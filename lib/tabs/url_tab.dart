import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_service.dart';
import '../scan_widgets.dart';

class UrlTab extends StatefulWidget {
  const UrlTab({super.key});

  @override
  State<UrlTab> createState() => _UrlTabState();
}

class _UrlTabState extends State<UrlTab> with ScanRunner<UrlTab> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      setState(() => _controller.text = text);
    }
  }

  void _scan() {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => error = 'Please enter a URL first.');
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
                tooltip: 'Paste',
                onPressed: _paste,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: loading ? null : _scan,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('🔎 Scan URL'),
            ),
          ),
          const SizedBox(height: 16),
          ScanOutput(loading: loading, error: error, result: result),
        ],
      ),
    );
  }
}