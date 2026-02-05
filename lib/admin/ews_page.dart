import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EWSPage extends StatefulWidget {
  const EWSPage({super.key});

  @override
  State<EWSPage> createState() => _EWSPageState();
}

class _EWSPageState extends State<EWSPage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  String? userRole;
  bool isLoading = true;

  // Controllers para sa Admin Update
  final TextEditingController _waterLevelController = TextEditingController();
  final TextEditingController _rainfallController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getUserRole();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          userRole = doc.data()?['role'];
          isLoading = false;
        });
      }
    }
  }

  // Admin function para i-update ang sensor readings
  Future<void> _updateEWS() async {
    await FirebaseFirestore.instance.collection('ews_data').doc('current_status').set({
      'water_level': _waterLevelController.text,
      'rainfall': _rainfallController.text,
      'status': _statusController.text,
      'last_updated': FieldValue.serverTimestamp(),
    });
    Navigator.pop(context); // Close dialog
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = userRole == 'admin';
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("EARLY WARNING SYSTEM",
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14, letterSpacing: 3)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.settings_input_component, color: Colors.blueAccent),
              onPressed: () => _showUpdateDialog(),
            )
        ],
      ),
      body: Stack(
        children: [
          _buildBackgroundGlows(),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('ews_data').doc('current_status').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                String status = data['status'] ?? "Normal";

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildMainStatusCard(status),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          Expanded(child: _buildSensorCard("WATER LEVEL", "${data['water_level'] ?? '0'}m", Icons.waves, Colors.blueAccent)),
                          const SizedBox(width: 15),
                          Expanded(child: _buildSensorCard("RAINFALL", "${data['rainfall'] ?? '0'}mm", Icons.umbrella, Colors.indigoAccent)),
                        ],
                      ),
                      const SizedBox(height: 25),
                      _buildTimelineSection(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStatusCard(String status) {
    bool isAlert = status.toLowerCase() != "normal";
    return _buildGlassBox(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.1).animate(_pulseController),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isAlert ? Colors.redAccent : Colors.blueAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: (isAlert ? Colors.redAccent : Colors.blueAccent).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Icon(
                isAlert ? Icons.warning_rounded : Icons.check_circle_outline,
                size: 60,
                color: isAlert ? Colors.redAccent : Colors.blueAccent,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(status.toUpperCase(),
              style: TextStyle(
                  color: isAlert ? Colors.redAccent : Colors.blueAccent,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4)),
          const Text("SYSTEM STATUS", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSensorCard(String label, String value, IconData icon, Color color) {
    return _buildGlassBox(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 15),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    return _buildGlassBox(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: Colors.white54, size: 16),
              SizedBox(width: 8),
              Text("RECENT ACTIVITY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          _buildTimelineItem("Level 1 Warning issued in Pasig River", "2h ago"),
          _buildTimelineItem("Heavy Rainfall detected in Marikina", "5h ago"),
          _buildTimelineItem("System routine check completed", "12h ago"),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String text, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle)),
          const SizedBox(width: 15),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Text(time, style: const TextStyle(color: Colors.white24, fontSize: 10)),
        ],
      ),
    );
  }

  // Admin Dialog for Updates
  void _showUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text("UPDATE SENSORS", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSimpleTextField(_waterLevelController, "Water Level (m)"),
              const SizedBox(height: 10),
              _buildSimpleTextField(_rainfallController, "Rainfall (mm)"),
              const SizedBox(height: 10),
              _buildSimpleTextField(_statusController, "Overall Status"),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
            ElevatedButton(onPressed: _updateEWS, child: const Text("UPDATE")),
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildGlassBox({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSimpleTextField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.black.withOpacity(0.24),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return Stack(children: [
      Positioned(top: 100, left: -50, child: _glow(Colors.blueAccent.withOpacity(0.1))),
      Positioned(bottom: 200, right: -100, child: _glow(Colors.indigoAccent.withOpacity(0.1))),
    ]);
  }

  Widget _glow(Color color) => Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 150, spreadRadius: 50)]));
}