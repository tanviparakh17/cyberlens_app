import 'package:flutter/material.dart';

import '../api_service.dart';
import '../app_theme.dart';
import '../l10n/app_strings.dart';
import '../scan_widgets.dart';

// ---------------------------------------------------------------------------
// Checklist rules (no machine learning here, just simple rules)
// ---------------------------------------------------------------------------

/// How much each checklist question counts (index = question number, see chk.q0 ... chk.q6).
const List<int> _questionWeights = [2, 3, 3, 3, 2, 3, 1];

/// Questions that are strong signs of a takeover on their own.
const Set<int> _criticalQuestions = {1, 2, 3, 5};

/// Risk level for the ticked questions: 'none', 'low', 'medium' or 'high'.
String assessAccountRisk(Set<int> ticked) {
  if (ticked.isEmpty) return 'none';
  var score = 0;
  var critical = 0;
  for (final q in ticked) {
    score += _questionWeights[q];
    if (_criticalQuestions.contains(q)) critical++;
  }
  if (critical >= 2 || score >= 6) return 'high';
  if (critical >= 1 || score >= 3) return 'medium';
  return 'low';
}

/// Text keys of the "what to do now" steps, in order, for each level.
const Map<String, List<String>> _actionsByLevel = {
  'high': [
    'act.password',
    'act.logout',
    'act.twofa',
    'act.warn',
    'act.platforms',
    'act.report',
  ],
  'medium': ['act.password', 'act.logout', 'act.twofa', 'act.noclick'],
  'low': ['act.watch', 'act.twofa', 'act.unique'],
  'none': ['act.twofa', 'act.unique'],
};

class _Platform {
  final String code; // text keys: '<code>.title', '<code>.1' ... '<code>.<steps>'
  final int steps;

  const _Platform(this.code, this.steps);
}

const List<_Platform> _platforms = [
  _Platform('plat.ig', 4),
  _Platform('plat.wa', 4),
  _Platform('plat.gm', 4),
];

class _HowCard {
  final String keyBase; // text keys: '<keyBase>.t' (title) and '<keyBase>.d' (description)
  final IconData icon;
  final int? page; // checker to open: 1 = link, 2 = email, 3 = QR, 5 = APK (null = no button)

  const _HowCard(this.keyBase, this.icon, this.page);
}

const List<_HowCard> _howCards = [
  _HowCard('how.url', Icons.link, 1),
  _HowCard('how.email', Icons.mail_outline, 2),
  _HowCard('how.qr', Icons.qr_code_scanner, 3),
  _HowCard('how.apk', Icons.android, 5),
  _HowCard('how.pw', Icons.lock_outline, null),
];

// ---------------------------------------------------------------------------
// The tab
// ---------------------------------------------------------------------------

class AccountTab extends StatefulWidget {
  /// Opens another checker. The numbers are the same as in the home menu
  /// (1 = link, 2 = email, 3 = QR, 5 = APK). When null, the cards show no button.
  final void Function(int page)? onOpenChecker;

  const AccountTab({super.key, this.onOpenChecker});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> with ScanRunner<AccountTab> {
  // Checklist
  final Set<int> _ticked = {};
  bool _assessed = false;

  // Detection demo (simulated scenarios from the server)
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
      setState(() => _scenarioError = context.t('demo.loaderr'));
    } finally {
      if (mounted) setState(() => _loadingScenarios = false);
    }
  }

  void _scan() {
    final id = _selected;
    if (id == null) return;
    runScan(() => ApiService.analyzeAccount(id));
  }

  /// Translated scenario name, or the English name made readable when there is no translation.
  String _scenarioLabel(String id) {
    final key = 'sc.$id';
    final text = context.t(key);
    return text == key ? ResultView.pretty(id) : text;
  }

  /// Translated scenario description, or the server's English description.
  String _scenarioDescription(String id) {
    final key = 'sc.$id.desc';
    final text = context.t(key);
    if (text != key) return text;
    for (final s in _scenarios) {
      if (s['id'] == id) return '${s['description']}';
    }
    return '';
  }

  // ---- Small building blocks ------------------------------------------------

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.track, width: 1.5),
        ),
        child: child,
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );

  Widget _noDividers({required Widget child}) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: child,
      );

  String _stepText(_Platform platform, int number) =>
      context.t('${platform.code}.$number');

  // ---- Section 1: "Was my account hacked?" checklist ---------------------------

  Widget _checklistCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('chk.title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(context.t('chk.desc'),
              style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 8),
          for (var i = 0; i < _questionWeights.length; i++)
            CheckboxListTile(
              value: _ticked.contains(i),
              onChanged: (value) => setState(() {
                if (value == true) {
                  _ticked.add(i);
                } else {
                  _ticked.remove(i);
                }
                _assessed = false;
              }),
              title: Text(context.t('chk.q$i'),
                  style: const TextStyle(fontSize: 14)),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.mintDark,
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() => _assessed = true),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(context.t('chk.button')),
                ),
              ),
            ),
            if (_ticked.isNotEmpty || _assessed) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() {
                  _ticked.clear();
                  _assessed = false;
                }),
                child: Text(context.t('chk.reset')),
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _assessmentCard() {
    final level = assessAccountRisk(_ticked);
    final color = level == 'high'
        ? AppColors.danger
        : level == 'medium'
            ? AppColors.warn
            : AppColors.safe;
    final actions = _actionsByLevel[level]!;
    final showRecovery = level == 'high' || level == 'medium';

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('chk.level.$level'),
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(context.t('chk.sum.$level')),
          const SizedBox(height: 12),
          Text(context.t('chk.todo'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          for (var i = 0; i < actions.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}. '),
                  Expanded(child: Text(context.t(actions[i]))),
                ],
              ),
            ),
          if (showRecovery) ...[
            const SizedBox(height: 12),
            Text(context.t('chk.recover'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            for (final platform in _platforms) _platformTile(platform),
            Text(context.t('plat.note'),
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }

  Widget _platformTile(_Platform platform) {
    return _noDividers(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(context.t('${platform.code}.title'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        children: [
          for (var i = 1; i <= platform.steps; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('• ${_stepText(platform, i)}'),
            ),
        ],
      ),
    );
  }

  // ---- Section 2: "How do accounts get hacked?" ---------------------------------

  Widget _howCard(_HowCard card) {
    final open = widget.onOpenChecker;
    final page = card.page;
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.mintSoft,
            child: Icon(card.icon, color: AppColors.mintDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.t('${card.keyBase}.t'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(context.t('${card.keyBase}.d'),
                    style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                if (page != null && open != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => open(page),
                    child: Text(context.t('how.open')),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Section 3: detection engine demo (simulated) -----------------------------

  Widget _demoCard() {
    return _card(
      child: _noDividers(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          title: Text(context.t('demo.title'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          children: [
            Text(context.t('demo.desc'),
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            if (_loadingScenarios)
              const Center(child: CircularProgressIndicator())
            else if (_scenarioError != null) ...[
              Text(_scenarioError!,
                  style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _loadScenarios,
                child: Text(context.t('demo.retry')),
              ),
            ] else ...[
              DropdownButton<String>(
                isExpanded: true,
                value: _selected,
                items: [
                  for (final s in _scenarios)
                    DropdownMenuItem<String>(
                      value: s['id'] as String,
                      child: Text(_scenarioLabel(s['id'] as String)),
                    ),
                ],
                onChanged: loading ? null : (v) => setState(() => _selected = v),
              ),
              if (_selected != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(_scenarioDescription(_selected!),
                      style: const TextStyle(color: AppColors.muted)),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: (loading || _selected == null) ? null : _scan,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(context.t('demo.button')),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ScanOutput(loading: loading, error: error, result: result),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('acc.intro')),
          const SizedBox(height: 4),
          Text(context.t('acc.note'),
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 16),
          _checklistCard(),
          if (_assessed) _assessmentCard(),
          const SizedBox(height: 12),
          _sectionTitle(context.t('how.title')),
          for (final card in _howCards) _howCard(card),
          const SizedBox(height: 12),
          _demoCard(),
        ],
      ),
    );
  }
}