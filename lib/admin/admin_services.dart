import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import Pages
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
  bool _isLoadingRole = true;

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
  }

  Future<void> _loadUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (mounted) {
        setState(() {
          _isAdmin = doc.exists && doc.get('role') == 'admin';
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading role: $e");
      if (mounted) setState(() => _isLoadingRole = false);
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    // FIXED TO 3 PER LAYER
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.95, // Medyo mas mahaba para sa centering
                    ),
                    itemCount: _servicesData.length,
                    itemBuilder: (context, index) {
                      final item = _servicesData[index];
                      return _buildServiceCard(
                        label: item['label'],
                        icon: item['icon'],
                        iconColor: item['color'],
                        onTap: () {
                          if (_isAdmin) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => item['page']));
                          } else {
                            _showAccessDenied();
                          }
                        },
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

  // --- 💎 RESPONSIVE & CENTERED GLASS BOARD (3 PER LAYER) ---
  Widget _buildServiceCard({required String label, required IconData icon, required Color iconColor, required VoidCallback onTap}) {
    return LayoutBuilder(
        builder: (context, constraints) {
          // Auto-scaling logic based on available card width
          double iconSize = constraints.maxWidth * 0.38;
          double fontSize = constraints.maxWidth * 0.10;

          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  // CLEAN SOLID WHITE LINE
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.2,
                  ),
                  color: Colors.white.withOpacity(0.04),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    splashColor: Colors.white.withOpacity(0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center, // PERFECT VERTICAL CENTER
                        crossAxisAlignment: CrossAxisAlignment.center, // PERFECT HORIZONTAL CENTER
                        children: [
                          // ICON
                          Icon(
                            _isAdmin ? icon : Icons.lock_outline,
                            size: iconSize,
                            color: _isAdmin ? iconColor : Colors.white24,
                          ),
                          SizedBox(height: constraints.maxHeight * 0.08),
                          // AUTO-ADJUST TEXT
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _isAdmin ? Colors.white : Colors.white38,
                                fontSize: fontSize,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (_isAdmin) ...[
                            const SizedBox(height: 6),
                            // CENTERED INDICATOR
                            Container(
                              height: 2.5,
                              width: 12,
                              decoration: BoxDecoration(
                                color: iconColor,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(color: iconColor.withOpacity(0.5), blurRadius: 4)
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
    );
  }

  void _showAccessDenied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Access Restricted: Admin privilege required."),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 15, 20, 15),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20), onPressed: widget.onBack),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Admin Services", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              Text(_isAdmin ? "CONTROL PANEL (ADMIN)" : "CONTROL PANEL (VIEW-ONLY)",
                  style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return Stack(children: [
      Container(color: const Color(0xFF020617)),
      Positioned(top: -50, right: -50, child: _glow(Colors.blueAccent)),
      Positioned(bottom: -50, left: -50, child: _glow(Colors.indigoAccent)),
    ]);
  }

  Widget _glow(Color color) => Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 100, spreadRadius: 50)]));
}