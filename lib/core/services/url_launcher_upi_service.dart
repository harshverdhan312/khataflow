import 'package:url_launcher/url_launcher.dart';
import 'upi_service.dart';

class UrlLauncherUpiService implements UpiService {
  // Regex pattern for standard UPI VPA (handle@psp)
  static final RegExp _vpaRegex = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');

  const UrlLauncherUpiService();

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
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        return const UpiLaunchResult(
          status: UpiLaunchStatus.launched,
          statusMessage: 'UPI payment application opened successfully',
        );
      } else {
        return const UpiLaunchResult(
          status: UpiLaunchStatus.noAppInstalled,
          statusMessage: 'No compatible UPI payment application found on device',
        );
      }
    } catch (e) {
      return UpiLaunchResult(
        status: UpiLaunchStatus.launchFailed,
        statusMessage: 'Failed to launch UPI application: $e',
      );
    }
  }
}
