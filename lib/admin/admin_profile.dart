import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login.dart';

class AdminProfile extends StatelessWidget {
  const AdminProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Mahalaga para sa Dashboard BG
      body: SafeArea(
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
        // Nilimitahan ang width para dikit ang profile at settings
        constraints: const BoxConstraints(maxWidth: 900),
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Side: Avatar and Info
            Expanded(
              flex: 1,
              child: _buildProfileHeader(context, isDesktop: true),
            ),

            // Subtle Vertical Divider
            Container(
              height: 250,
              width: 1,
              color: Colors.white.withOpacity(0.1),
              margin: const EdgeInsets.symmetric(horizontal: 60),
            ),

            // Right Side: Settings List
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: _buildActionList(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- REUSABLE COMPONENTS ---

  Widget _buildProfileHeader(BuildContext context, {required bool isDesktop}) {
    final user = FirebaseAuth.instance.currentUser;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // GLOWING AVATAR STACK
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: CircleAvatar(
                radius: isDesktop ? 70 : 60, // Mas malaki konti sa desktop
                backgroundColor: Colors.white.withOpacity(0.05),
                child: Icon(Icons.person_rounded, size: isDesktop ? 70 : 60, color: Colors.blueAccent),
              ),
            ),
            Positioned(
              bottom: 5,
              right: 5,
              child: GestureDetector(
                onTap: () => _showImageSourceDialog(context),
                child: Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 3),
                      boxShadow: [
                        BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 10)
                      ]
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        Text(
          "ADMINISTRATOR",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.blueAccent.withOpacity(0.9),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user?.email ?? "admin@aiper.com",
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white,
              fontSize: isDesktop ? 24 : 20,
              fontWeight: FontWeight.w800
          ),
        ),
      ],
    );
  }

  Widget _buildActionList(BuildContext context) {
    return Column(
      children: [
        _buildGlassTile(Icons.security_rounded, "Security Settings"),
        const SizedBox(height: 12),
        _buildGlassTile(Icons.notifications_active_rounded, "Notification Preferences"),
        const SizedBox(height: 12),
        _buildGlassTile(Icons.history_toggle_off_rounded, "Emergency Logs"),
        const SizedBox(height: 12),
        _buildGlassTile(Icons.info_outline_rounded, "App Version"),
        const SizedBox(height: 12),
        _buildGlassTile(
          Icons.logout_rounded,
          "Sign Out",
          isDestructive: true,
          onTap: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildGlassTile(IconData icon, String title, {bool isDestructive = false, VoidCallback? onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: InkWell(
          onTap: onTap ?? () {},
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              color: isDestructive ? Colors.redAccent.withOpacity(0.05) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: isDestructive ? Colors.redAccent.withOpacity(0.2) : Colors.white.withOpacity(0.12),
                  width: 1.2
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: isDestructive ? Colors.redAccent.withOpacity(0.1) : Colors.blueAccent.withOpacity(0.1),
                      shape: BoxShape.circle
                  ),
                  child: Icon(icon, color: isDestructive ? Colors.redAccent : Colors.blueAccent, size: 20),
                ),
                const SizedBox(width: 18),
                Text(
                    title,
                    style: TextStyle(
                        color: isDestructive ? Colors.redAccent : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700
                    )
                ),
                const Spacer(),
                Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.2),
                    size: 12
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showImageSourceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Text("Change Profile Picture", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceOption(context, Icons.photo_library_rounded, "Gallery"),
                  _buildSourceOption(context, Icons.camera_enhance_rounded, "Camera"),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption(BuildContext context, IconData icon, String label) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 30),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}