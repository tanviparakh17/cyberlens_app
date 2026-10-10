import 'package:flutter/material.dart';

import '../api_service.dart';
import '../scan_widgets.dart';
import '../app_theme.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> with ScanRunner<AccountTab> {
  List<Map<String, dynamic>> _scenarios = [];
  String? _selected;
  bool _loadingScenarios = true;
  String? _scenarioError;

  @override
  void initState() {
    super.initState();
    _loadScenarios();
  }

  Future<void> _loadScenarios() async {
    setState(() {
      _loadingScenarios = true;
      _scenarioError = null;
    });
    try {
      final list = await ApiService.getScenarios();
      if (!mounted) return;
      setState(() {
        _scenarios = list;
        _selected = list.isNotEmpty ? list.first['id'] as String : null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _scenarioError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _scenarioError = 'Could not load the scenarios.');
    } finally {
      if (mounted) setState(() => _loadingScenarios = false);
    }
  }

  String _descriptionOf(String id) {
    for (final s in _scenarios) {
      if (s['id'] == id) return '${s['description']}';
    }
    return '';
  }

  void _scan() {
    final id = _selected;
    if (id == null) return;
    runScan(() => ApiService.analyzeAccount(id));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Demo mode: pick a simulated message-activity scenario and CyberLens '
            'checks it for signs of an account takeover. No real messages are read.',
          ),
          const SizedBox(height: 12),
          if (_loadingScenarios)
            const Center(child: CircularProgressIndicator())
          else if (_scenarioError != null) ...[
            Text(_scenarioError!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _loadScenarios, child: const Text('Retry')),
          ] else ...[
            DropdownButton<String>(
              isExpanded: true,
              value: _selected,
              items: [
                for (final s in _scenarios)
                  DropdownMenuItem<String>(
                    value: s['id'] as String,
                    child: Text(ResultView.pretty(s['id'] as String)),
                  ),
              ],
              onChanged: loading ? null : (v) => setState(() => _selected = v),
            ),
            if (_selected != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(_descriptionOf(_selected!),
                    style: const TextStyle(color: AppColors.muted)),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: (loading || _selected == null) ? null : _scan,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('🔎 Check Account Activity'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ScanOutput(loading: loading, error: error, result: result),
        ],
      ),
    );
  }
}