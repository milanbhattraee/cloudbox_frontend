import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom cache manager for CloudBox images with optimized settings
class CloudBoxCacheManager {
  static const key = 'cloudbox_image_cache';
  
  static CacheManager instance = CacheManager(
    Config(
      key,
      // Cache for 30 days
      stalePeriod: const Duration(days: 30),
      // Maximum 500 cached objects
      maxNrOfCacheObjects: 500,
      // Cleanup when app starts
      repo: JsonCacheInfoRepository(databaseName: key),
      // Clean expired cache entries automatically
      fileService: HttpFileService(),
    ),
  );
}
