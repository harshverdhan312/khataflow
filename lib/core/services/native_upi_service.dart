import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'upi_service.dart';

class NativeUpiService implements UpiService {
  static const MethodChannel _channel = MethodChannel('dev.khataflow.app/upi');

  // Regex pattern for standard UPI VPA (handle@psp)
  static final RegExp _vpaRegex = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');

  const NativeUpiService();

  @override
  bool isValidVpa(String vpa) {
    final trimmed = vpa.trim();
    if (trimmed.isEmpty) return false;
    return _vpaRegex.hasMatch(trimmed);
  }

  @override
  Uri buildUpiUri({
    required String vpa,
    required String merchantName,
    required int amountPaise,
    required String transactionNote,
  }) {
    // Exact integer arithmetic to convert paise to rupees (e.g. 1050 paise -> "10.50")
    final rupees = amountPaise ~/ 100;
    final paiseRemainder = amountPaise % 100;
    final amountString = '$rupees.${paiseRemainder.toString().padLeft(2, '0')}';

    final queryParameters = <String, String>{
      'pa': vpa.trim(),
      'pn': merchantName.trim(),
      'am': amountString,
      'cu': 'INR',
      'tn': transactionNote.trim(),
    };

    return Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: queryParameters,
    );
  }

  @override
  Future<UpiLaunchResult> launchPayment({
    required String vpa,
    required String merchantName,
    required int amountPaise,
    required String transactionNote,
  }) async {
    if (!isValidVpa(vpa)) {
      return const UpiLaunchResult(
        status: UpiLaunchStatus.launchFailed,
        statusMessage: 'Invalid UPI VPA address',
      );
    }

    if (amountPaise <= 0) {
      return const UpiLaunchResult(
        status: UpiLaunchStatus.launchFailed,
        statusMessage: 'Settlement amount must be greater than zero',
      );
    }

    final uri = buildUpiUri(
      vpa: vpa,
      merchantName: merchantName,
      amountPaise: amountPaise,
      transactionNote: transactionNote,
    );

    try {
      final resultMap = await _channel.invokeMapMethod<String, dynamic>(
        'launchUpiPayment',
        {'upiUri': uri.toString()},
      );

      if (resultMap != null) {
        final launchStatusStr = resultMap['launchStatus'] as String?;
        final statusMessage = resultMap['statusMessage'] as String?;

        if (launchStatusStr == 'noAppInstalled') {
          return UpiLaunchResult(
            status: UpiLaunchStatus.noAppInstalled,
            statusMessage: statusMessage ?? 'No compatible UPI payment application found on device',
          );
        }

        if (launchStatusStr == 'launchFailed') {
          return UpiLaunchResult(
            status: UpiLaunchStatus.launchFailed,
            statusMessage: statusMessage ?? 'Failed to launch UPI application',
          );
        }

        return UpiLaunchResult(
          status: UpiLaunchStatus.launched,
          rawResponse: resultMap['rawResponse'] as String?,
          upiStatus: resultMap['status'] as String?,
          txnId: resultMap['txnId'] as String?,
          approvalRefNo: resultMap['approvalRefNo'] as String?,
          responseCode: resultMap['responseCode'] as String?,
          txnRef: resultMap['txnRef'] as String?,
          statusMessage: statusMessage ?? 'UPI payment flow completed',
        );
      }
    } on MissingPluginException {
      // Graceful fallback for non-Android platforms / unit tests
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) {
          return const UpiLaunchResult(
            status: UpiLaunchStatus.launched,
            statusMessage: 'UPI application opened via external launcher',
          );
        } else {
          return const UpiLaunchResult(
            status: UpiLaunchStatus.noAppInstalled,
            statusMessage: 'No compatible UPI payment application found',
          );
        }
      } catch (e) {
        return UpiLaunchResult(
          status: UpiLaunchStatus.launchFailed,
          statusMessage: 'Failed to launch UPI application: $e',
        );
      }
    } catch (e) {
      return UpiLaunchResult(
        status: UpiLaunchStatus.launchFailed,
        statusMessage: 'Error during native UPI intent: $e',
      );
    }

    return const UpiLaunchResult(
      status: UpiLaunchStatus.launched,
      statusMessage: 'UPI payment application finished',
    );
  }
}
