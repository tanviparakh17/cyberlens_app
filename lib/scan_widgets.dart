import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_theme.dart';

/// Shared loading / error / result state for every scan tab.
mixin ScanRunner<T extends StatefulWidget> on State<T> {
  bool loading = false;
  String? error;
  Map<String, dynamic>? result;

  Future<void> runScan(Future<Map<String, dynamic>> Function() call) async {
    setState(() {
      loading = true;
      error = null;
      result = null;
    });
    try {
      final data = await call();
      if (!mounted) return;
      setState(() => result = data);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

/// Shows the spinner, the error text, or the result, depending on the state.
class ScanOutput extends StatelessWidget {
  final bool loading;
  final String? error;
  final Map<String, dynamic>? result;
  final String loadingText;

  const ScanOutput({
    super.key,
    required this.loading,
    required this.error,
    required this.result,
    this.loadingText =
        'Scanning... if the server is waking up, this can take up to 50 seconds.',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading)
          Column(children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text(loadingText, textAlign: TextAlign.center),
          ]),
        if (error != null)
          Text(error!, style: const TextStyle(color: AppColors.danger)),
        if (result != null) ResultView(result: result!),
      ],
    );
  }
}

/// One result screen for every agent (URL, email, QR, account, APK).
class ResultView extends StatelessWidget {
  final Map<String, dynamic> result;

  const ResultView({super.key, required this.result});

  // "has_suspicious_keyword" -> "Has Suspicious Keyword"
  static String pretty(String name) => name
      .split('_')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  static Color verdictColor(String verdict) {
    switch (verdict) {
      case 'phishing':
      case 'malicious':
        return AppColors.danger;
      case 'suspicious':
        return AppColors.warn;
      default:
        return AppColors.safe;
    }
  }

  static IconData verdictIcon(String verdict) {
    switch (verdict) {
      case 'phishing':
      case 'malicious':
        return Icons.dangerous_outlined;
      case 'suspicious':
        return Icons.warning_amber_rounded;
      default:
        return Icons.verified_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final verdict = (result['verdict'] as String?) ?? 'unknown';
    final color = verdictColor(verdict);
    final riskScore = ((result['risk_score'] as num?) ?? 0).toDouble();
    final confidencePct = result['confidence_pct'];
    final factors = (result['top_features'] as List?) ?? [];
    final evidence = (result['evidence'] as List?) ?? [];
    final riskyPermissions = (result['risky_permissions'] as List?) ?? [];
    final explanationType = result['explanation_type'] as String?;
    final modelSource = result['model_source'] as String?;
    final report = result['report'] as String?;

    // Optional per-agent details, shown only when the backend sends them
    final details = <MapEntry<String, String>>[
      if (result['decoded_url'] != null)
        MapEntry('Decoded URL', '${result['decoded_url']}'),
      if (result['scenario_description'] != null)
        MapEntry('Scenario', '${result['scenario_description']}'),
      if (result['app_name'] != null) MapEntry('App', '${result['app_name']}'),
      if (result['package_name'] != null)
        MapEntry('Package', '${result['package_name']}'),
      if (result['permission_count'] != null)
        MapEntry('Permissions requested', '${result['permission_count']}'),
      if (result['sha256'] != null) MapEntry('SHA-256', '${result['sha256']}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Verdict banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withAlpha(40),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(verdictIcon(verdict), color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    verdict.toUpperCase(),
                    style: TextStyle(
                        color: color, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Text('Risk score: ${riskScore.round()}/100'),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (riskScore / 100).clamp(0.0, 1.0),
                color: color,
                backgroundColor: AppColors.track,
                minHeight: 8,
              ),
              if (confidencePct != null) ...[
                const SizedBox(height: 8),
                Text('Model confidence: $confidencePct%'),
              ],
            ],
          ),
        ),

        // ---- Warning when the model was trained on synthetic data
        if (modelSource != null && modelSource.startsWith('synthetic')) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warn.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'This model was trained on synthetic permission profiles, not real '
              'malware samples. Treat the score as indicative only.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],

        // ---- Details (decoded URL, app name, package, hash, ...)
        if (details.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final d in details)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(d.key, style: const TextStyle(color: AppColors.muted)),
                  ),
                  Expanded(child: SelectableText(d.value)),
                ],
              ),
            ),
        ],

        // ---- Key factors
        if (factors.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(children: [
            const Text('Key Risk Factors',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (explanationType != null)
              Text(explanationType == 'shap' ? 'Explained with SHAP' : 'Rule-based',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
          const SizedBox(height: 8),
          for (final f in factors)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(pretty(f[0] as String)),
              subtitle: Text((f[1] as num).toStringAsFixed(3),
                  style: const TextStyle(color: AppColors.faint)),
              trailing: Text(
                (f[1] as num) > 0 ? '▲ Increased Risk' : '▼ Decreased Risk',
                style: TextStyle(
                  color: (f[1] as num) > 0 ? AppColors.danger : AppColors.safe,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],

        // ---- Risky permissions (APK)
        if (riskyPermissions.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Sensitive Permissions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in riskyPermissions)
                Chip(
                  label: Text(
                    (p as String).replaceFirst('android.permission.', ''),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
        ],

        // ---- Evidence (APK)
        if (evidence.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Evidence',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final e in evidence)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• $e'),
            ),
        ],

        // ---- Full report
        if (report != null) ...[
          const SizedBox(height: 16),
          Card(
            color: AppColors.surfaceTint,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(report),
            ),
          ),
        ],
      ],
    );
  }
}