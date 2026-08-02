import 'cloud_file.dart';

class PageMeta {
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  PageMeta({required this.page, required this.limit, required this.total, required this.totalPages});

  factory PageMeta.fromJson(Map<String, dynamic> json) {
    return PageMeta(
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

class PaginatedFiles {
  final List<CloudFile> items;
  final PageMeta meta;

  PaginatedFiles({required this.items, required this.meta});

  bool get hasMore => meta.page < meta.totalPages;
}
