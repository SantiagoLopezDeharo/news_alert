import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load();
  runApp(const NewsAlertApp());
}

class NewsAlertApp extends StatelessWidget {
  const NewsAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color neonAccent = Color(0xFF00FFC6); // Softer neon
    const Color darkBg = Colors.black;
    const Color cardBg = Color(0xFF181A20);
    const Color borderColor = Color(0xFF23272F);
    return MaterialApp(
      title: 'News Alert',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBg,
          foregroundColor: neonAccent,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFF00FFC6),
            fontWeight: FontWeight.w700,
            fontSize: 22,
            letterSpacing: 1.1,
          ),
        ),
        cardColor: cardBg,
        cardTheme: CardTheme(
          color: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: borderColor, width: 1.2),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: neonAccent,
            foregroundColor: darkBg,
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(cardBg),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardBg,
          labelStyle: const TextStyle(color: neonAccent),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: neonAccent),
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white, fontSize: 16),
          bodyLarge: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: Color(0xFF00FFC6), fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: neonAccent, size: 22),
        dividerColor: borderColor,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
