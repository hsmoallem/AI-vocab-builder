package com.aivocabbuilder.ai_vocab_builder

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.vocabreader/picker"
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "pickPdf") {
                pendingResult = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "application/pdf"
                }
                startActivityForResult(intent, 1001)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1001 && resultCode == Activity.RESULT_OK) {
            val uri = data?.data
            if (uri != null) {
                try {
                    // Copy the file to app cache so we can read bytes
                    val cursor = contentResolver.query(uri, null, null, null, null)
                    val name = cursor?.use {
                        if (it.moveToFirst()) {
                            val idx = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                            if (idx >= 0) it.getString(idx) else "document.pdf"
                        } else "document.pdf"
                    } ?: "document.pdf"

                    val inputStream = contentResolver.openInputStream(uri)
                    val cacheFile = File(cacheDir, "picked_$name")
                    inputStream?.use { input ->
                        FileOutputStream(cacheFile).use { output ->
                            input.copyTo(output)
                        }
                    }

                    val resultMap = mapOf(
                        "path" to cacheFile.absolutePath,
                        "name" to name
                    )
                    pendingResult?.success(resultMap)
                } catch (e: Exception) {
                    pendingResult?.error("PICK_ERROR", e.message, null)
                }
            } else {
                pendingResult?.error("PICK_ERROR", "No file selected", null)
            }
        } else {
            pendingResult?.success(null) // User cancelled
        }
        pendingResult = null
    }
}
