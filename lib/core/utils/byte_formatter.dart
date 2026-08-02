/// Formats a byte count as a human-readable string, e.g. 1536 -> "1.5 KB".
String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final formatted = unitIndex == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(decimals);
  return '$formatted ${units[unitIndex]}';
}
