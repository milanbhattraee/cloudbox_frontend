import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/byte_formatter.dart';
import '../../core/utils/save_file/save_file.dart';
import '../../models/cloud_file.dart';
import '../../services/file_service.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_view.dart';

class ImagePreviewScreen extends StatefulWidget {
  final CloudFile file;
  const ImagePreviewScreen({super.key, required this.file});

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  final _fileService = FileService();
  Uint8List? _bytes;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _fileService.downloadBytes(widget.file.id);
      if (!mounted) return;
      setState(() => _bytes = Uint8List.fromList(data));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.displayMessage : e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadOrOpen() async {
    if (_bytes == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Web: triggers the browser's download flow directly.
      // Mobile/desktop: writes to app storage and opens with the system viewer.
      await saveAndOpenBytes(_bytes!, widget.file.originalName, mimeType: widget.file.mimeType);
      if (!kIsWeb) {
        messenger.showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Download failed: $e')));
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
            icon: const Icon(Icons.download_rounded),
            tooltip: kIsWeb ? 'Download' : 'Save & open',
            onPressed: _bytes == null ? null : _downloadOrOpen,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingView(message: 'Loading preview...')
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5,
                    child: Image.memory(_bytes!, fit: BoxFit.contain),
                  ),
                ),
      bottomNavigationBar: _bytes != null
          ? Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                formatBytes(widget.file.size),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            )
          : null,
    );
  }
}
