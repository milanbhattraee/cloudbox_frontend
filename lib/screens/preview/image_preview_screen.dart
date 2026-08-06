import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/utils/byte_formatter.dart';
import '../../core/utils/image_cache_manager.dart';
import '../../core/utils/save_file/save_file.dart';
import '../../models/cloud_file.dart';
import '../../services/file_service.dart';

class ImagePreviewScreen extends StatefulWidget {
  final CloudFile file;
  const ImagePreviewScreen({super.key, required this.file});

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  final _fileService = FileService();
  bool _isDownloading = false;

  Future<void> _downloadAndOpen() async {
    if (_isDownloading) return;
    
    setState(() => _isDownloading = true);
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      final bytes = await _fileService.downloadBytes(widget.file.id);
      if (!mounted) return;
      
      await saveAndOpenBytes(bytes, widget.file.originalName, mimeType: widget.file.mimeType);
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('File saved')));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.file.originalName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: _isDownloading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded),
            tooltip: 'Save & open',
            onPressed: _isDownloading ? null : _downloadAndOpen,
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: 'image_${widget.file.id}',
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: CachedNetworkImage(
              imageUrl: widget.file.path,
              cacheManager: CloudBoxCacheManager.instance,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (context, url, error) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          formatBytes(widget.file.size),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
