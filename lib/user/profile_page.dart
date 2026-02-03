import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login.dart'; // <--- Siguraduhing tama ang path patungo sa iyong login.dart

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  // --- HELPER: SHOW IMAGE SOURCE DIALOG ---
  void _showImageSourceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Change Profile Picture",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
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
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 30),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 60),

            // --- GLOWING AVATAR SECTION ---
            Center(
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.15),
                          blurRadius: 30,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      child: const Icon(Icons.person_rounded, size: 55, color: Colors.blueAccent),
                    ),
                  ),

                  // FUNCTIONAL CAMERA BUTTON
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _showImageSourceDialog(context),
                      child: Container(
                        height: 35,
                        width: 35,
                        decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)
                            ]
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text(
              user?.email ?? "user@email.com",
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),

            // --- ACTION TILES ---
            _buildGlowingTile(Icons.security, "Security Settings", onTap: () {}),
            const SizedBox(height: 15),
            _buildGlowingTile(Icons.notifications_none, "Notification Preferences", onTap: () {}),
            const SizedBox(height: 15),
            _buildGlowingTile(Icons.history, "SOS History", onTap: () {}),
            const SizedBox(height: 15),
            _buildGlowingTile(Icons.help_outline, "Help & Support", onTap: () {}),
            const SizedBox(height: 15),

            // FUNCTIONAL LOGOUT BUTTON
            _buildGlowingTile(
              Icons.logout,
              "Logout",
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

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  // --- REUSABLE GLOWING TILE WIDGET ---
  Widget _buildGlowingTile(IconData icon, String label, {bool isDestructive = false, VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 1,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: InkWell( // Ginamit ang InkWell para sa click feedback
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(icon, color: isDestructive ? Colors.redAccent : Colors.blueAccent),
                  const SizedBox(width: 15),
                  Text(
                    label,
                    style: TextStyle(
                        color: isDestructive ? Colors.redAccent : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}