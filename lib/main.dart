import 'package:flutter/material.dart';

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

  static const List<String> _titles = [
    'URL Phishing Scanner',
    'Email Phishing Scanner',
    'QR Code Scanner',
    'Account Takeover Check',
    'APK Malware Scanner',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🔍 ${_titles[_index]}'),
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