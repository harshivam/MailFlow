import 'dart:math';

String formatEmailDate(String timeString) {
  if (timeString.isEmpty) return '';

  try {
    DateTime? date;
    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    try {
      date = DateTime.parse(timeString);
    } catch (_) {
      final RegExp dateRegex = RegExp(
        r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)',
        caseSensitive: false,
      );
      final match = dateRegex.firstMatch(timeString);
      if (match != null) {
        return '${match.group(1)} ${match.group(2)}';
      }
      if (timeString.contains(',')) {
        final parts = timeString.split(',');
        if (parts.length > 1) return parts[0];
      }
      return timeString.substring(0, min(10, timeString.length));
    }

    final day = date.day;
    final month = months[date.month - 1];
    return '$day $month';
  } catch (_) {
    return timeString.length > 10 ? timeString.substring(0, 10) : timeString;
  }
}
