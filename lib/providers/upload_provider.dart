import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../models/cloud_file.dart';
import '../services/file_service.dart';

enum UploadStatus { idle, uploading, success, error }

class UploadProvider extends ChangeNotifier {
  UploadProvider({FileService? fileService})
      : _fileService = fileService ?? FileService();

  final FileService _fileService;

  UploadStatus status = UploadStatus.idle;
  String? currentBatchLabel;
  double progress = 0; // 0..1
  String? errorMessage;

  bool get isUploading => status == UploadStatus.uploading;

  /// Opens the system file picker (any file type, multi-select) and, if the
  /// user picked something, uploads it to [folderId] (null == root).
  /// Returns the newly created files on success, or null if the user
  /// cancelled the picker or the upload failed (see [errorMessage]).
  Future<List<CloudFile>?> pickAndUpload({String? folderId}) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    return uploadPicked(result.files, folderId: folderId);
  }

  Future<List<CloudFile>?> uploadPicked(List<PlatformFile> pickedFiles,
      {String? folderId}) async {
    status = UploadStatus.uploading;
    progress = 0;
    errorMessage = null;
    currentBatchLabel = pickedFiles.length == 1
        ? pickedFiles.first.name
        : '${pickedFiles.length} files';
    notifyListeners();

    try {
      final uploaded = await _fileService.uploadFiles(
        files: pickedFiles,
        folderId: folderId,
        onProgress: (sent, total) {
          if (total > 0) {
            final newProgress = sent / total;
            // Only notify if progress changed significantly (>1% change) or reached 100%
            if ((newProgress - progress).abs() > 0.01 || newProgress >= 1.0) {
              progress = newProgress;
              debugPrint('[Upload] Progress: ${(progress * 100).toStringAsFixed(1)}%');
              notifyListeners();
            }
          }
        },
      );
      status = UploadStatus.success;
      progress = 1.0;
      notifyListeners();
      return uploaded;
    } catch (e) {
      errorMessage = e is ApiException ? e.displayMessage : e.toString();
      status = UploadStatus.error;
      notifyListeners();
      return null;
    } finally {
      // Let the UI show the final state briefly, then reset.
      Future.delayed(const Duration(seconds: 3), () {
        if (status != UploadStatus.uploading) {
          status = UploadStatus.idle;
          currentBatchLabel = null;
          progress = 0;
          notifyListeners();
        }
      });
    }
  }
}
