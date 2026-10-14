import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_service.dart';
import '../app_theme.dart';
import '../l10n/app_strings.dart';
import '../scan_widgets.dart';
import '../share_inbox.dart';

class QrTab extends StatefulWidget {
  const QrTab({super.key});

  @override
  State<QrTab> createState() => _QrTabState();
}

class _QrTabState extends State<QrTab> with ScanRunner<QrTab> {
  static const int _maxBytes = 5 * 1024 * 1024; // same limit as the server

  final ImagePicker _picker = ImagePicker();
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    ShareInbox.current.addListener(_onShare);
  }

  @override
  void dispose() {
    ShareInbox.current.removeListener(_onShare);
    super.dispose();
  }

  void _onShare() {
    final request = ShareInbox.current.value;
    if (request == null || request.kind != ShareKind.qr) return;
    final path = request.path;
    if (path == null) return;
    _scanShared(path, request.name ?? 'shared_image');
  }

  Future<void> _scanShared(String path, String name) async {
    setState(() {
      _imagePath = path;
      result = null;
      error = null;
    });
    try {
      final size = await File(path).length();
      if (!mounted) return;
      if (size > _maxBytes) {
        setState(() => error = context.t('qr.err.large'));
        return;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => error = context.t('qr.err.read'));
      return;
    }
    runScan(() => ApiService.analyzeQr(path, name));
  }

  Future<void> _pick(ImageSource source) async {
    try {
      // maxWidth keeps camera photos well under the server's 5 MB limit
      final XFile? file = await _picker.pickImage(source: source, maxWidth: 1600);
      if (file == null) return;
      setState(() => _imagePath = file.path);
      runScan(() => ApiService.analyzeQr(file.path, file.name));
    } catch (_) {
      if (!mounted) return;
      setState(() => error = context.t('qr.err.picker'));
    }
  }

  @override
  Widget build(BuildContext context) {
    // The server's "no QR code" message is English, so it is swapped for the translated one
    String? shownError = error;
    if (shownError != null && shownError.contains('No QR code')) {
      shownError = context.t('qr.err.none');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('qr.desc')),
          const SizedBox(height: 6),
          Text(
            context.t('qr.tip'),
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: loading ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera),
                label: Text(context.t('qr.camera')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: loading ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: Text(context.t('qr.gallery')),
              ),
            ),
          ]),
          if (_imagePath != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(_imagePath!), height: 200, fit: BoxFit.contain),
            ),
          ],
          const SizedBox(height: 16),
          ScanOutput(
            loading: loading,
            error: shownError,
            result: result,
            loadingText: context.t('scan.loading'),
          ),
        ],
      ),
    );
  }
}
