import 'package:flutter/foundation.dart';

/// Which scanner tab a shared item should go to.
enum ShareKind { url, email, qr, apk }

class ShareRequest {
  final ShareKind kind;

  /// Text kinds: what goes into the tab's text field (for URL: just the link).
  final String text;

  /// Text kinds: the full text that was shared, kept for the "Wrong tab?" button.
  final String original;

  final bool autoScan;

  /// File kinds (qr, apk): local path and name of the shared file.
  final String? path;
  final String? name;

  const ShareRequest({
    required this.kind,
    this.text = '',
    this.original = '',
    this.autoScan = false,
    this.path,
    this.name,
  });
}

/// Small bridge between the share listener (main.dart) and the scan tabs.
class ShareInbox {
  static final ValueNotifier<ShareRequest?> current =
      ValueNotifier<ShareRequest?>(null);

  static final RegExp _urlPattern =
      RegExp(r'(https?://\S+|www\.\S+)', caseSensitive: false);
  static final RegExp _whitespace = RegExp(r'\s');

  static void send(ShareRequest request) => current.value = request;

  /// Builds a text request for a chosen tab (also used by the "Wrong tab?" buttons).
  static ShareRequest build(ShareKind kind, String original,
      {required bool autoScan}) {
    final full = original.trim();
    if (kind == ShareKind.url) {
      final match = _urlPattern.firstMatch(full);
      return ShareRequest(
        kind: kind,
        text: match?.group(0) ?? full,
        original: full,
        autoScan: autoScan,
      );
    }
    return ShareRequest(kind: kind, text: full, original: full, autoScan: autoScan);
  }

  /// Decides the tab for text shared from another app.
  /// Link -> URL tab with auto-scan. Anything else -> Email tab, no auto-scan,
  /// so the person can review a private email before it is sent to the server.
  static ShareRequest routeText(String raw) {
    final text = raw.trim();
    final hasLink = _urlPattern.hasMatch(text);
    final noSpaces = !_whitespace.hasMatch(text);
    final isLink = hasLink && (noSpaces || text.length <= 200);
    return build(
      isLink ? ShareKind.url : ShareKind.email,
      text,
      autoScan: isLink,
    );
  }
}
