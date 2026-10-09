import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_service.dart';
import '../scan_widgets.dart';

class EmailTab extends StatefulWidget {
  const EmailTab({super.key});

  @override
  State<EmailTab> createState() => _EmailTabState();
}

class _EmailTabState extends State<EmailTab> with ScanRunner<EmailTab> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.trim().isNotEmpty) {
      setState(() => _controller.text = text);
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
                  child: Text('🔎 Scan Email'),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          ScanOutput(loading: loading, error: error, result: result),
        ],
      ),
    );
  }
}