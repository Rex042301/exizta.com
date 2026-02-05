import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login.dart';

class AdminProfile extends StatelessWidget {
  const AdminProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background para lumitaw ang glass
      body: Stack(
        children: [
          // Gradient Background (Katulad ng AdminHome)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF020617), Colors.black],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return _buildDesktopView(context);
                } else {
                  return _buildMobileView(context);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- MOBILE VIEW ---
  Widget _buildMobileView(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildProfileHeader(context, isDesktop: false),
          const SizedBox(height: 40),
          _buildActionList(context),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  // --- DESKTOP VIEW ---
  Widget _buildDesktopView(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900),
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(flex: 1, child: _buildProfileHeader(context, isDesktop: true)),
            // Divider na glass din
            Container(
              height: 250,
              width: 1,
              color: Colors.white.withOpacity(0.1),
              margin: const EdgeInsets.symmetric(horizontal: 60),
            ),
            Expanded(
              flex: 1,
              child: _buildActionList(context),
            ),
          ],
        ),
      ),
    );
  }

  // --- GLASS COMPONENT (ANG SIKRETO SA LINAW) ---
  Widget _glassTile({required Widget child, Color statusColor = Colors.blueAccent}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        // Sigma 15-20 ay ang pinakamalinaw na glass look sa Flutter
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            // Sobrang nipis na border para magmukhang glass edge
            border: Border.all(
              color: statusColor.withOpacity(0.2),
              width: 1.0,
            ),
            // Translucent black para hindi "washed out" ang text
            color: Colors.white.withOpacity(0.03),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, {required bool isDesktop}) {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _glassTile(
          child: CircleAvatar(
            radius: isDesktop ? 70 : 60,
            backgroundColor: Colors.blueAccent.withOpacity(0.1),
            child: Icon(Icons.person_rounded, size: isDesktop ? 70 : 60, color: Colors.blueAccent),
          ),
        ),
        const SizedBox(height: 25),
        Text("ADMINISTRATOR", style: TextStyle(color: Colors.blueAccent.withOpacity(0.8), fontSize: 10, letterSpacing: 4, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(user?.email ?? "admin@aiper.com", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionList(BuildContext context) {
    return Column(
      children: [

        _actionItem(Icons.info, "Profile Information"),
        _actionItem(Icons.security_rounded, "Security Settings"),
        _actionItem(Icons.notifications_active_rounded, "Notifications"),
        _actionItem(Icons.settings, "Setiings"),
        _actionItem(Icons.logout_rounded, "Sign Out", isDestructive: true, onTap: () async {
          await FirebaseAuth.instance.signOut();
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
        }),
      ],
    );
  }

  Widget _actionItem(IconData icon, String title, {bool isDestructive = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: _glassTile(
          statusColor: isDestructive ? Colors.redAccent : Colors.blueAccent,
          child: Row(
            children: [
              Icon(icon, color: isDestructive ? Colors.redAccent : Colors.blueAccent, size: 20),
              const SizedBox(width: 15),
              Text(title, style: TextStyle(color: isDestructive ? Colors.redAccent : Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.2), size: 12),
            ],
          ),
        ),
      ),
    );
  }
}