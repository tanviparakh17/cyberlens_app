import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings_en.dart';
import 'strings_hi.dart';
import 'strings_mr.dart';

/// One language the app can show.
class AppLanguage {
  final String code; // e.g. 'hi'
  final String nativeName; // shown in its own script
  final bool beta; // true until a native speaker has reviewed the translation

  const AppLanguage(this.code, this.nativeName, {this.beta = true});
}

/// Languages shown in the picker. To add one: add it here, in _tables, and write one strings file.
const List<AppLanguage> kLanguages = [
  AppLanguage('en', 'English', beta: false),
  AppLanguage('hi', 'हिन्दी'),
  AppLanguage('mr', 'मराठी'),
];

const Map<String, Map<String, String>> _tables = {
  'en': stringsEn,
  'hi': stringsHi,
  'mr': stringsMr,
};

/// Holds the chosen language, saves it, and looks up texts.
class LocaleController extends ChangeNotifier {
  static const String _prefKey = 'app_language';

  String _code = 'en';
  bool _chosen = false;

  String get code => _code;

  /// False on the very first launch (the language picker is shown then).
  bool get hasChosen => _chosen;

  /// Reads the saved language. Call once before runApp.
  Future<void> load() async {
    assert(() {
      // Debug-only reminder of keys a translation has not covered yet
      for (final entry in _tables.entries) {
        final missing = stringsEn.keys.where((k) => !entry.value.containsKey(k));
        if (missing.isNotEmpty) {
          debugPrint('[i18n] ${entry.key} is missing: ${missing.join(', ')}');
        }
      }
      return true;
    }());
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null && _tables.containsKey(saved)) {
        _code = saved;
        _chosen = true;
      }
    } catch (_) {
      // Storage not available: the picker will simply show again next time
    }
  }

  Future<void> setLanguage(String code) async {
    if (!_tables.containsKey(code)) return;
    _code = code;
    _chosen = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, code);
    } catch (_) {
      // The choice still works for this session
    }
  }

  /// Text for [key] in the current language. Falls back to English, then to the key itself,
  /// so a missing translation can never crash the app.
  String text(String key, [Map<String, String>? args]) {
    var value = _tables[_code]?[key] ?? stringsEn[key] ?? key;
    if (args != null) {
      args.forEach((name, replacement) {
        value = value.replaceAll('{$name}', replacement);
      });
    }
    return value;
  }
}

/// Makes the controller available to every widget and rebuilds them when the language changes.
class AppStringsScope extends InheritedNotifier<LocaleController> {
    const AppStringsScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Listens: the calling widget rebuilds when the language changes.
  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStringsScope>();
    assert(scope != null, 'AppStringsScope is missing above this widget');
    return scope!.notifier!;
  }

  /// Does not listen: for code that only needs the controller once.
  static LocaleController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppStringsScope>();
    assert(scope != null, 'AppStringsScope is missing above this widget');
    return scope!.notifier!;
  }
}

extension AppStringsContext on BuildContext {
  /// Usage: context.t('menu.heading')
  String t(String key, [Map<String, String>? args]) =>
      AppStringsScope.of(this).text(key, args);
}