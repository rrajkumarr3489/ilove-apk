import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'auth/auth_service.dart';
import 'bus/bus_repo.dart';
import 'home_shell.dart';
import 'push_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait only: the app never turns sideways.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await app.init();
  await repo.init();
  runApp(const ILoveApkApp());
}

class ILoveApkApp extends StatelessWidget {
  const ILoveApkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'I Love APK',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: buildTheme(),
      home: const AppGate(),
    );
  }
}

/// The home screen opens straight away - nobody has to register just to look at bus timings.
/// Registration is asked for only when someone wants to add or change something
/// (see requireLogin in auth/auth_guard.dart).
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  @override
  void initState() {
    super.initState();
    // Quietly confirm a saved login (if any) and refresh the bus timetable in the background.
    auth.validate();
    repo.registerDevice();
    repo.loadConfig();
    repo.autoSync();
    PushService.init();   // does nothing until lib/firebase_config.dart is filled
  }

  @override
  Widget build(BuildContext context) => const HomeShell();
}
