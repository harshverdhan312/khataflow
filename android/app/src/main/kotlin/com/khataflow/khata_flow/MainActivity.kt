package com.khataflow.khata_flow

import android.content.Intent
import android.util.Log
import java.io.File
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val TAG = "KhataFlowShare"
    private val CHANNEL = "dev.khataflow.app/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareText" -> handleShareText(call, result)
                    "shareFile" -> handleShareFile(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleShareText(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text")
        val subject = call.argument<String>("subject")
        if (text.isNullOrBlank()) {
            result.error("INVALID_TEXT", "Text to share cannot be null or empty", null)
            return
        }

        try {
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
                if (!subject.isNullOrBlank()) {
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                }
            }
            val shareIntent = Intent.createChooser(sendIntent, subject ?: "Share Settlement Statement")
            startActivity(shareIntent)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch share sheet: ${e.message}", e)
            result.error("SHARE_FAILED", "Failed to launch share sheet: ${e.message}", null)
        }
    }

    private fun handleShareFile(call: MethodCall, result: MethodChannel.Result) {
        val filePath = call.argument<String>("filePath")
        val mimeType = call.argument<String>("mimeType") ?: "application/pdf"
        val subject = call.argument<String>("subject")
        val text = call.argument<String>("text")

        if (filePath.isNullOrBlank()) {
            result.error("INVALID_FILE", "File path cannot be null or empty", null)
            return
        }

        try {
            val file = File(filePath)
            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                return
            }

            val contentUri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )

            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = mimeType
                putExtra(Intent.EXTRA_STREAM, contentUri)
                if (!text.isNullOrBlank()) {
                    putExtra(Intent.EXTRA_TEXT, text)
                }
                if (!subject.isNullOrBlank()) {
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                }
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            val chooser = Intent.createChooser(sendIntent, subject ?: "Share Settlement PDF")
            chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            startActivity(chooser)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to share file: ${e.message}", e)
            result.error("SHARE_FILE_FAILED", "Failed to share file: ${e.message}", null)
        }
    }
}


