import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> with SingleTickerProviderStateMixin {
  late AnimationController _sosController;
  final TextEditingController _reportController = TextEditingController();

  String? userRole;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _getUserRole();
    _sosController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sosController.dispose();
    _reportController.dispose();
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

  Future<void> _submitSOS() async {
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('emergencies').add({
      'userId': user?.uid,
      'userEmail': user?.email,
      'type': 'CRITICAL SOS',
      'message': 'Manual SOS Triggered',
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'PENDING',
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("SOS Sent! Help is on the way."), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = userRole == 'admin';
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("EMERGENCY HUB",
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16, letterSpacing: 4)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _buildBackgroundGlows(),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildSOSButton(),
                const SizedBox(height: 40),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text("ACTIVE INCIDENTS",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(child: _buildIncidentList(isAdmin)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSButton() {
    return GestureDetector(
      onLongPress: _submitSOS,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _sosController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.redAccent.withOpacity(_sosController.value), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.2 * _sosController.value),
                      blurRadius: 40,
                      spreadRadius: 20 * _sosController.value,
                    )
                  ],
                ),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [Colors.redAccent, Colors.red]),
                  ),
                  child: const Center(
                    child: Text("SOS",
                        style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 15),
          const Text("LONG PRESS TO SEND SOS",
              style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildIncidentList(bool isAdmin) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('emergencies').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
        var docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            bool isResolved = data['status'] == 'RESOLVED';

            return _buildGlassBox(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(15),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.emergency_share_rounded, color: isResolved ? Colors.greenAccent : Colors.redAccent),
                title: Text(data['userEmail'] ?? 'Anonymous',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("${data['type']} • ${data['status']}",
                    style: TextStyle(color: isResolved ? Colors.greenAccent : Colors.redAccent.withOpacity(0.7), fontSize: 11)),
                trailing: isAdmin ? IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.blueAccent),
                  onPressed: () => docs[index].reference.update({'status': 'RESOLVED'}),
                ) : null,
              ),
            );
          },
        );
      },
    );
  }

  // --- REUSABLE UI ---
  Widget _buildGlassBox({required Widget child, EdgeInsets? margin, EdgeInsets? padding}) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return Stack(children: [
      Positioned(top: -50, right: -50, child: _glow(Colors.redAccent.withOpacity(0.15))),
      Positioned(bottom: -100, left: -50, child: _glow(Colors.orangeAccent.withOpacity(0.05))),
    ]);
  }

  Widget _glow(Color color) => Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 150, spreadRadius: 50)]));
}