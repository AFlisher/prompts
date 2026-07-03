import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const PrombtApp());
}

class PrombtApp extends StatelessWidget {
  const PrombtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prombt — AI Photo Styles',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const MainShell(),
    );
  }
}
