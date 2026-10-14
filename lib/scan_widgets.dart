import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'l10n/app_strings.dart';

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

/// Remembers the Simple / Technical choice while the app is open.
final ValueNotifier<bool> kTechnicalView = ValueNotifier<bool>(false);

enum _Level { safe, warn, danger }

/// Text for [key], or [fallback] when the key has no translation.
String _tOr(BuildContext context, String key, String fallback) {
  final value = context.t(key);
  return value == key ? fallback : value;
}

/// The strongest factors first, without zero-value ones: [(name, value), ...]
List<MapEntry<String, double>> _topFactors(Object? raw, int count) {
  final out = <MapEntry<String, double>>[];
  if (raw is List) {
    for (final item in raw) {
      if (item is List && item.length >= 2 && item[0] is String && item[1] is num) {
        final value = (item[1] as num).toDouble();
        if (value != 0) out.add(MapEntry(item[0] as String, value));
      }
    }
  }
  out.sort((a, b) => b.value.abs().compareTo(a.value.abs()));
  return out.take(count).toList();
}

/// Plain-language name of a factor. Works for URL, email, account and APK names
/// (APK names may come with or without the "android.permission." prefix).
String _factorName(BuildContext context, String raw) {
  var key = raw.trim();
  const prefix = 'android.permission.';
  if (key.toLowerCase().startsWith(prefix)) key = key.substring(prefix.length);
  // Email word features arrive as "tfidf_<word>"
  if (key.toLowerCase().startsWith('tfidf_')) {
    return context.t('f.tfidf', {'word': key.substring(6)});
  }
  final id = 'f.${key.toLowerCase()}';
  final text = context.t(id);
  // Unknown factor: fall back to a tidied-up version of the raw name
  return text == id ? ResultView.pretty(key) : text;
}

/// One result screen for every agent (URL, email, QR, account, APK),
/// with a Simple view (everyday words, user's language) and a Technical view (English).
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

  /// Known verdict words map directly. An unknown word (for example from the
  /// account agent) is judged by the risk score instead of silently showing green.
  static _Level _levelOf(String verdict, double risk) {
    switch (verdict) {
      case 'phishing':
      case 'malicious':
        return _Level.danger;
      case 'suspicious':
        return _Level.warn;
      case 'safe':
        return _Level.safe;
    }
    if (risk >= 70) return _Level.danger;
    if (risk >= 35) return _Level.warn;
    return _Level.safe;
  }

  static Color _levelColor(_Level level) {
    switch (level) {
      case _Level.danger:
        return AppColors.danger;
      case _Level.warn:
        return AppColors.warn;
      case _Level.safe:
        return AppColors.safe;
    }
  }

  static IconData _levelIcon(_Level level) {
    switch (level) {
      case _Level.danger:
        return Icons.dangerous_outlined;
      case _Level.warn:
        return Icons.warning_amber_rounded;
      case _Level.safe:
        return Icons.verified_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ViewToggle(),
        const SizedBox(height: 14),
        ValueListenableBuilder<bool>(
          valueListenable: kTechnicalView,
          builder: (context, technical, _) => technical
              ? _TechnicalView(result: result)
              : _SimpleView(result: result),
        ),
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: kTechnicalView,
      builder: (context, technical, _) => SegmentedButton<bool>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          foregroundColor: AppColors.muted,
          selectedForegroundColor: AppColors.ink,
          selectedBackgroundColor: AppColors.mintSoft,
        ),
        segments: [
          ButtonSegment<bool>(
            value: false,
            icon: const Icon(Icons.sentiment_satisfied_alt_rounded, size: 18),
            label: Text(context.t('view.simple')),
          ),
          ButtonSegment<bool>(
            value: true,
            icon: const Icon(Icons.analytics_outlined, size: 18),
            label: Text(context.t('view.technical')),
          ),
        ],
        selected: {technical},
        onSelectionChanged: (selection) => kTechnicalView.value = selection.first,
      ),
    );
  }
}

// =============================================================== Simple view

class _SimpleView extends StatelessWidget {
  final Map<String, dynamic> result;

  const _SimpleView({required this.result});

  @override
  Widget build(BuildContext context) {
    final verdict = (result['verdict'] as String?) ?? 'unknown';
    final risk = ((result['risk_score'] as num?) ?? 0).toDouble();
    final level = ResultView._levelOf(verdict, risk);
    final color = ResultView._levelColor(level);
    final factors = _topFactors(result['top_features'], 3);
    final maxAbs = factors.isEmpty ? 1.0 : factors.first.value.abs();
    final riskyPermissions = (result['risky_permissions'] as List?) ?? [];
    final modelSource = result['model_source'] as String?;
    final isApk = result['package_name'] != null;
    final isAccountDemo =
        result['scenario'] != null || result['scenario_description'] != null;

    final verdictWord = _tOr(context, 'verdict.$verdict', verdict.toUpperCase());
    final levelKey = level == _Level.danger
        ? 'danger'
        : (level == _Level.warn ? 'suspicious' : 'safe');
    final riskKey =
        level == _Level.danger ? 'high' : (level == _Level.warn ? 'medium' : 'low');

    String tipKey;
    if (isAccountDemo) {
      tipKey = 'todo.account';
    } else if (isApk && level == _Level.danger) {
      tipKey = 'todo.apk.danger';
    } else if (isApk && level == _Level.warn) {
      tipKey = 'todo.apk.suspicious';
    } else {
      tipKey = 'todo.$levelKey';
    }

    final details = <MapEntry<String, String>>[
      if (result['decoded_url'] != null)
        MapEntry(context.t('detail.decoded'), '${result['decoded_url']}'),
      if (result['app_name'] != null)
        MapEntry(context.t('detail.app'), '${result['app_name']}'),
      if (result['package_name'] != null)
        MapEntry(context.t('detail.package'), '${result['package_name']}'),
      if (result['permission_count'] != null)
        MapEntry(context.t('detail.permissions'), '${result['permission_count']}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Verdict banner with an animated risk meter
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color.withAlpha(35),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(ResultView._levelIcon(level), color: color, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    verdictWord,
                    style: TextStyle(
                        color: color, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Text(context.t('summary.$levelKey'),
                  style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 14),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: (risk / 100).clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 12,
                    color: color,
                    backgroundColor: AppColors.track,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.t('risk.$riskKey'),
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),

        // ---- Honest warnings
        if (modelSource != null && modelSource.startsWith('synthetic')) ...[
          const SizedBox(height: 12),
          _InfoBox(text: context.t('warn.synthetic')),
        ],
        if (isAccountDemo) ...[
          const SizedBox(height: 12),
          _InfoBox(text: context.t('warn.simulated')),
        ],

        // ---- What was found (decoded link, app name, ...)
        if (details.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final d in details)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.key,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  SelectableText(d.value),
                ],
              ),
            ),
        ],

        // ---- Why this result
        if (factors.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(context.t('section.why'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(context.t('why.note'),
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          const SizedBox(height: 10),
          for (final f in factors)
            _FactorRow(
              name: _factorName(context, f.key),
              value: f.value,
              maxAbs: maxAbs,
            ),
        ],

        // ---- Sensitive permissions (APK)
        if (riskyPermissions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(context.t('section.permissions'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in riskyPermissions)
                Chip(
                  label: Text(_factorName(context, '$p'),
                      style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.skySoft,
                  side: BorderSide.none,
                ),
            ],
          ),
        ],

        // ---- What you can do
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.mintSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: AppColors.mintDark),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t('section.todo'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(context.t(tipKey)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Text(context.t('hint.technical'),
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;

  const _InfoBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warn.withAlpha(30),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warn),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  final String name;
  final double value;
  final double maxAbs;

  const _FactorRow({
    required this.name,
    required this.value,
    required this.maxAbs,
  });

  @override
  Widget build(BuildContext context) {
    final raises = value > 0;
    final color = raises ? AppColors.danger : AppColors.safe;
        // Absolute size of the SHAP value, so a weak result never shows "Strong"
    final size = value.abs();
    final influenceKey =
        size >= 0.15 ? 'inf.strong' : (size >= 0.05 ? 'inf.medium' : 'inf.slight');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.track, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(35),
              shape: BoxShape.circle,
            ),
            child: Icon(
              raises ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: context.t(raises ? 'dir.up' : 'dir.down'),
                      style: TextStyle(color: color, fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: '  \u2022  ${context.t(influenceKey)}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ]),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================ Technical view
// Kept in English on purpose: it is for people who read model details.

class _TechnicalView extends StatelessWidget {
  final Map<String, dynamic> result;

  const _TechnicalView({required this.result});

  @override
  Widget build(BuildContext context) {
    final verdict = (result['verdict'] as String?) ?? 'unknown';
    final riskScore = ((result['risk_score'] as num?) ?? 0).toDouble();
    final level = ResultView._levelOf(verdict, riskScore);
    final color = ResultView._levelColor(level);
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
                Icon(ResultView._levelIcon(level), color: color),
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

        // ---- Key factors (raw feature names and values)
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
              title: Text(ResultView.pretty(f[0] as String)),
              subtitle: Text((f[1] as num).toStringAsFixed(3),
                  style: const TextStyle(color: AppColors.faint)),
              trailing: Text(
                (f[1] as num) > 0
                    ? '\u25B2 Increased Risk'
                    : '\u25BC Decreased Risk',
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
              child: Text('\u2022 $e'),
            ),
        ],

        // ---- Full report (English, from the server)
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
