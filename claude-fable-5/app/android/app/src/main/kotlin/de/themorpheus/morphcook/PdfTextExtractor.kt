package de.themorpheus.morphcook

import android.content.Context
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.contentstream.operator.Operator
import com.tom_roush.pdfbox.cos.COSBase
import com.tom_roush.pdfbox.io.MemoryUsageSetting
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.PDPage
import com.tom_roush.pdfbox.pdmodel.encryption.InvalidPasswordException
import com.tom_roush.pdfbox.text.PDFTextStripper
import com.tom_roush.pdfbox.text.TextPosition
import java.io.ByteArrayInputStream
import java.io.IOException
import java.io.Writer

class PdfImportException(val code: String, message: String) : IOException(message)

/** Offline text extraction only: no rendering, OCR, links or JavaScript. */
class PdfTextExtractor(private val context: Context) {
    companion object {
        const val MAX_BYTES = 10 * 1024 * 1024
        const val MAX_PAGES = 50
        const val MAX_TEXT = 200_000
        private const val MAX_OPERATORS = 500_000
    }

    fun extract(bytes: ByteArray): String {
        if (bytes.size > MAX_BYTES) throw PdfImportException("tooLarge", "PDF is too large")
        if (bytes.size < 5 || String(bytes, 0, 5, Charsets.US_ASCII) != "%PDF-") {
            throw PdfImportException("invalidPdf", "Not a PDF document")
        }
        try {
            PDFBoxResourceLoader.init(context.applicationContext)
            val memory = MemoryUsageSetting.setupMixed(2L * 1024 * 1024, 64L * 1024 * 1024)
                .setTempDir(context.cacheDir)
            PDDocument.load(ByteArrayInputStream(bytes), "", memory).use { document ->
                if (!document.currentAccessPermission.canExtractContent()) {
                    throw PdfImportException("permissionDenied", "PDF does not permit text extraction")
                }
                // Empty-password encryption is still encryption: do not silently
                // bypass it merely because the library can open the document.
                if (document.isEncrypted) throw PdfImportException("encrypted", "PDF is encrypted")
                if (document.numberOfPages > MAX_PAGES) {
                    throw PdfImportException("tooManyPages", "PDF has too many pages")
                }
                val writer = BoundedTextWriter()
                val stripper = object : PDFTextStripper() {
                    var pages = 0
                    var characters = 0
                    var operators = 0

                    fun checkInterrupted() {
                        if (Thread.currentThread().isInterrupted) {
                            throw PdfImportException("unavailable", "PDF extraction was interrupted")
                        }
                    }

                    override fun processPage(page: PDPage) {
                        checkInterrupted()
                        if (++pages > MAX_PAGES) {
                            throw PdfImportException("tooManyPages", "PDF has too many pages")
                        }
                        super.processPage(page)
                    }

                    override fun processTextPosition(text: TextPosition) {
                        checkInterrupted()
                        characters += text.unicode.length
                        if (characters > MAX_TEXT) {
                            throw PdfImportException("textTooLarge", "PDF contains too much text")
                        }
                        super.processTextPosition(text)
                    }

                    override fun processOperator(operator: Operator, operands: MutableList<COSBase>) {
                        checkInterrupted()
                        if (++operators > MAX_OPERATORS) {
                            throw PdfImportException("textTooLarge", "PDF content is too complex")
                        }
                        super.processOperator(operator, operands)
                    }

                    override fun operatorException(
                        operator: Operator,
                        operands: MutableList<COSBase>,
                        exception: IOException,
                    ) {
                        // PDFBox normally logs recoverable operator errors. Our
                        // resource limits must abort instead of being swallowed.
                        if (exception is PdfImportException) throw exception
                        super.operatorException(operator, operands, exception)
                    }
                }
                stripper.sortByPosition = true
                stripper.writeText(document, writer)
                return writer.toString().trim().also {
                    if (it.isBlank()) throw PdfImportException("noText", "PDF has no selectable text")
                }
            }
        } catch (error: PdfImportException) {
            throw error
        } catch (error: InvalidPasswordException) {
            throw PdfImportException("encrypted", "PDF requires a password")
        } catch (error: StackOverflowError) {
            throw PdfImportException("invalidPdf", "PDF contains invalid recursive content")
        } catch (error: OutOfMemoryError) {
            throw PdfImportException("tooLarge", "PDF requires too much memory")
        } catch (error: Exception) {
            throw PdfImportException("invalidPdf", "PDF could not be read")
        }
    }

    private class BoundedTextWriter : Writer() {
        private val text = StringBuilder()
        override fun write(buffer: CharArray, offset: Int, length: Int) {
            if (text.length + length > MAX_TEXT) {
                throw PdfImportException("textTooLarge", "PDF contains too much text")
            }
            text.append(buffer, offset, length)
        }
        override fun flush() {}
        override fun close() {}
        override fun toString() = text.toString()
    }
}
