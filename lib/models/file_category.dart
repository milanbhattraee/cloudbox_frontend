import 'package:flutter/material.dart';

enum FileCategory { image, video, pdf, document, others }

extension FileCategoryX on FileCategory {
  /// Value expected/returned by the backend ("IMAGE", "VIDEO", ...).
  String get apiValue => switch (this) {
        FileCategory.image => 'IMAGE',
        FileCategory.video => 'VIDEO',
        FileCategory.pdf => 'PDF',
        FileCategory.document => 'DOCUMENT',
        FileCategory.others => 'OTHERS',
      };

  String get label => switch (this) {
        FileCategory.image => 'Images',
        FileCategory.video => 'Videos',
        FileCategory.pdf => 'PDFs',
        FileCategory.document => 'Documents',
        FileCategory.others => 'Others',
      };

  IconData get icon => switch (this) {
        FileCategory.image => Icons.image_rounded,
        FileCategory.video => Icons.movie_rounded,
        FileCategory.pdf => Icons.picture_as_pdf_rounded,
        FileCategory.document => Icons.description_rounded,
        FileCategory.others => Icons.insert_drive_file_rounded,
      };

  Color get color => switch (this) {
        FileCategory.image => const Color(0xFF16A34A),
        FileCategory.video => const Color(0xFFDB2777),
        FileCategory.pdf => const Color(0xFFDC2626),
        FileCategory.document => const Color(0xFF2563EB),
        FileCategory.others => const Color(0xFF64748B),
      };

  static FileCategory fromApiValue(String? value) {
    switch (value) {
      case 'IMAGE':
        return FileCategory.image;
      case 'VIDEO':
        return FileCategory.video;
      case 'PDF':
        return FileCategory.pdf;
      case 'DOCUMENT':
        return FileCategory.document;
      default:
        return FileCategory.others;
    }
  }
}
