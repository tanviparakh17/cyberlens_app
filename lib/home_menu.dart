import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'l10n/app_strings.dart';

class _Feature {
  final String emoji;
  final String titleKey;
  final String descKey;
  final Color tint;

  const _Feature(this.emoji, this.titleKey, this.descKey, this.tint);
}

/// Start screen: every checker as a card, one below the other.
class HomeMenu extends StatelessWidget {
  /// Called with the page number of the tapped card (1 = link ... 5 = APK).
  final void Function(int page) onOpen;

  const HomeMenu({super.key, required this.onOpen});

  static const List<_Feature> _features = [
    _Feature('\u{1F517}', 'title.url', 'desc.url', AppColors.mintSoft),
    _Feature('\u{1F48C}', 'title.email', 'desc.email', AppColors.skySoft),
    _Feature('\u{1F4F7}', 'title.qr', 'desc.qr', AppColors.mintSoft),
    _Feature('\u{1F512}', 'title.account', 'desc.account', AppColors.skySoft),
    _Feature('\u{1F916}', 'title.apk', 'desc.apk', AppColors.mintSoft),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
      children: [
        Text(
          context.t('menu.heading'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          context.t('menu.hint'),
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < _features.length; i++)
          _FeatureCard(
            feature: _features[i],
            order: i,
            onTap: () => onOpen(i + 1),
          ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  final int order;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.feature,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Cards fade and slide in one after the other
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + order * 90),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Material(
          color: AppColors.card,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.track, width: 1.5),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: feature.tint,
                      shape: BoxShape.circle,
                    ),
                    child: Text(feature.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t(feature.titleKey),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.t(feature.descKey),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}