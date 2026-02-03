import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';

// Pages
import 'mapp_page.dart';
import 'admin_home.dart';
import 'admin_services.dart';
import 'admin_updates.dart';
import 'admin_profile.dart';
import 'evacuation_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _shimmerController;
  bool _isSirenPlaying = false;
  StreamSubscription<QuerySnapshot>? _sosSubscription;
  final Map<String, Timer> _vibrationTimers = {}; // per-user vibration timers

  // Screens
  List<Widget> get _screens => [
    AdminHome(onNavigate: (index) => _onItemTapped(index)),
    const AdminMap(),
    AdminServices(onBack: () => _onItemTapped(0)),
    AdminUpdates(onBack: () => _onItemTapped(0)),
    const AdminProfile(),
    const EvacuationPage(),
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _startGlobalSosListener();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _sosSubscription?.cancel();
    _stopAllSirens();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ---------------- SOS LISTENER ----------------
  void _startGlobalSosListener() {
    _sosSubscription = FirebaseFirestore.instance
        .collection('sos_triggers')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) async {
      final activeSOS = snapshot.docs
          .where((doc) =>
      (doc.data() as Map<String, dynamic>)['acknowledged'] == false)
          .toList();

      if (activeSOS.isEmpty) {
        await _stopAllSirens();
      } else {
        if (!_isSirenPlaying) {
          _isSirenPlaying = true;
          await _audioPlayer.setReleaseMode(ReleaseMode.loop);
          await _audioPlayer.play(AssetSource('sounds/sirens.mp3'));
        }

        // Start vibration per active user
        for (var doc in activeSOS) {
          final docId = doc.id;
          if (!_vibrationTimers.containsKey(docId) &&
              await Vibration.hasVibrator() == true) {
            _vibrationTimers[docId] =
                Timer.periodic(const Duration(seconds: 1), (_) {
                  Vibration.vibrate(duration: 500);
                });
          }
        }

        // Cancel vibration for acknowledged users
        final ackedDocs = snapshot.docs
            .where((doc) =>
        (doc.data() as Map<String, dynamic>)['acknowledged'] == true)
            .toList();
        for (var doc in ackedDocs) {
          final docId = doc.id;
          _vibrationTimers[docId]?.cancel();
          _vibrationTimers.remove(docId);
        }
      }

      if (mounted) setState(() {}); // Refresh UI
    });
  }

  Future<void> _stopAllSirens() async {
    _isSirenPlaying = false;
    _vibrationTimers.values.forEach((timer) => timer.cancel());
    _vibrationTimers.clear();
    await _audioPlayer.stop();
    if (mounted) setState(() {});
  }

  // ---------------- CALL FUNCTION ----------------
  Future<void> _callUser(String phoneNumber) async {
    final Uri callUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot make a call on this device')),
      );
    }
  }

  // ---------------- UI ----------------
  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildDynamicBackground(),
          LayoutBuilder(
            builder: (context, constraints) {
              bool isDesktop = constraints.maxWidth > 800;
              return Row(
                children: [
                  if (isDesktop) _buildNavigationRail(),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isDesktop ? 0 : 80),
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: _screens,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            bottom: 20,
            left: 15,
            right: 15,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) return const SizedBox.shrink();
                return _buildGlowingGlassNavbar();
              },
            ),
          ),
          Positioned(
            bottom: 90,
            left: 15,
            right: 15,
            child: _buildCompactSosOverlay(),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicBackground() {
    return Stack(
      children: [
        Container(color: Colors.black),
        Positioned(
          top: -100,
          right: -50,
          child: _buildGlowOrb(Colors.blueAccent.withOpacity(0.1), 300),
        ),
        Positioned(
          bottom: 100,
          left: -100,
          child: _buildGlowOrb(Colors.indigo.withOpacity(0.08), 400),
        ),
      ],
    );
  }

  Widget _buildGlowOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 50)]),
    );
  }

  Widget _buildGlowingGlassNavbar() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              height: 75,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navItem(Icons.grid_view_rounded, "HOME", 0),
                  _navItem(Icons.map_rounded, "MAP", 1),
                  _navItem(Icons.pending_actions_rounded, "PENDING", 2),
                  _navItem(Icons.campaign_rounded, "UPDATE", 3),
                  _navItem(Icons.person_rounded, "USER", 4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? Colors.blueAccent : Colors.white38, size: 26),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blueAccent : Colors.white24,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      backgroundColor: Colors.white.withOpacity(0.02),
      selectedIndex: _selectedIndex > 4 ? 0 : _selectedIndex,
      onDestinationSelected: _onItemTapped,
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.grid_view_rounded), label: Text("Home")),
        NavigationRailDestination(icon: Icon(Icons.map_rounded), label: Text("Map")),
        NavigationRailDestination(icon: Icon(Icons.pending_actions_rounded), label: Text("Services")),
        NavigationRailDestination(icon: Icon(Icons.campaign_rounded), label: Text("Updates")),
        NavigationRailDestination(icon: Icon(Icons.person_rounded), label: Text("Profile")),
      ],
    );
  }

  Widget _buildCompactSosOverlay() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sos_triggers')
          .where('acknowledged', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        final activeUsers = snapshot.data!.docs;

        return ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: activeUsers.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Unknown';
                  final phone = data['phone'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_rounded, color: Colors.redAccent, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.call, color: Colors.greenAccent, size: 22),
                          onPressed: phone.isNotEmpty ? () => _callUser(phone) : null,
                        ),
                        TextButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('sos_triggers')
                                .doc(doc.id)
                                .update({'acknowledged': true});
                            _vibrationTimers[doc.id]?.cancel();
                            _vibrationTimers.remove(doc.id);

                            if (_vibrationTimers.isEmpty) await _stopAllSirens();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            "ACK",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
