abstract class ReceiptShareService {
  Future<void> shareWhatsAppReceipt({
    required String phone,
    required String message,
  });

  Future<void> shareGenericText({
    required String text,
    String? subject,
  });

  Future<void> shareFile({
    required String filePath,
    required String mimeType,
    String? subject,
    String? text,
  });
}

