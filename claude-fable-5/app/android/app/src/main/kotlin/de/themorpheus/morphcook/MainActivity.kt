package de.themorpheus.morphcook

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val pdfWorker = Executors.newSingleThreadExecutor()
    private val pdfBusy = AtomicBoolean(false)
    private var pdfChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pdfChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "morphcook/pdf_import")
        pdfChannel!!.setMethodCallHandler { call, result ->
            if (call.method != "extractText") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val bytes = call.argument<ByteArray>("bytes")
            if (bytes == null || bytes.isEmpty()) {
                result.error("invalidPdf", "No PDF data was supplied", null)
            } else if (bytes.size > PdfTextExtractor.MAX_BYTES) {
                result.error("tooLarge", "The PDF exceeds the file limit", null)
            } else if (!pdfBusy.compareAndSet(false, true)) {
                result.error("unavailable", "A PDF import is already running", null)
            } else {
                pdfWorker.execute {
                    try {
                        val text = PdfTextExtractor(applicationContext).extract(bytes)
                        runOnUiThread { result.success(text) }
                    } catch (error: PdfImportException) {
                        runOnUiThread { result.error(error.code, error.message, null) }
                    } finally {
                        pdfBusy.set(false)
                    }
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        pdfChannel?.setMethodCallHandler(null)
        pdfChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        pdfWorker.shutdownNow()
        super.onDestroy()
    }
}
