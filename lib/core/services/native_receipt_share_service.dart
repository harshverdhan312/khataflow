import 'package:flutter/services.dart';
import 'receipt_share_service.dart';

class NativeReceiptShareService implements ReceiptShareService {
  static const MethodChannel _channel = MethodChannel('dev.khataflow.app/upi');

  const NativeReceiptShareService();

  @override
  Future<void> shareGenericText({
    required String text,
    String? subject,
  }) async {
    try {
      await _channel.invokeMethod('shareText', {
        'text': text,
        'subject': subject,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to open share sheet: ${e.message}');
    }
  }

  @override
  Future<void> shareWhatsAppReceipt({
    required String phone,
    required String message,
  }) async {
    await shareGenericText(text: message);
  }

  @override
  Future<void> shareFile({
    required String filePath,
    required String mimeType,
    String? subject,
    String? text,
  }) async {
    try {
      await _channel.invokeMethod('shareFile', {
        'filePath': filePath,
        'mimeType': mimeType,
        'subject': subject,
        'text': text,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to open share sheet: ${e.message}');
    }
  }
}

