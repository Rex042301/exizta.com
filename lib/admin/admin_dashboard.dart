import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

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

class _AdminDashboardPageState extends State<AdminDashboardPage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<QuerySnapshot>? _sosSubscription;
  bool _isSirenPlaying = false;
  final Map<String, Timer> _vibrationTimers = {};

  List<Widget> get _screens => [
    AdminHome(onNavigate: (i) => _onItemTapped(i)),
    const AdminMap(),
    AdminServices(onBack: () => _onItemTapped(0)),
    AdminUpdates(onBack: () => _onItemTapped(0)),
    const AdminProfile(),
    const EvacuationPage(),
  ];

  @override
  void initState() {
    super.initState();
    _startGlobalSosListener();
  }

  @override
  void dispose() {
    _sosSubscription?.cancel();
    _audioPlayer.dispose();
    for (var t in _vibrationTimers.values) { t.cancel(); }
    super.dispose();
  }

  void _startGlobalSosListener() {
    _sosSubscription = FirebaseFirestore.instance.collection('sos_triggers').snapshots().listen((snapshot) async {
      final unacknowledgedSOS = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['status'] != 'resolved' && data['acknowledged'] != true;
      }).toList();

      if (unacknowledgedSOS.isEmpty && _isSirenPlaying) {
        await _audioPlayer.stop();
        _isSirenPlaying = false;
      } else if (unacknowledgedSOS.isNotEmpty && !_isSirenPlaying) {
        try {
          await _audioPlayer.setReleaseMode(ReleaseMode.loop);
          await _audioPlayer.play(AssetSource('sounds/sirens.mp3'));
          _isSirenPlaying = true;
        } catch (e) { debugPrint("Audio Error: $e"); }
      }
      _syncVibrations(unacknowledgedSOS);
      if (mounted) setState(() {});
    });
  }

  void _syncVibrations(List<QueryDocumentSnapshot> activeDocs) {
    final activeIds = activeDocs.map((e) => e.id).toSet();
    for (var id in activeIds) {
      if (!_vibrationTimers.containsKey(id)) {
        _vibrationTimers[id] = Timer.periodic(const Duration(seconds: 1), (_) {
          Vibration.hasVibrator().then((v) { if (v == true) Vibration.vibrate(duration: 500); });
        });
      }
    }
    _vibrationTimers.keys.toList().forEach((id) {
      if (!activeIds.contains(id)) { _vibrationTimers[id]?.cancel(); _vibrationTimers.remove(id); }
    });
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) {
          bool isDesktop = constraints.maxWidth > 900;

          return Scaffold(
            backgroundColor: Colors.black,
            body: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (_selectedIndex != 0) setState(() => _selectedIndex = 0);
              },
              child: Row( // Row para sa Desktop Side Rail
                children: [
                  if (isDesktop) _buildSideRail(), // Side Rail para sa Desktop

                  Expanded(
                    child: Stack(
                      children: [
                        Positioned(top: -100, right: -50, child: _glow(Colors.blueAccent.withOpacity(.05), 300)),

                        IndexedStack(index: _selectedIndex, children: _screens),

                        if (!isDesktop) // Bottom Navbar para sa Mobile lang
                          Positioned(
                            bottom: 20,
                            left: 15,
                            right: 15,
                            child: _buildBottomNavbar(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
    );
  }

  // --- 🖥️ DESKTOP SIDE RAIL ---
  Widget _buildSideRail() {
    return Container(
      width: 100,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.admin_panel_settings, color: Colors.blueAccent, size: 30),
          const SizedBox(height: 50),
          _railIcon(Icons.grid_view_rounded, 0),
          _railIcon(Icons.map_rounded, 1),
          _railIcon(Icons.pending_actions_rounded, 2),
          _railIcon(Icons.campaign_rounded, 3),
          _railIcon(Icons.person_rounded, 4),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Icon(Icons.logout_rounded, color: Colors.white24),
          ),
        ],
      ),
    );
  }

  Widget _railIcon(IconData icon, int index) {
    bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: InkWell(
        onTap: () => _onItemTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blueAccent.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: isSelected ? Colors.blueAccent : Colors.white38, size: 28),
        ),
      ),
    );
  }

  // --- 📱 MOBILE BOTTOM NAVBAR ---
  Widget _buildBottomNavbar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white10)
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navIcon(Icons.grid_view_rounded, 0),
              _navIcon(Icons.map_rounded, 1),
              _navIcon(Icons.pending_actions_rounded, 2),
              _navIcon(Icons.campaign_rounded, 3),
              _navIcon(Icons.person_rounded, 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, int index) {
    bool isSelected = _selectedIndex == index;
    return IconButton(
      icon: Icon(icon, color: isSelected ? Colors.blueAccent : Colors.white38, size: 26),
      onPressed: () => _onItemTapped(index),
    );
  }

  Widget _glow(Color c, double s) => Container(
      width: s, height: s,
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: c, blurRadius: 100, spreadRadius: 50)])
  );
}