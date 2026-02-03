import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';

// Pages
import 'user_home.dart';
import 'user_services.dart';
import 'updates.dart';
import 'profile_page.dart';

class UserDashboardPage extends StatefulWidget {
  final String userRole;
  const UserDashboardPage({super.key, required this.userRole});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  int _selectedIndex = 0;
  StreamSubscription<Position>? _positionStream;
  Timer? _sosHoldTimer; // SOS long press timer
  final List<Map<String, String>> _chatMessages = [];
  OverlayEntry? _incomingCallOverlay;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const UserHome(),
      UserServices(onBack: () => _onItemTapped(0)),
      _buildAiChatPage(),
      const UserUpdates(),
      const ProfilePage(),
    ];
    _startLocationUpdates();
    _listenIncomingCalls();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _sosHoldTimer?.cancel();
    _incomingCallOverlay?.remove();
    super.dispose();
  }

  // ---------------- LOCATION TRACKING ----------------
  Future<void> _startLocationUpdates() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position pos) {
        _updateUserLocationInFirestore(pos);
      });
    }
  }

  Future<void> _updateUserLocationInFirestore(Position pos) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // ---------------- SOS ----------------
  Future<void> _triggerSosAction() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      await FirebaseFirestore.instance.collection('sos_triggers').add({
        'userId': user.uid,
        'email': user.email,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 500);
      }

      _aiReply(
          "Hi! Emergency responders are on their way to your location.");
      setState(() => _selectedIndex = 2); // Switch to AI chat page
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("SOS Error: ${e.toString()}")));
      }
    }
  }

  // ---------------- AI CHAT ----------------
  void _aiReply(String message) {
    setState(() {
      _chatMessages.add({'sender': 'ai', 'message': message});
    });
  }

  void _sendMessage(String msg) {
    if (msg.trim().isEmpty) return;
    setState(() {
      _chatMessages.add({'sender': 'user', 'message': msg.trim()});
      _chatMessages.add({'sender': 'ai', 'message': 'AI: Message received, stay calm!'});
    });
  }

  Widget _buildAiChatPage() {
    final TextEditingController controller = TextEditingController();
    return Column(
      children: [
        Expanded(
          child: _chatMessages.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.chat, size: 50, color: Colors.white30),
                SizedBox(height: 10),
                Text("SOS AI Chat will appear here",
                    style: TextStyle(color: Colors.white54))
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) {
              final msg = _chatMessages[index];
              final isUser = msg['sender'] == 'user';
              return Align(
                alignment:
                isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blueAccent : Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(msg['message']!,
                      style: const TextStyle(color: Colors.white)),
                ),
              );
            },
          ),
        ),
        if (_chatMessages.isNotEmpty)
          Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: () {
                    _sendMessage(controller.text);
                    controller.clear();
                  },
                )
              ],
            ),
          ),
      ],
    );
  }

  // ---------------- INCOMING CALL ----------------
  void _listenIncomingCalls() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('calls')
        .where('calleeId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final callDoc = snapshot.docs.first;
        final callData = callDoc.data() as Map<String, dynamic>;
        _showIncomingCallPopup(
          callData['callerName'] ?? 'Admin',
          callDoc.id,
        );
      } else {
        _incomingCallOverlay?.remove();
        _incomingCallOverlay = null;
      }
    });
  }

  void _showIncomingCallPopup(String callerName, String callDocId) {
    _incomingCallOverlay?.remove();

    _incomingCallOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: 150,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white70),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.call, color: Colors.white, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "$callerName is calling...",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('calls')
                            .doc(callDocId)
                            .update({'status': 'answered'});

                        _incomingCallOverlay?.remove();
                        _incomingCallOverlay = null;

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Call answered!")),
                          );
                        }
                      },
                      icon: const Icon(Icons.call, color: Colors.white),
                      label: const Text("Answer"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('calls')
                            .doc(callDocId)
                            .update({'status': 'declined'});

                        _incomingCallOverlay?.remove();
                        _incomingCallOverlay = null;

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Call declined.")),
                          );
                        }
                      },
                      icon: const Icon(Icons.call_end, color: Colors.white),
                      label: const Text("Decline"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context)?.insert(_incomingCallOverlay!);
  }

  // ---------------- UI ----------------
  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  Widget _buildGlowingNavbar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
              color: Colors.white.withOpacity(0.06), blurRadius: 20, spreadRadius: 2)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 75,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.grid_view_rounded, 0),
                _navItem(Icons.handyman_rounded, 1),
                _sosButton(),
                _navItem(Icons.notifications_active_rounded, 3),
                _navItem(Icons.person_3_rounded, 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Icon(icon,
          color: isSelected ? Colors.blueAccent : Colors.white30,
          size: isSelected ? 30 : 26),
    );
  }

  Widget _sosButton() {
    return GestureDetector(
      onLongPressStart: (_) {
        _sosHoldTimer = Timer(const Duration(seconds: 3), _triggerSosAction);
      },
      onLongPressEnd: (_) {
        _sosHoldTimer?.cancel();
      },
      child: Container(
        height: 55,
        width: 55,
        decoration: BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.redAccent.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2)
          ],
        ),
        child: const Icon(Icons.sos_rounded, color: Colors.white, size: 28),
      ),
    );
  }

  // ---------------- SOS LIST WIDGET ----------------
  Widget buildSosList() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sos_triggers')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text("No active SOS triggers", style: TextStyle(color: Colors.white54)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final isOwnSos = currentUser != null && data['userId'] == currentUser.uid;

            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 400 + index * 100),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: value,
                      child: AnimatedScale(
                        scale: isOwnSos ? 1.05 : 1.0,
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeInOut,
                        child: _glassContainer(
                          statusColor: isOwnSos ? Colors.redAccent : Colors.redAccent.withOpacity(0.7),
                          isBlinking: isOwnSos,
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.emergency,
                                color: isOwnSos ? Colors.redAccent : Colors.redAccent.withOpacity(0.7),
                                size: 20),
                            title: Text(
                              data['userId']?.toString().split('@')[0].toUpperCase() ?? "USER",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: isOwnSos ? FontWeight.bold : FontWeight.normal),
                            ),
                            subtitle: Text(
                              data['address'] ?? "Locating...",
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                              maxLines: 1,
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 10),
                            onTap: () => _onItemTapped(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _glassContainer({
    required Widget child,
    required Color statusColor,
    bool isBlinking = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(isBlinking ? 0.8 : 0.3), width: 1.2),
        color: Colors.white.withOpacity(0.05),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              _screens[0],
              _screens[1],
              Column(
                children: [
                  Expanded(child: _screens[2]),
                  SizedBox(height: 200, child: buildSosList()), // Display all SOS triggers
                ],
              ),
              _screens[3],
              _screens[4],
            ],
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: _buildGlowingNavbar(),
          ),
        ],
      ),
    );
  }
}
