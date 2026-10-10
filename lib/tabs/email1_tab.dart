import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_service.dart';
import '../scan_widgets.dart';
import '../share_inbox.dart';

class EmailTab extends StatefulWidget {
  const EmailTab({super.key});

  @override
  State<EmailTab> createState() => _EmailTabState();
}

class _EmailTabState extends State<EmailTab> with ScanRunner<EmailTab> {
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
    if (request == null || request.kind != ShareKind.email) return;
    setState(() {
      _controller.text = request.text;
      _sharedOriginal = request.original;
      result = null;
      error = null;
    });
    if (request.autoScan) _scan();
  }

  void _scanAsUrl() {
    final original = _sharedOriginal;
    if (original == null) return;
    ShareInbox.send(ShareInbox.build(ShareKind.url, original, autoScan: true));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.trim().isNotEmpty) {
      setState(() {
        _controller.text = text;
        _sharedOriginal = null;
      });
    }
  }

  void _scan() {
    final text = _controller.text.trim();
    if (text.length < 10) {
      setState(() => error = 'Please paste the full email text first.');
      return;
    }
    runScan(() => ApiService.analyzeEmail(text));
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
            minLines: 8,
            maxLines: 14,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: 'Paste the full email (subject and body) here',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(
              onPressed: _paste,
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: loading ? null : _scan,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('\u{1F50E} Scan Email'),
                ),
              ),
            ),
          ]),
          if (_sharedOriginal != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: loading ? null : _scanAsUrl,
                child: const Text('Wrong tab? Scan as URL'),
              ),
            ),
          const SizedBox(height: 16),
          ScanOutput(loading: loading, error: error, result: result),
        ],
      ),
    );
  }
}
