import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'l10n/app_strings.dart';

/// Full-screen "Choose your language" page.
/// firstRun = true: shown once at the very first launch (no back arrow).
/// firstRun = false: opened from the header button.
class LanguagePickerScreen extends StatelessWidget {
  final bool firstRun;

  /// Called after a language was picked (first run: open the menu, later: go back).
  final void Function(BuildContext context) onDone;

  const LanguagePickerScreen({
    super.key,
    required this.firstRun,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final controller = AppStringsScope.of(context);
    // Nothing is chosen yet on the first run, so the title is shown in two scripts
    final title =
        firstRun ? 'Choose your language\nअपनी भाषा चुनें' : context.t('lang.title');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 18, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.mint, AppColors.sky],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!firstRun)
                    IconButton(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.ink),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  const Text('\u{1F310}', style: TextStyle(fontSize: 34)),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.t('lang.subtitle'),
                    style: const TextStyle(fontSize: 14, color: AppColors.ink),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                    16, 20, 16, MediaQuery.of(context).padding.bottom + 12),
                children: [
                  for (final language in kLanguages)
                    _LanguageCard(
                      language: language,
                      selected:
                          controller.hasChosen && controller.code == language.code,
                      onTap: () async {
                        await controller.setLanguage(language.code);
                        if (context.mounted) onDone(context);
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      context.t('lang.beta'),
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? AppColors.mintSoft : AppColors.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: selected ? AppColors.mintDark : AppColors.track,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language.nativeName,
                    style:
                        const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                if (language.beta)
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.skySoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'beta',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.skyDark),
                    ),
                  ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: selected ? AppColors.mintDark : AppColors.faint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}