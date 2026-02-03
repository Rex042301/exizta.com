import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'login.dart';
import 'register.dart';
import 'theme_provider.dart';
import 'user/user_dashboard.dart';
import 'admin/admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI-RES',
      theme: themeProvider.themeData,
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
      },
    );
  }
}

/* =======================
   AUTH WRAPPER
======================= */
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<Widget> _getHome(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final role = doc.data()?['role'] ?? 'user';
        if (role == 'admin') return const AdminDashboardPage();
        return UserDashboardPage(userRole: role);
      }
    } catch (e) {
      debugPrint("Error fetching role: $e");
    }
    return const UserDashboardPage(userRole: 'user');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
          );
        }

        if (snapshot.hasData) {
          return FutureBuilder<Widget>(
            future: _getHome(snapshot.data!),
            builder: (context, roleSnapshot) {
              if (!roleSnapshot.hasData) {
                return const Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
                );
              }
              return roleSnapshot.data!;
            },
          );
        }
        return const HomePage();
      },
    );
  }
}

/* =======================
   UPGRADED HOME PAGE (LOGIN BG REPLICA)
======================= */
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: Colors.black, // Pure black base para lumitaw ang glow
      body: Stack(
        children: [
          // 1. GAYANG-GAYA NA GLOW EFFECTS
          _buildGlowCircle(top: -50, right: -50, color: Colors.blueAccent),
          _buildGlowCircle(bottom: 50, left: -80, color: Colors.indigoAccent),

          // 2. MAIN CONTENT
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  children: [
                    // Logo Section
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/sirens.gif',
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      "AI-RES",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                      ),
                    ),
                    const Text(
                      "INTELLIGENT RESPONSE SYSTEM",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 60),

                    // GLASS BUTTONS (Login Style)
                    _buildGlassButton(
                      context,
                      label: "LOGIN",
                      icon: Icons.login_rounded,
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                    ),
                    const SizedBox(height: 20),
                    _buildGlassButton(
                      context,
                      label: "CREATE ACCOUNT",
                      icon: Icons.person_add_rounded,
                      onPressed: () => Navigator.pushNamed(context, '/register'),
                    ),

                    const SizedBox(height: 50),

                    // THEME TOGGLE (Subtle version)
                    IconButton(
                      icon: Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: Colors.white24,
                        size: 28,
                      ),
                      onPressed: themeProvider.toggleTheme,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // GLASS BUTTON BUILDER
  Widget _buildGlassButton(BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1.2,
            ),
          ),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white70, size: 20),
            label: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // GLOW CIRCLE BUILDER (Login Page Spec)
  Widget _buildGlowCircle({double? top, double? bottom, double? left, double? right, required Color color}) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 100,
              spreadRadius: 50,
            )
          ],
        ),
      ),
    );
  }
}