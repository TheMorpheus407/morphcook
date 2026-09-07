package de.themorpheus.morphcook

import android.graphics.Bitmap
import android.util.Base64
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.cos.COSDictionary
import com.tom_roush.pdfbox.cos.COSName
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.PDPage
import com.tom_roush.pdfbox.pdmodel.PDPageContentStream
import com.tom_roush.pdfbox.pdmodel.PDResources
import com.tom_roush.pdfbox.pdmodel.encryption.AccessPermission
import com.tom_roush.pdfbox.pdmodel.encryption.StandardProtectionPolicy
import com.tom_roush.pdfbox.pdmodel.font.PDType0Font
import com.tom_roush.pdfbox.pdmodel.font.PDType1Font
import com.tom_roush.pdfbox.pdmodel.graphics.image.LosslessFactory
import java.io.ByteArrayOutputStream
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/** Real PDF bytes and the production Android extractor, running on a device. */
@RunWith(AndroidJUnit4::class)
class PdfTextExtractorTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val extractor = PdfTextExtractor(context)

    @Before fun initialize() = PDFBoxResourceLoader.init(context)

    @Test fun extractsCompressedEmbeddedUnicodeRecipe() {
        val expected = listOf("Kartoffelsuppe für zwei", "Zutaten", "½ EL Öl", "Zubereitung", "Gemüse dünsten.")
        val bytes = makePdf { document ->
            val page = PDPage()
            document.addPage(page)
            val font = context.assets.open(
                "flutter_assets/assets/fonts/AtkinsonHyperlegible-Regular.ttf"
            ).use { PDType0Font.load(document, it) }
            PDPageContentStream(document, page, PDPageContentStream.AppendMode.OVERWRITE, true).use { stream ->
                stream.beginText()
                stream.setFont(font, 12f)
                stream.newLineAtOffset(40f, 700f)
                for (line in expected) {
                    stream.showText(line)
                    stream.newLineAtOffset(0f, -20f)
                }
                stream.endText()
            }
        }
        assertTrue(String(bytes, Charsets.ISO_8859_1).contains("/FlateDecode"))
        val actual = extractor.extract(bytes)
        for (line in expected) assertTrue("Missing $line in $actual", actual.contains(line))
    }

    @Test fun rejectsOversizedBytesBeforeParsing() {
        assertFailure("tooLarge", ByteArray(PdfTextExtractor.MAX_BYTES + 1))
    }

    @Test fun rejectsPageOverflowWithoutTruncation() {
        assertFailure("tooManyPages", makePdf { doc -> repeat(51) { doc.addPage(PDPage()) } })
    }

    @Test fun rejectsLargeCompressedTextBeforeAccumulatingThePage() {
        val bytes = makePdf { document ->
            val page = PDPage()
            document.addPage(page)
            PDPageContentStream(document, page, PDPageContentStream.AppendMode.OVERWRITE, true).use { stream ->
                stream.beginText()
                stream.setFont(PDType1Font.HELVETICA, 1f)
                // Repeated text on the same page is intentionally highly compressed.
                repeat(201) { stream.showText("a".repeat(1000)) }
                stream.endText()
            }
        }
        assertTrue(bytes.size < 100_000)
        assertFailure("textTooLarge", bytes)
    }

    @Test fun rejectsExcessiveContentOperations() {
        val bytes = makePdf { document ->
            val page = PDPage()
            document.addPage(page)
            PDPageContentStream(document, page, PDPageContentStream.AppendMode.OVERWRITE, true).use { stream ->
                @Suppress("DEPRECATION")
                stream.appendRawCommands("q Q\n".repeat(250_001))
            }
        }
        assertTrue(bytes.size < 100_000)
        assertFailure("textTooLarge", bytes)
    }

    @Test fun rejectsDeeplyNestedContentWithoutCrashing() {
        val bytes = makePdf { document ->
            val page = PDPage()
            document.addPage(page)
            PDPageContentStream(document, page).use { stream ->
                @Suppress("DEPRECATION")
                stream.appendRawCommands("[".repeat(20_000) + "0" + "]".repeat(20_000))
            }
        }
        assertFailure("invalidPdf", bytes)
    }

    @Test fun rejectsPasswordAndEmptyPasswordEncryption() {
        for (password in listOf("secret", "")) {
            val bytes = makePdf { document ->
                document.addPage(PDPage())
                document.protect(StandardProtectionPolicy("owner", password, AccessPermission()))
            }
            assertFailure("encrypted", bytes)
        }
    }

    @Test fun respectsExtractionPermissions() {
        val bytes = makePdf { document ->
            document.addPage(PDPage())
            val permission = AccessPermission()
            permission.setCanExtractContent(false)
            document.protect(StandardProtectionPolicy("owner", "", permission))
        }
        assertFailure("permissionDenied", bytes)
    }

    @Test fun rejectsCorruptAndImageOnlyDocuments() {
        assertFailure("invalidPdf", "%PDF-1.7\nnot a valid document".toByteArray())
        assertFailure("invalidPdf", "not a PDF".toByteArray())
        assertFailure("noText", makePdf { document ->
            val page = PDPage()
            document.addPage(page)
            PDPageContentStream(document, page).use { stream ->
                val bitmap = Bitmap.createBitmap(20, 20, Bitmap.Config.ARGB_8888)
                try {
                    bitmap.eraseColor(0xff000000.toInt())
                    stream.drawImage(LosslessFactory.createFromImage(document, bitmap), 0f, 0f)
                } finally {
                    bitmap.recycle()
                }
            }
        })
    }

    @Test fun extractsRecipeTextWithoutDecodingJpeg2000Images() {
        assertJpeg2000DecoderAbsent()
        fun pdfWithImage(text: String) = makePdf { document ->
            val page = PDPage()
            document.addPage(page)
            val image = document.document.createCOSStream()
            image.setItem(COSName.TYPE, COSName.XOBJECT)
            image.setItem(COSName.SUBTYPE, COSName.IMAGE)
            image.setInt(COSName.WIDTH, 1)
            image.setInt(COSName.HEIGHT, 1)
            image.setInt(COSName.BITS_PER_COMPONENT, 8)
            image.setItem(COSName.COLORSPACE, COSName.DEVICERGB)
            image.setItem(COSName.FILTER, COSName.JPX_DECODE)
            image.createRawOutputStream().use { it.write(jpeg2000Pixel()) }
            page.resources = PDResources().also { resources ->
                val objects = COSDictionary()
                objects.setItem(COSName.getPDFName("JPXTest"), image)
                resources.cosObject.setItem(COSName.XOBJECT, objects)
            }
            PDPageContentStream(document, page).use { stream ->
                stream.beginText()
                stream.setFont(PDType1Font.HELVETICA, 12f)
                stream.showText(text)
                stream.endText()
                @Suppress("DEPRECATION")
                stream.appendRawCommands("\nq 1 0 0 1 0 0 cm /JPXTest Do Q\n")
            }
        }
        assertEquals("Soup: simmer carrots.", extractor.extract(pdfWithImage("Soup: simmer carrots.")))
        assertFailure("noText", pdfWithImage(""))
    }

    @Test fun rejectsJpeg2000FilteredPageContentWithoutCrashing() {
        assertJpeg2000DecoderAbsent()
        val bytes = makePdf { document ->
            val page = PDPage()
            document.addPage(page)
            // Malformed PDFs can put an image-only filter on the text content
            // stream. This must become a readable import error, not a linkage
            // error from the deliberately omitted optional decoder.
            val content = document.document.createCOSStream()
            content.setItem(COSName.FILTER, COSName.JPX_DECODE)
            content.createRawOutputStream().use { it.write(jpeg2000Pixel()) }
            page.cosObject.setItem(COSName.CONTENTS, content)
        }
        assertFailure("invalidPdf", bytes)
    }

    private fun assertJpeg2000DecoderAbsent() {
        try {
            Class.forName("com.gemalto.jp2.JP2Decoder")
            fail("Test must exercise extraction without the optional JPEG2000 decoder")
        } catch (_: ClassNotFoundException) {
            // Expected: the release keeps the same text-only dependency set.
        }
    }

    // A real 1x1 blue JP2 fixture generated with Pillow/OpenJPEG 2.5.4.
    // Embedded bytes keep native tests offline and require no image decoder.
    private fun jpeg2000Pixel(): ByteArray = Base64.decode(
        "AAAADGpQICANCocKAAAAFGZ0eXBqcDIgAAAAAGpwMiAAAAAtanAyaAAAABZpaGRyAAAAAQAAAAEAAwcHAAAAAAAPY29scgEAAAAAABAAAACSanAyY/9P/1EALwAAAAAAAQAAAAEAAAAAAAAAAAAAAAEAAAABAAAAAAAAAAAAAwcBAQcBAQcBAf9SAAwAAAABAAAEBAAB/1wABEBA/2QAJQABQ3JlYXRlZCBieSBPcGVuSlBFRyB2ZXJzaW9uIDIuNS40/5AACgAAAAAAGgAB/5PfgAgH34AIB8+0BAD/2Q==",
        Base64.DEFAULT,
    )

    @Test fun closesScratchFilesAfterSuccessAndFailure() {
        val before = context.cacheDir.listFiles()?.filter { it.name.startsWith("PDFBox") }?.map { it.name }?.toSet()
        // The uncompressed extra stream makes the input exceed the 2 MiB RAM
        // threshold, so this exercises real scratch files rather than an empty PDF.
        fun largePdf(text: String) = makePdf { document ->
            val page = PDPage()
            document.addPage(page)
            PDPageContentStream(document, page).use { stream ->
                stream.beginText()
                stream.setFont(PDType1Font.HELVETICA, 12f)
                stream.showText(text)
                stream.endText()
            }
            val padding = document.document.createCOSStream()
            padding.createOutputStream().use { it.write(ByteArray(3 * 1024 * 1024)) }
            document.documentCatalog.cosObject.setItem(COSName.getPDFName("ScratchFixture"), padding)
        }
        assertEquals("Soup", extractor.extract(largePdf("Soup")))
        assertFailure("noText", largePdf(""))
        val after = context.cacheDir.listFiles()?.filter { it.name.startsWith("PDFBox") }?.map { it.name }?.toSet()
        assertEquals(before, after)
    }

    private fun makePdf(fill: (PDDocument) -> Unit): ByteArray = PDDocument().use { document ->
        fill(document)
        ByteArrayOutputStream().use { output ->
            document.save(output)
            output.toByteArray()
        }
    }

    private fun assertFailure(code: String, bytes: ByteArray) {
        try {
            extractor.extract(bytes)
            fail("Expected $code")
        } catch (error: PdfImportException) {
            assertEquals(code, error.code)
        }
    }
}
