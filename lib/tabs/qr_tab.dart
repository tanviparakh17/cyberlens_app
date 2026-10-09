import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_service.dart';
import '../scan_widgets.dart';

class QrTab extends StatefulWidget {
  const QrTab({super.key});

  @override
  State<QrTab> createState() => _QrTabState();
}

class _QrTabState extends State<QrTab> with ScanRunner<QrTab> {
  final ImagePicker _picker = ImagePicker();
  String? _imagePath;

  Future<void> _pick(ImageSource source) async {
    try {
      // maxWidth keeps camera photos well under the server's 5 MB limit
      final XFile? file = await _picker.pickImage(source: source, maxWidth: 1600);
      if (file == null) return;
      setState(() => _imagePath = file.path);
      runScan(() => ApiService.analyzeQr(file.path, file.name));
    } catch (_) {
      setState(() => error = 'Could not open the image picker. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Take a clear, straight-on photo of a QR code, or pick one from your gallery. '
            'The link inside is decoded and checked for phishing.',
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: loading ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: loading ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
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
          ScanOutput(loading: loading, error: error, result: result),
        ],
      ),
    );
  }
}