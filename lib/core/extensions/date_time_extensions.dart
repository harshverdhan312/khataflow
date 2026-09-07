import 'package:intl/intl.dart';

extension DateTimeFormatting on DateTime {
  String toFormattedDate() {
    return DateFormat('d MMM yyyy').format(this);
  }

  String toShortDate() {
    return DateFormat('d MMM').format(this);
  }

  String toTimeDisplay() {
    return DateFormat('h:mm a').format(this);
  }

  String toRelativeDisplay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDate = DateTime(year, month, day);

    final diffDays = today.difference(recordDate).inDays;
    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';
    if (diffDays < 7) return '$diffDays days ago';
    return toShortDate();
  }
}
