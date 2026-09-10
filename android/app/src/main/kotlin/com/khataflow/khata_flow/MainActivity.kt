package com.khataflow.khata_flow

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.activity.result.ActivityResult
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import java.io.File
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val TAG = "KhataFlowUPI"
    private val CHANNEL = "dev.khataflow.app/upi"
    private var pendingResult: MethodChannel.Result? = null

    private val upiLauncher: ActivityResultLauncher<Intent> =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result: ActivityResult ->
            handleUpiActivityResult(result.resultCode, result.data)
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "launchUpiPayment" -> handleLaunchUpi(call, result)
                    "isUpiAvailable" -> handleIsUpiAvailable(result)
                    "shareText" -> handleShareText(call, result)
                    "shareFile" -> handleShareFile(call, result)
                    else -> result.notImplemented()
                }
            }
    }



    private fun handleLaunchUpi(call: MethodCall, result: MethodChannel.Result) {
        val uriString = call.argument<String>("upiUri")
        if (uriString.isNullOrBlank()) {
            result.error("INVALID_URI", "UPI URI cannot be null or empty", null)
            return
        }

        try {
            val upiUri = Uri.parse(uriString)
            val intent = Intent(Intent.ACTION_VIEW, upiUri)

            val packageManager = packageManager
            val activities = packageManager.queryIntentActivities(intent, 0)
            if (activities.isEmpty()) {
                val responseMap = mapOf(
                    "launchStatus" to "noAppInstalled",
                    "statusMessage" to "No compatible UPI app found on device"
                )
                result.success(responseMap)
                return
            }

            Log.d(TAG, "Launching direct UPI intent for: ${upiUri.scheme}://pay")
            pendingResult = result
            // Direct launch preserves direct ActivityResult without ChooserActivity proxy stripping
            upiLauncher.launch(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch direct UPI intent: ${e.message}", e)
            val responseMap = mapOf(
                "launchStatus" to "launchFailed",
                "statusMessage" to "Failed to launch UPI application: ${e.message}"
            )
            result.success(responseMap)
        }
    }

    private fun handleIsUpiAvailable(result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("upi://pay"))
            val activities = packageManager.queryIntentActivities(intent, 0)
            result.success(activities.isNotEmpty())
        } catch (e: Exception) {
            result.success(false)
        }
    }

    private fun handleUpiActivityResult(resultCode: Int, data: Intent?) {
        val channelResult = pendingResult ?: return
        pendingResult = null

        val responseMap = mutableMapOf<String, Any?>()
        responseMap["launchStatus"] = "launched"

        val rawResponse: String? = data?.getStringExtra("response")
            ?: data?.data?.query
            ?: data?.data?.toString()

        var status: String? = null
        var txnId: String? = null
        var approvalRefNo: String? = null
        var responseCode: String? = null
        var txnRef: String? = null

        if (!rawResponse.isNullOrBlank()) {
            responseMap["rawResponse"] = rawResponse
            val pairs = rawResponse.split("&")
            for (pair in pairs) {
                val parts = pair.split("=", limit = 2)
                if (parts.size == 2) {
                    val key = parts[0].trim()
                    val value = parts[1].trim()
                    when {
                        key.equals("Status", ignoreCase = true) -> status = value
                        key.equals("txnId", ignoreCase = true) -> txnId = value
                        key.equals("ApprovalRefNo", ignoreCase = true) || key.equals("refId", ignoreCase = true) -> approvalRefNo = value
                        key.equals("responseCode", ignoreCase = true) -> responseCode = value
                        key.equals("txnRef", ignoreCase = true) -> txnRef = value
                    }
                }
            }
        }

        val extras = data?.extras
        if (extras != null) {
            for (key in extras.keySet()) {
                val valueStr = extras.get(key)?.toString()
                if (valueStr != null) {
                    when {
                        key.equals("Status", ignoreCase = true) && status == null -> status = valueStr
                        key.equals("txnId", ignoreCase = true) && txnId == null -> txnId = valueStr
                        (key.equals("ApprovalRefNo", ignoreCase = true) || key.equals("refId", ignoreCase = true)) && approvalRefNo == null -> approvalRefNo = valueStr
                        key.equals("responseCode", ignoreCase = true) && responseCode == null -> responseCode = valueStr
                        key.equals("txnRef", ignoreCase = true) && txnRef == null -> txnRef = valueStr
                    }
                }
            }
        }

        if (status == null && resultCode == Activity.RESULT_CANCELED) {
            status = "CANCELED"
        }

        Log.d(TAG, "Received UPI ActivityResult: resultCode=$resultCode, Status=$status, hasApprovalRef=${approvalRefNo != null}, hasTxnId=${txnId != null}")

        responseMap["status"] = status
        responseMap["txnId"] = txnId
        responseMap["approvalRefNo"] = approvalRefNo
        responseMap["responseCode"] = responseCode
        responseMap["txnRef"] = txnRef
        responseMap["resultCode"] = resultCode

        channelResult.success(responseMap)
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


