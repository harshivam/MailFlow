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

// Add DateFormatter class
class DateFormatter {
  // Format a date relative to now (like "Today", "Yesterday", "2 days ago", etc.)
  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    // Same day
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Today';
    }

    // Yesterday
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.day == yesterday.day &&
        date.month == yesterday.month &&
        date.year == yesterday.year) {
      return 'Yesterday';
    }

    // Within the last 7 days
    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    // Within the last 4 weeks
    if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }

    // Different year
    if (date.year != now.year) {
      return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
    }

    // Same year, different month
    return '${_getMonthName(date.month)} ${date.day}';
  }

  // Helper method to get month names
  static String _getMonthName(int month) {
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
    return months[month - 1];
  }
}
