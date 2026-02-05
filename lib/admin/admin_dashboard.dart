import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';

// Pages - Siguraduhin na tama ang import paths mo
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
  final Map<String, Timer> _vibrationTimers = {};

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

  void _startGlobalSosListener() {
    _sosSubscription = FirebaseFirestore.instance
        .collection('sos_triggers')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) async {
      final activeSOS = snapshot.docs
          .where((doc) => (doc.data() as Map<String, dynamic>)['acknowledged'] == false)
          .toList();

      if (activeSOS.isEmpty) {
        await _stopAllSirens();
      } else {
        if (!_isSirenPlaying) {
          _isSirenPlaying = true;
          await _audioPlayer.setReleaseMode(ReleaseMode.loop);
          await _audioPlayer.play(AssetSource('sounds/sirens.mp3'));
        }
        for (var doc in activeSOS) {
          final docId = doc.id;
          if (!_vibrationTimers.containsKey(docId) && await Vibration.hasVibrator() == true) {
            _vibrationTimers[docId] = Timer.periodic(const Duration(seconds: 1), (_) {
              Vibration.vibrate(duration: 500);
            });
          }
        }
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _stopAllSirens() async {
    _isSirenPlaying = false;
    for (var timer in _vibrationTimers.values) {
      timer.cancel();
    }
    _vibrationTimers.clear();
    await _audioPlayer.stop();
    if (mounted) setState(() {});
  }

  Future<void> _callUser(String phoneNumber) async {
    final Uri callUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true, // Hayaan ang body na mag-extend sa ilalim ng navbar
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
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _screens,
                    ),
                  ),
                ],
              );
            },
          ),
          // FLOATING NAVBAR (Mobile Only Logic built-in)
          Positioned(
            bottom: 25,
            left: 0,
            right: 0,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) return const SizedBox.shrink();
                return _buildGlowingGlassNavbar(constraints.maxWidth);
              },
            ),
          ),
          // SOS OVERLAY
          Positioned(
            bottom: 115,
            left: 20,
            right: 20,
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
          top: -150,
          right: -50,
          child: _buildGlowOrb(Colors.blueAccent.withOpacity(0.12), 400),
        ),
        Positioned(
          bottom: -100,
          left: -100,
          child: _buildGlowOrb(Colors.indigo.withOpacity(0.1), 500),
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
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 50)],
      ),
    );
  }

  Widget _buildGlowingGlassNavbar(double screenWidth) {
    // Nag-aadjust ang lapad depende sa screen para hindi "stretched"
    double navWidth = screenWidth > 500 ? 450 : screenWidth * 0.92;

    return Center(
      child: SizedBox(
        width: navWidth,
        height: 70,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05), // Clear look
                borderRadius: BorderRadius.circular(35),
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.2),
              ),
              child: Row(
                children: [
                  _navItem(Icons.grid_view_rounded, "HOME", 0),
                  _navItem(Icons.map_rounded, "MAP", 1),
                  _navItem(Icons.pending_actions_rounded, "SERVICES", 2),
                  _navItem(Icons.campaign_rounded, "UPDATES", 3),
                  _navItem(Icons.person_rounded, "PROFILE", 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blueAccent.withOpacity(0.15) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.4),
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.3),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      backgroundColor: Colors.white.withOpacity(0.02),
      selectedIndex: _selectedIndex > 4 ? 0 : _selectedIndex,
      onDestinationSelected: _onItemTapped,
      labelType: NavigationRailLabelType.all,
      unselectedIconTheme: const IconThemeData(color: Colors.white38),
      selectedIconTheme: const IconThemeData(color: Colors.blueAccent),
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
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 1.2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: activeUsers.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    leading: const CircleAvatar(
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.warning_rounded, color: Colors.white, size: 20),
                    ),
                    title: Text(data['name'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.call, color: Colors.greenAccent),
                          onPressed: () => _callUser(data['phone'] ?? ''),
                        ),
                        ElevatedButton(
                          onPressed: () => FirebaseFirestore.instance.collection('sos_triggers').doc(doc.id).update({'acknowledged': true}),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                          child: const Text("ACK", style: TextStyle(color: Colors.white, fontSize: 10)),
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