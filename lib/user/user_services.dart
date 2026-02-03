import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Pag-import ng pages (Gagana lang ito kung existing ang files)
// Kung wala pa, i-comment out muna ang lines na ito.
import '../admin/emergency_page.dart';
import '../admin/safety_tips_page.dart';
import '../admin/ews_page.dart';
import '../admin/facilities_page.dart';
import '../admin/evacuation_page.dart';
import '../admin/hazard_page.dart';
import '../admin/hotlines_page.dart';

class UserServices extends StatefulWidget {
  final VoidCallback onBack;
  final bool isReadOnly; // TRUE kung ididisplay lang sa user_service.dart

  const UserServices({
    super.key,
    required this.onBack,
    this.isReadOnly = false, // Default ay false (Admin Mode)
  });

  @override
  State<UserServices> createState() => _UserServicesState();
}

class _UserServicesState extends State<UserServices> with SingleTickerProviderStateMixin {
  bool _isAdmin = false;
  late AnimationController _shimmerController;

  // Configuration ng Services
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
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
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
          _buildCyberBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _servicesData.length,
                    itemBuilder: (context, index) {
                      final item = _servicesData[index];
                      return _buildUnifiedCard(
                        label: item['label'],
                        icon: item['icon'],
                        iconColor: item['color'],
                        // Kapag Read Only, hindi clickable ang cards
                        onTap: widget.isReadOnly
                            ? null
                            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => item['page'])),
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

  Widget _buildUnifiedCard({
    required String label,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isReadOnly
                  ? Colors.white.withOpacity(0.05) // Mas malabo pag Read Only
                  : Colors.white.withOpacity(0.12),
            ),
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
                    child: Opacity(
                      opacity: widget.isReadOnly ? 0.6 : 1.0, // Faded effect pag Read Only
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Center(child: Icon(icon, size: 28, color: iconColor)),
                            ),
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
                                  ),
                                ),
                              ),
                            ),
                            if (_isAdmin && !widget.isReadOnly) // Admin dot only in active mode
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Shimmer Sweep Effect (Optional: keep even in read-only for life)
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-3.0 + (_shimmerController.value * 6), -1.2),
                        end: Alignment(-2.0 + (_shimmerController.value * 6), 1.2),
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(widget.isReadOnly ? 0.1 : 0.3),
                          Colors.transparent,
                        ],
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
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: widget.onBack,
          ),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isReadOnly ? "System Overview" : "Admin Hub",
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              Text(
                widget.isReadOnly ? "VIEW ONLY" : "FULL ACCESS",
                style: TextStyle(
                  color: widget.isReadOnly ? Colors.blueAccent : Colors.greenAccent,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCyberBackground() {
    return Stack(
      children: [
        Container(color: const Color(0xFF020617)),
        _glowCircle(top: -50, right: -50, color: Colors.blueAccent),
        _glowCircle(bottom: -50, left: -50, color: Colors.indigoAccent),
      ],
    );
  }

  Widget _glowCircle({double? top, double? bottom, double? left, double? right, required Color color}) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Container(
        width: 300, height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 100, spreadRadius: 50)],
        ),
      ),
    );
  }
}