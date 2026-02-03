import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true; // Default sa dark (since current background is black)

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  ThemeData get themeData {
    return ThemeData(
      brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: _isDarkMode ? Colors.black : Colors.white,
      primaryColor: _isDarkMode ? Colors.blueGrey[900] : Colors.blue[100],
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
        bodyMedium: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87),
        titleLarge: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.blue,
        foregroundColor: _isDarkMode ? Colors.white : Colors.black,
      ),
    );
  }

  Color get buttonTextColor => _isDarkMode ? Colors.white : Colors.black;
  Color get buttonBackground => _isDarkMode ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);
}
