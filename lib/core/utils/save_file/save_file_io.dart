import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

String _safeFileName(String fileName) => fileName.replaceAll(RegExp(r'[/\\]'), '_');

/// Writes [bytes] to the app's sandboxed documents directory (no runtime
/// storage permission needed on Android 10+ / iOS) and hands it off to the
/// OS to open with whatever app the user has for that file type.
Future<void> saveAndOpenBytes(List<int> bytes, String fileName, {String? mimeType}) async {
  final path = await saveBytesToDisk(bytes, fileName);
  await OpenFilex.open(path, type: mimeType);
}

/// Writes [bytes] to disk and returns the absolute path, without opening it.
Future<String> saveBytesToDisk(List<int> bytes, String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}${Platform.pathSeparator}${_safeFileName(fileName)}';
  final file = File(path);
  await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);
  return path;
}
