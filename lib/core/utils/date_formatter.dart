import 'package:intl/intl.dart';

/// Formats a [DateTime] the way a file browser would: a short relative
/// label for recent items, and an absolute date further back.
String formatFriendlyDate(DateTime date) {
  final now = DateTime.now();
  final local = date.toLocal();
  final diff = now.difference(local);

  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24 && now.day == local.day) return '${diff.inHours}h ago';
  if (diff.inDays == 1 || (diff.inDays == 0 && now.day != local.day)) return 'Yesterday';
  if (diff.inDays < 7) return DateFormat('EEEE').format(local);
  if (local.year == now.year) return DateFormat('MMM d').format(local);
  return DateFormat('MMM d, yyyy').format(local);
}
