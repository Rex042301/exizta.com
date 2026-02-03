import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import mo pa rin ang mga pages para sa navigation
import 'emergency_page.dart';
import 'safety_tips_page.dart';
import 'ews_page.dart';
import 'facilities_page.dart';
import 'evacuation_page.dart';
import 'hazard_page.dart';
import 'hotlines_page.dart';

class AdminServices extends StatefulWidget {
  final VoidCallback onBack;
  const AdminServices({super.key, required this.onBack});

  @override
  State<AdminServices> createState() => _AdminServicesState();
}

class _AdminServicesState extends State<AdminServices> with SingleTickerProviderStateMixin {
  bool _isAdmin = false;
  late AnimationController _shimmerController;

  final List<Map<String, dynamic>> _servicesData = [
    {'label': 'Emergency', 'icon': Icons.emergency, 'color': Colors.blueAccent, 'page': const EmergencyPage()},
    {'label': 'Safety Tips', 'icon': Icons.shield_outlined, 'color': Colors.greenAccent, 'page': const SafetyTipsPage()},
    {'label': 'EWS', 'icon': Icons.notifications_active_outlined, 'color': Colors.orangeAccent, 'page': const EWSPage()},
    {'label': 'Facilities', 'icon': Icons.business_outlined, 'color': Colors.cyanAccent, 'page': const FacilitiesPage()},
    {'label': 'Evacuation', 'icon': Icons.directions_run_outlined, 'color': Colors.yellowAccent, 'page': const EvacuationPage()},
    {'label': 'Hazard', 'icon': Icons.warning_amber_rounded, 'color': Colors.redAccent, 'page': const HazardPage()},
    {'label': 'Hotlines', 'icon': Icons.phone_in_talk_outlined, 'color': Colors.blueAccent, 'page': const HotlinesPage()},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    // 6 seconds para mag-match sa bagong AdminHome speed
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (mounted) {
        setState(() => _isAdmin = doc.exists && doc.get('role') == 'admin');
      }
    } catch (e) {
      debugPrint("Error loading role: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildBackgroundGlows(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _servicesData.length,
                    itemBuilder: (context, index) {
                      final item = _servicesData[index];
                      return _buildServiceCard(
                        label: item['label'],
                        icon: item['icon'],
                        iconColor: item['color'],
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item['page'])),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UPDATED RAZOR-THIN ICE BLUE SWEEP CARD ---
  Widget _buildServiceCard({required String label, required IconData icon, required Color iconColor, required VoidCallback onTap}) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Material(
                  color: Colors.white.withOpacity(0.05),
                  child: InkWell(
                    onTap: onTap,
                    splashColor: Colors.blueAccent.withOpacity(0.2),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          Expanded(flex: 3, child: Icon(icon, size: 28, color: iconColor)),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3
                                ),
                              ),
                            ),
                          ),
                          if (_isAdmin)
                            Container(width: 4, height: 4, decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle)),
                        ],
                      ),
                    ),
                  ),
                ),
                // Razor-Thin Ice Blue Sweep (Manipis at Mabagal)
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        // Range -5.0 to 5.0 para sa mahabang gap/pause
                        begin: Alignment(-5.0 + (_shimmerController.value * 10), -1.2),
                        end: Alignment(-4.0 + (_shimmerController.value * 10), 1.2),
                        colors: [
                          Colors.transparent,
                          Colors.blueAccent.withOpacity(0.05), // Ice Blue Glow
                          Colors.white.withOpacity(0.4),       // Razor Thin White Core
                          Colors.blueAccent.withOpacity(0.05), // Ice Blue Glow
                          Colors.transparent,
                        ],
                        // Needle-thin stops
                        stops: const [0.0, 0.492, 0.5, 0.508, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 15, 20, 15),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20), onPressed: widget.onBack),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Admin Services", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              Text("SYSTEM DIRECTORY", style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return Stack(
      children: [
        Container(color: const Color(0xFF020617)),
        Positioned(top: -50, right: -50, child: _glow(Colors.blueAccent)),
        Positioned(bottom: -50, left: -50, child: _glow(Colors.indigoAccent)),
      ],
    );
  }

  Widget _glow(Color color) => Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 100, spreadRadius: 50)]));
}