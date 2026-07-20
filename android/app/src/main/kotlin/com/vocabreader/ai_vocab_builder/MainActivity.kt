package com.vocabreader.ai_vocab_builder

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val PICKER_CHANNEL = "com.vocabreader/picker"
    private val TTS_CHANNEL = "com.vocabreader/tts"
    private val SHARE_CHANNEL = "com.vocabreader/share"
    private var pendingResult: MethodChannel.Result? = null
    private var tts: TextToSpeech? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── PDF File Picker Channel ───────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PICKER_CHANNEL)
            .setMethodCallHandler { call, result ->
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

        // ── Text-to-Speech Channel ─────────────────────────────
        // Uses Android's built-in TextToSpeech engine — works offline.
        // No external package needed. Zero Kotlin Gradle Plugin warnings.
        tts = TextToSpeech(this) { status ->
            // TTS engine initialized (or failed — handled gracefully)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TTS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val text = call.argument<String>("text") ?: ""
                        val language = call.argument<String>("language") ?: "de"
                        if (text.isNotEmpty()) {
                            val locale = Locale.forLanguageTag(language)
                            tts?.language = locale
                            // QUEUE_FLUSH = stop current speech, start new one
                            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, null)
                        }
                        result.success(true)
                    }
                    "stop" -> {
                        tts?.stop()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Share / Export Channel ─────────────────────────────
        // Writes content to a cache file and opens the Android share sheet so
        // the word list can be exported as a real .csv / .txt file.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "shareFile") {
                    try {
                        val content = call.argument<String>("content") ?: ""
                        val rawFilename = call.argument<String>("filename") ?: "export.txt"
                        // Base name only — never let a filename escape the cache dir.
                        val filename = rawFilename.substringAfterLast('/')
                            .substringAfterLast('\\')
                            .ifBlank { "export.txt" }
                        val mime = call.argument<String>("mime") ?: "text/plain"

                        val file = File(cacheDir, filename)
                        file.writeText(content)
                        val uri = FileProvider.getUriForFile(
                            this, "$packageName.fileprovider", file
                        )
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = mime
                            putExtra(Intent.EXTRA_STREAM, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(Intent.createChooser(intent, "Export word list"))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, null)
                    }
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

                    // Sanitize: a content provider could supply a display name
                    // containing path separators ("../…"). Keep only the base
                    // name so the copy can never escape the cache directory.
                    val safeName = name.substringAfterLast('/')
                        .substringAfterLast('\\')
                        .ifBlank { "document.pdf" }
                    val inputStream = contentResolver.openInputStream(uri)
                    val cacheFile = File(cacheDir, "picked_$safeName")
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

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        super.onDestroy()
    }
}
