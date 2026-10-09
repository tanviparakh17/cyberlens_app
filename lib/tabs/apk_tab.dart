import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api_service.dart';
import '../scan_widgets.dart';

class ApkTab extends StatefulWidget {
  const ApkTab({super.key});

  @override
  State<ApkTab> createState() => _ApkTabState();
}

class _ApkTabState extends State<ApkTab> with ScanRunner<ApkTab> {
  static const int _maxBytes = 25 * 1024 * 1024; // same limit as the server

  PlatformFile? _file;

  Future<void> _pick() async {
    try {
      // FileType.any, because some phones do not offer .apk under custom filters
      final picked = await FilePicker.platform.pickFiles(type: FileType.any);
      if (picked == null || picked.files.isEmpty) return;

      final file = picked.files.single;
      if (!file.name.toLowerCase().endsWith('.apk')) {
        setState(() {
          _file = null;
          result = null;
          error = 'Please choose an .apk file.';
        });
        return;
      }
      if (file.size > _maxBytes) {
        setState(() {
          _file = null;
          result = null;
          error = 'This APK is larger than 25 MB, which is the upload limit.';
        });
        return;
      }
      if (file.path == null) {
        setState(() {
          _file = null;
          result = null;
          error = 'Could not read the selected file. Please try another one.';
        });
        return;
      }
      setState(() {
        _file = file;
        result = null;
        error = null;
      });
    } catch (_) {
      setState(() => error = 'Could not open the file picker. Please try again.');
    }
  }

  void _scan() {
    final file = _file;
    if (file == null || file.path == null) return;
    runScan(() => ApiService.analyzeApk(file.path!, file.name));
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pick an APK file (up to 25 MB). CyberLens analyses the permissions it '
            'requests and explains which ones raise the risk.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: loading ? null : _pick,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose APK file'),
          ),
          if (file != null) ...[
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.android),
              title: Text(file.name),
              subtitle: Text('${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'),
            ),
            ElevatedButton(
              onPressed: loading ? null : _scan,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('🔎 Scan APK'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ScanOutput(
            loading: loading,
            error: error,
            result: result,
            loadingText: 'Uploading and analysing the APK... this can take up to a minute.',
          ),
        ],
      ),
    );
  }
}