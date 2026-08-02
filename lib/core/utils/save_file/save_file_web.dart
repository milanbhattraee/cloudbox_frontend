// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// On the web there's no app-local filesystem to write to and nothing to
/// "open" separately - triggering the browser's normal download flow *is*
/// the action. [mimeType] is used for the Blob's content type so the
/// browser handles it sensibly.
Future<void> saveAndOpenBytes(List<int> bytes, String fileName, {String? mimeType}) async {
  final blob = html.Blob([Uint8List.fromList(bytes)], mimeType ?? 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// There's no real filesystem path on the web; this still triggers the
/// download (see [saveAndOpenBytes]) and returns the filename for display
/// purposes only.
Future<String> saveBytesToDisk(List<int> bytes, String fileName) async {
  await saveAndOpenBytes(bytes, fileName);
  return fileName;
}
