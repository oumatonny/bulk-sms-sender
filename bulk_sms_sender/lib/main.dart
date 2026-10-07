import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BulkSmsApp());
}

class BulkSmsApp extends StatelessWidget {
  const BulkSmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..load(),
      child: Consumer<AppState>(
        builder: (context, state, _) {
          final darkModeSetting = state.settings['darkMode'] as String? ?? 'system';
          final themeMode = switch (darkModeSetting) {
            'on' => ThemeMode.dark,
            'off' => ThemeMode.light,
            _ => ThemeMode.system,
          };

          const seedColor = Color(0xFF2E7D32); // green primary accent

          return MaterialApp(
            title: 'Bulk Messenger',
            debugShowCheckedModeBanner: false,
            themeMode: themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: seedColor,
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: Colors.white,
              appBarTheme: const AppBarTheme(
                backgroundColor: seedColor,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: seedColor,
                brightness: Brightness.dark,
              ),
            ),
            home: state.loaded
                ? const HomeScreen()
                : const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  ),
          );
        },
      ),
    );
  }
}
