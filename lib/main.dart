import 'package:flutter/material.dart';

import 'data_store.dart';
import 'home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.init();
  runApp(const ILoveApkApp());
}

class ILoveApkApp extends StatelessWidget {
  const ILoveApkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'I Love APK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF57C00)),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const HomeScreen(),
    );
  }
}
