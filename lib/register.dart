import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Pages
import 'user/user_dashboard.dart';
import 'admin/admin_dashboard.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();
  final TextEditingController _adminCodeCtrl = TextEditingController();

  bool _loading = false;
  bool _obscureText = true;

  String _selectedRole = 'user';
  final List<String> _roles = ['user', 'admin'];
  static const String _adminSecret = "bossrex23";

  Future<void> _register() async {
    if (_nameCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passCtrl.text.isEmpty ||
        _confirmCtrl.text.isEmpty) {
      _showError("Please fill in all fields.");
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      _showError("Passwords do not match.");
      return;
    }
    if (_selectedRole == 'admin' &&
        _adminCodeCtrl.text.trim() != _adminSecret) {
      _showError("Invalid admin code.");
      return;
    }

    setState(() => _loading = true);
    try {
      final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'role': _selectedRole,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      if (_selectedRole == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => UserDashboardPage(userRole: _selectedRole)),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Registration failed.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Glow background
          _buildGlowCircle(top: -50, right: -50, color: Colors.blueAccent),
          _buildGlowCircle(bottom: 50, left: -80, color: Colors.indigoAccent),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: GlassContainer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon / Logo
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.blueAccent, size: 45),
                        ),
                        const SizedBox(height: 25),
                        const Text(
                          "CREATE ACCOUNT",
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2.5),
                        ),
                        const Text(
                          "Enter your information to register",
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        const SizedBox(height: 35),

                        // Input Fields
                        _inputField(controller: _nameCtrl, hint: "Full Name", icon: Icons.person_outline),
                        const SizedBox(height: 18),
                        _inputField(controller: _emailCtrl, hint: "Email Address", icon: Icons.email_outlined),
                        const SizedBox(height: 18),
                        _inputField(controller: _passCtrl, hint: "Password", icon: Icons.lock_outline, obscure: _obscureText, isPassword: true),
                        const SizedBox(height: 18),
                        _inputField(controller: _confirmCtrl, hint: "Confirm Password", icon: Icons.lock_clock_outlined, obscure: _obscureText),

                        const SizedBox(height: 15),
                        _buildRoleSelector(),

                        if (_selectedRole == 'admin') ...[
                          const SizedBox(height: 15),
                          _inputField(controller: _adminCodeCtrl, hint: "Admin Code", icon: Icons.security, obscure: true),
                        ],

                        const SizedBox(height: 35),
                        _registerButton(),

                        const SizedBox(height: 25),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pushNamed('/login'),
                          child: RichText(
                            text: const TextSpan(
                              text: "Already have an account? ",
                              style: TextStyle(color: Colors.white54, fontSize: 13),
                              children: [
                                TextSpan(
                                  text: "Login",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
              ),
            ),
          ),

          // Loading overlay
          if (_loading)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _inputField({required TextEditingController controller, required String hint, required IconData icon, bool obscure = false, bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: isPassword
            ? IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 18), onPressed: () => setState(() => _obscureText = !_obscureText))
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
        ),
      ),
    );
  }

  Widget _registerButton() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(colors: [Colors.blueAccent, Colors.blueAccent.withOpacity(0.6)]),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: _loading ? null : _register,
        child: const Text(
          "CREATE ACCOUNT",
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          isExpanded: true,
          dropdownColor: Colors.grey[900],
          icon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
          style: const TextStyle(color: Colors.white),
          items: _roles.map((role) {
            return DropdownMenuItem(value: role, child: Text("Register as ${role.toUpperCase()}"));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedRole = value;
                _adminCodeCtrl.clear();
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildGlowCircle({double? top, double? bottom, double? left, double? right, required Color color}) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 100, spreadRadius: 50)],
        ),
      ),
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  const GlassContainer({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}
