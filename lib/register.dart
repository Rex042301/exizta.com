import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _emergencyContactCtrl = TextEditingController();
  final _adminCodeCtrl = TextEditingController();

  bool _loading = false;
  bool _obscureText = true;
  String _selectedRole = 'user';
  String _selectedBloodType = 'Unknown';

  final List<String> _roles = ['user', 'admin'];
  final List<String> _bloodTypes = ['Unknown', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  static const String _adminSecret = "bossrex23";

  // --- REGISTRATION LOGIC ---
  Future<void> _handleRegister() async {
    if (!_validateInputs()) return;

    setState(() => _loading = true);

    try {
      // 1. Create Account sa Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      User? user = userCredential.user;

      if (user != null) {
        // 2. I-send ang Email Verification
        await user.sendEmailVerification();

        // 3. I-save sa Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'phone': '+63${_phoneCtrl.text.trim()}',
          'emergencyContact': _emergencyContactCtrl.text.trim(),
          'bloodType': _selectedBloodType,
          'role': _selectedRole,
          'status': 'pending_verification',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 4. Start Phone Verification
        if (!mounted) return;
        _startPhoneVerification(user.uid);
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? "Registration failed", Colors.redAccent);
      setState(() => _loading = false);
    } catch (e) {
      _showSnackBar("An unexpected error occurred", Colors.redAccent);
      setState(() => _loading = false);
    }
  }

  // --- UPDATED PHONE VERIFICATION (WITH FIX) ---
  void _startPhoneVerification(String uid) async {
    String fullPhone = '+63${_phoneCtrl.text.trim()}';

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution (Minsan nangyayari sa real devices)
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            await currentUser.linkWithCredential(credential);
            await FirebaseFirestore.instance.collection('users').doc(uid).update({'status': 'verified'});
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint("Phone Auth Error Code: ${e.code}");
          _showSnackBar("Verification Failed: ${e.message}", Colors.red);
          setState(() => _loading = false);
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() => _loading = false);
          _showOTPDialog(verificationId, uid);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint("Timeout: $verificationId");
        },
      );
    } catch (e) {
      // Catcher para sa subtype 'bool' error
      debugPrint("Caught exception in verifyPhoneNumber: $e");
      _showSnackBar("System configuration error. Please check Play Integrity settings.", Colors.orange);
      setState(() => _loading = false);
    }
  }

  void _showOTPDialog(String verificationId, String uid) {
    final otpCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Verify Phone (OTP)", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter the 6-digit code sent to your number.",
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              // DITO ANG FIX: Inilipat ang TextStyle configuration sa 'style' parameter
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 8.0, // Dito dapat ang letterSpacing
              ),
              decoration: InputDecoration(
                hintText: "000000",
                hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8.0),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () async {
              if (otpCtrl.text.length < 6) {
                _showSnackBar("Please enter the 6-digit code", Colors.orange);
                return;
              }
              try {
                PhoneAuthCredential credential = PhoneAuthProvider.credential(
                  verificationId: verificationId,
                  smsCode: otpCtrl.text.trim(),
                );

                await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
                await FirebaseFirestore.instance.collection('users').doc(uid).update({'status': 'verified'});

                if (!context.mounted) return;
                Navigator.pop(context); // Close Dialog
                _showSuccessFlow();
              } catch (e) {
                _showSnackBar("Invalid OTP code. Please try again.", Colors.red);
              }
            },
            child: const Text("VERIFY"),
          )
        ],
      ),
    );
  }

  // --- REST OF THE UI REMAINS THE SAME ---

  bool _validateInputs() {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _phoneCtrl.text.length < 10) {
      _showSnackBar("Complete all fields correctly.", Colors.orange);
      return false;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      _showSnackBar("Passwords do not match.", Colors.red);
      return false;
    }
    return true;
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  void _showSuccessFlow() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Registration Successful"),
        content: const Text("Account created! Check your email for the verification link before logging in."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pushReplacementNamed('/login'), child: const Text("GO TO LOGIN"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildGlow(top: -50, right: -50, color: Colors.blueAccent),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: GlassContainer(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  child: Column(
                    children: [
                      const Text("SECURE REGISTER", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      const SizedBox(height: 30),
                      _buildTextField(_nameCtrl, "Full Name", Icons.person),
                      const SizedBox(height: 15),
                      _buildTextField(_emailCtrl, "Email Address", Icons.email),
                      const SizedBox(height: 15),
                      _buildTextField(_phoneCtrl, "Phone Number (9xxxxxxxxx)", Icons.phone_android, prefix: "+63 ", isPhone: true),
                      const SizedBox(height: 15),
                      _buildTextField(_emergencyContactCtrl, "Emergency Contact No.", Icons.contact_phone),
                      const SizedBox(height: 15),
                      _buildDropdown("Blood Type", _selectedBloodType, _bloodTypes, (val) => setState(() => _selectedBloodType = val!)),
                      const SizedBox(height: 15),
                      _buildTextField(_passCtrl, "Password", Icons.lock, isPass: true),
                      const SizedBox(height: 15),
                      _buildTextField(_confirmCtrl, "Confirm Password", Icons.lock_outline, isPass: true),
                      const SizedBox(height: 15),
                      _buildDropdown("Role", _selectedRole, _roles, (val) => setState(() => _selectedRole = val!)),
                      if (_selectedRole == 'admin') ...[
                        const SizedBox(height: 15),
                        _buildTextField(_adminCodeCtrl, "Admin Secret", Icons.security, isPass: true),
                      ],
                      const SizedBox(height: 30),
                      _buildRegisterBtn(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_loading) _buildLoader(),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon, {bool isPass = false, bool isPhone = false, String? prefix}) {
    return TextField(
      controller: ctrl,
      obscureText: isPass ? _obscureText : false,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      inputFormatters: isPhone ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)] : [],
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixText: prefix,
        prefixStyle: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
        prefixIcon: Icon(icon, color: Colors.white38),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        suffixIcon: isPass ? IconButton(icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off, color: Colors.white38), onPressed: () => setState(() => _obscureText = !_obscureText)) : null,
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChange) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: Colors.grey[900],
          style: const TextStyle(color: Colors.white),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
          onChanged: onChange,
        ),
      ),
    );
  }

  Widget _buildRegisterBtn() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: _loading ? null : _handleRegister,
        child: const Text("REGISTER & VERIFY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildGlow({double? top, double? right, required Color color}) {
    return Positioned(top: top, right: right, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 100, spreadRadius: 50)])));
  }

  Widget _buildLoader() {
    return Container(
      color: Colors.black54,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      ),
    );
  }
}

// GlassContainer remain the same...
class GlassContainer extends StatelessWidget {
  final Widget child;
  const GlassContainer({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white10),
            borderRadius: BorderRadius.circular(30),
          ),
          child: child,
        ),
      ),
    );
  }
}