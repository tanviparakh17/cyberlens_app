import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api_service.dart';
import '../l10n/app_strings.dart';
import '../scan_widgets.dart';
import '../app_theme.dart';
import '../share_inbox.dart';

class ApkTab extends StatefulWidget {
  const ApkTab({super.key});

  @override
  State<ApkTab> createState() => _ApkTabState();
}

class _ApkTabState extends State<ApkTab> with ScanRunner<ApkTab> {
  static const int _maxBytes = 25 * 1024 * 1024; // same limit as the server

  PlatformFile? _file;
  bool _fromShare = false;

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

  void _reject(String message) {
    setState(() {
      _file = null;
      _fromShare = false;
      result = null;
      error = message;
    });
  }

  /// Returns true if the file can be scanned; otherwise shows the reason.
  bool _check(PlatformFile file) {
    if (!file.name.toLowerCase().endsWith('.apk')) {
      _reject(context.t('err.apkext'));
      return false;
    }
    if (file.size > _maxBytes) {
      _reject(context.t('err.apksize'));
      return false;
    }
    if (file.path == null) {
      _reject(context.t('err.apkread'));
      return false;
    }
    return true;
  }

  void _onShare() {
    final request = ShareInbox.current.value;
    if (request == null || request.kind != ShareKind.apk) return;
    final path = request.path;
    if (path == null) return;
    _prepareShared(path, request.name ?? path.split(RegExp(r'[\\/]')).last);
  }

  Future<void> _prepareShared(String path, String name) async {
    int size;
    try {
      size = await File(path).length();
    } catch (_) {
      if (!mounted) return;
      _reject(context.t('err.sharedread'));
      return;
    }
    if (!mounted) return;
    final file = PlatformFile(name: name, size: size, path: path);
    if (!_check(file)) return;
    // Wait for the person to confirm: scanning uploads the whole APK
    setState(() {
      _file = file;
      _fromShare = true;
      result = null;
      error = null;
    });
  }

  Future<void> _pick() async {
    try {
      // FileType.any, because some phones do not offer .apk under custom filters
      final picked = await FilePicker.platform.pickFiles(type: FileType.any);
      if (picked == null || picked.files.isEmpty) return;

      final file = picked.files.single;
      if (!_check(file)) return;
      setState(() {
        _file = file;
        _fromShare = false;
        result = null;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => error = context.t('err.picker'));
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
          Text(context.t('apk.intro')),
          const SizedBox(height: 6),
          Text(context.t('apk.slow'),
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: loading ? null : _pick,
            icon: const Icon(Icons.folder_open),
            label: Text(context.t('apk.choose')),
          ),
          if (file != null) ...[
            const SizedBox(height: 12),
            if (_fromShare)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  context.t('apk.shared'),
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.android),
              title: Text(file.name),
              subtitle: Text('${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB'),
            ),
            ElevatedButton(
              onPressed: loading ? null : _scan,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_fromShare
                    ? '\u{1F50E} ${context.t('btn.scanapk.q')}'
                    : '\u{1F50E} ${context.t('btn.scanapk')}'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ScanOutput(
            loading: loading,
            error: error,
            result: result,
            loadingText: context.t('load.apk'),
          ),
        ],
      ),
    );
  }
}
