import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_handler/share_handler.dart';

import 'share_inbox.dart';
import 'tabs/account_tab.dart';
import 'tabs/apk_tab.dart';
import 'tabs/email1_tab.dart';
import 'tabs/qr_tab.dart';
import 'tabs/url_tab.dart';

void main() => runApp(const CyberLensApp());

class CyberLensApp extends StatelessWidget {
  const CyberLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CyberLens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF22D3EE)),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  StreamSubscription<SharedMedia>? _shareSub;

  static const List<String> _titles = [
    'URL Phishing Scanner',
    'Email Phishing Scanner',
    'QR Code Scanner',
    'Account Takeover Check',
    'APK Malware Scanner',
  ];

  @override
  void initState() {
    super.initState();
    ShareInbox.current.addListener(_onInbox);
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
      // Sharing is optional; the 5 tabs keep working without it
    }
    // Shares that arrive while the app is already open
    _shareSub = handler.sharedMediaStream.listen(_handleShared);
  }

  void _handleShared(SharedMedia media) {
    final text = media.content;
    if (text == null || text.trim().isEmpty) return;
    ShareInbox.send(ShareInbox.routeText(text));
  }

  void _onInbox() {
    final request = ShareInbox.current.value;
    if (request == null) return;
    setState(() => _index = request.kind == ShareKind.url ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('\u{1F50D} ${_titles[_index]}'),
        backgroundColor: const Color(0xFF0F172A),
      ),
      // IndexedStack keeps each tab's state when you switch between tabs
      body: IndexedStack(
        index: _index,
        children: const [
          UrlTab(),
          EmailTab(),
          QrTab(),
          AccountTab(),
          ApkTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.link), label: 'URL'),
          NavigationDestination(icon: Icon(Icons.email_outlined), label: 'Email'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'QR'),
          NavigationDestination(icon: Icon(Icons.manage_accounts_outlined), label: 'Account'),
          NavigationDestination(icon: Icon(Icons.android), label: 'APK'),
        ],
      ),
    );
  }
}
