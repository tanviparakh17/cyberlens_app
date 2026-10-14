import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_service.dart';
import '../l10n/app_strings.dart';
import '../scan_widgets.dart';
import '../share_inbox.dart';

class UrlTab extends StatefulWidget {
  const UrlTab({super.key});

  @override
  State<UrlTab> createState() => _UrlTabState();
}

class _UrlTabState extends State<UrlTab> with ScanRunner<UrlTab> {
  final TextEditingController _controller = TextEditingController();

  // Full text of the last share that landed here (for the "Wrong tab?" button)
  String? _sharedOriginal;

  @override
  void initState() {
    super.initState();
    ShareInbox.current.addListener(_onShare);
  }

  @override
  void dispose() {
    ShareInbox.current.removeListener(_onShare);
    _controller.dispose();
    super.dispose();
  }

  void _onShare() {
    final request = ShareInbox.current.value;
    if (request == null || request.kind != ShareKind.url) return;
    setState(() {
      _controller.text = request.text;
      _sharedOriginal = request.original;
      result = null;
      error = null;
    });
    if (request.autoScan) _scan();
  }

  void _scanAsEmail() {
    final original = _sharedOriginal;
    if (original == null) return;
    ShareInbox.send(ShareInbox.build(ShareKind.email, original, autoScan: true));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      setState(() {
        _controller.text = text;
        _sharedOriginal = null;
      });
    }
  }

  void _scan() {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => error = context.t('err.enterurl'));
      return;
    }
    runScan(() => ApiService.analyzeUrl(url));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'https://example-login-auth.com/secure',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste),
                tooltip: context.t('btn.paste'),
                onPressed: _paste,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: loading ? null : _scan,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('\u{1F50E} ${context.t('btn.scanurl')}'),
            ),
          ),
          if (_sharedOriginal != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: loading ? null : _scanAsEmail,
                child: Text(context.t('btn.wrongemail')),
              ),
            ),
          const SizedBox(height: 16),
          ScanOutput(loading: loading, error: error, result: result),
        ],
      ),
    );
  }
}
