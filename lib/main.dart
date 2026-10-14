import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_handler/share_handler.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'home_menu.dart';
import 'l10n/app_strings.dart';
import 'language_picker.dart';
import 'share_inbox.dart';
import 'tabs/account_tab.dart';
import 'tabs/apk_tab.dart';
import 'tabs/email1_tab.dart';
import 'tabs/qr_tab.dart';
import 'tabs/url_tab.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final locale = LocaleController();
  await locale.load(); // reads the saved language before the first frame
  runApp(AppStringsScope(controller: locale, child: const CyberLensApp()));
}

class CyberLensApp extends StatelessWidget {
  const CyberLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    // read(), not of(): the app shell must not rebuild when the language changes
    final locale = AppStringsScope.read(context);
    return MaterialApp(
      title: 'CyberLens',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: locale.hasChosen
          ? const HomeScreen()
          : LanguagePickerScreen(
              firstRun: true,
              onDone: (ctx) => Navigator.of(ctx).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              ),
            ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 0 = menu, 1 = link, 2 = email, 3 = QR, 4 = account, 5 = APK
  int _page = 0;
  StreamSubscription<SharedMedia>? _shareSub;

  // True if the app was opened by (or already received) a share
  bool _gotShare = false;

  // Text keys, looked up in the chosen language (see lib/l10n)
  static const List<String> _titleKeys = [
    'title.menu',
    'title.url',
    'title.email',
    'title.qr',
    'title.account',
    'title.apk',
  ];

  static const List<String> _subtitleKeys = [
    'sub.menu',
    'sub.url',
    'sub.email',
    'sub.qr',
    'sub.account',
    'sub.apk',
  ];

  @override
  void initState() {
    super.initState();
    ShareInbox.current.addListener(_onInbox);
    // Wake the free server early, so the first scan is faster
    unawaited(ApiService.warmUp());
    // Wait for the first frame so the tabs are already listening
    WidgetsBinding.instance.addPostFrameCallback((_) => _initShare());
  }

  @override
  void dispose() {
    ShareInbox.current.removeListener(_onInbox);
    _shareSub?.cancel();
    super.dispose();
  }

  Future<void> _initShare() async {
    final handler = ShareHandlerPlatform.instance;
    try {
      // Share that launched the app (app was closed)
      final initial = await handler.getInitialSharedMedia();
      if (initial != null) {
        _handleShared(initial);
        await handler.resetInitialSharedMedia();
      }
    } catch (_) {
      // Sharing is optional; the checkers keep working without it
    }
    // Shares that arrive while the app is already open
    _shareSub = handler.sharedMediaStream.listen(_handleShared);

    // A share has priority; only offer the copied link on a normal launch
    if (!_gotShare) _checkClipboard();
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final link = ShareInbox.bareLink(data?.text ?? '');
      if (link == null || !mounted || _gotShare) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 12),
          content: Text(
            '${context.t('clip.ask')}\n$link',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          action: SnackBarAction(
            label: context.t('clip.scan'),
            onPressed: () => ShareInbox.send(
              ShareInbox.build(ShareKind.url, link, autoScan: true),
            ),
          ),
        ),
      );
    } catch (_) {
      // Clipboard not available; nothing to offer
    }
  }

  void _handleShared(SharedMedia media) {
    _gotShare = true;

    // Files first (image -> QR tab, .apk -> APK tab)
    for (final attachment in media.attachments ?? const <SharedAttachment?>[]) {
      if (attachment == null) continue;
      final path = attachment.path;
      final name = path.split(RegExp(r'[\\/]')).last;
      if (path.toLowerCase().endsWith('.apk')) {
        ShareInbox.send(ShareRequest(kind: ShareKind.apk, path: path, name: name));
        return;
      }
      if (attachment.type == SharedAttachmentType.image) {
        ShareInbox.send(ShareRequest(
          kind: ShareKind.qr,
          path: path,
          name: name,
          autoScan: true,
        ));
        return;
      }
      _showMessage('share.unsupported');
      return;
    }

    // Then plain text (link -> URL tab, other text -> Email tab)
    final text = media.content;
    if (text == null || text.trim().isEmpty) return;
    ShareInbox.send(ShareInbox.routeText(text));
  }

  /// [key] is a text key from lib/l10n, translated here.
  void _showMessage(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.t(key))));
  }

  int _pageFor(ShareKind kind) {
    switch (kind) {
      case ShareKind.url:
        return 1;
      case ShareKind.email:
        return 2;
      case ShareKind.qr:
        return 3;
      case ShareKind.apk:
        return 5;
    }
  }

  void _onInbox() {
    final request = ShareInbox.current.value;
    if (request == null) return;
    setState(() => _page = _pageFor(request.kind));
  }

  void _goTo(int page) => setState(() => _page = page);

  void _openLanguagePicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LanguagePickerScreen(
          firstRun: false,
          onDone: (ctx) => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onMenu = _page == 0;
    return PopScope(
      // On a tool, the back button returns to the menu instead of closing the app
      canPop: onMenu,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goTo(0);
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: onMenu ? 20 : 0,
          foregroundColor: AppColors.ink,
          backgroundColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.mint, AppColors.sky],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          leading: onMenu
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: context.t('tip.back'),
                  onPressed: () => _goTo(0),
                ),
          actions: [
            IconButton(
              icon: const Icon(Icons.translate_rounded),
              tooltip: context.t('tip.language'),
              onPressed: _openLanguagePicker,
            ),
          ],
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  context.t(_titleKeys[_page]),
                  key: ValueKey<String>('t$_page'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  context.t(_subtitleKeys[_page]),
                  key: ValueKey<String>('s$_page'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        // IndexedStack builds every page once and keeps its state
        // (so results survive going back to the menu, and shares always find a listener)
        body: IndexedStack(
          index: _page,
          children: [
            HomeMenu(onOpen: _goTo),
            const UrlTab(),
            const EmailTab(),
            const QrTab(),
            AccountTab(onOpenChecker: _goTo),
            const ApkTab(),
          ],
        ),
      ),
    );
  }
}