import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'services/notifications.dart';
import 'state/app_state.dart';
import 'ui/home_page.dart';
import 'ui/lock.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notif.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const KhaneApp(),
    ),
  );
}

class KhaneApp extends StatelessWidget {
  const KhaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'خرج خانه',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF00897B),
        fontFamily: 'Vazirmatn',
      ),
      builder: (context, child) =>
          LockGate(child: child ?? const SizedBox.shrink()),
      home: const HomePage(),
    );
  }
}
