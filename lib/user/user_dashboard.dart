import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';

// Pages - Siguraduhing tama ang import paths mo
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
  Timer? _sosHoldTimer;
  final List<Map<String, String>> _chatMessages = [];
  OverlayEntry? _incomingCallOverlay;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const UserHome(),
      UserServices(onBack: () => _onItemTapped(0)),
      _buildAiChatWithSos(), // Updated to include SOS List
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
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
      ).listen((Position pos) => _updateUserLocationInFirestore(pos));
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

  // ---------------- SOS ACTION (FIREBASE FIRST) ----------------
  Future<void> _triggerSosAction() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Get Current Location
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      // 2. Fetch User Info for Admin Report
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      // 3. Add to Firestore and Wait (Prevents Ghost Triggers)
      await FirebaseFirestore.instance.collection('sos_triggers').add({
        'userId': user.uid,
        'email': user.email,
        'userName': userData?['name'] ?? 'Unknown User',
        'phone': userData?['phone'] ?? 'No Phone Provided',
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active', // Mark as active for admin
      });

      if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(duration: 500);

      _aiReply("SOS signal received. Responders have your profile and location.");
      setState(() => _selectedIndex = 2);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("SOS Sync Failed: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _cancelSosAction(String docId) async {
    await FirebaseFirestore.instance.collection('sos_triggers').doc(docId).update({
      'status': 'cancelled',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------- UI COMPONENTS ----------------
  Widget _buildAiChatWithSos() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 40, bottom: 10),
          child: Text("ACTIVE SOS TRIGGERS", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
        SizedBox(height: 200, child: _buildSosList()), // List of active SOS
        const Divider(color: Colors.white10),
        Expanded(child: _buildAiChatPage()), // Chat below
      ],
    );
  }

  Widget _buildSosList() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sos_triggers')
          .where('status', isEqualTo: 'active') // Filter only active
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text("No active emergencies", style: TextStyle(color: Colors.white24)));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            final isOwnSos = currentUser?.uid == data['userId'];

            return _glassContainer(
              statusColor: Colors.redAccent,
              isBlinking: isOwnSos,
              child: ExpansionTile(
                iconColor: Colors.white,
                collapsedIconColor: Colors.white54,
                title: Text(data['userName'] ?? "User", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: Text("Contact: ${data['phone']}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Text("Location: ${data['latitude']}, ${data['longitude']}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton.icon(
                              onPressed: () => _openMap(data['latitude'], data['longitude']),
                              icon: const Icon(Icons.map, color: Colors.blueAccent),
                              label: const Text("View Map", style: TextStyle(color: Colors.blueAccent)),
                            ),
                            if (isOwnSos)
                              TextButton.icon(
                                onPressed: () => _cancelSosAction(docId),
                                icon: const Icon(Icons.cancel, color: Colors.redAccent),
                                label: const Text("Cancel SOS", style: TextStyle(color: Colors.redAccent)),
                              ),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openMap(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  // (Previous UI logic for AI Chat, Navbar, and Calls remain the same...)
  // ---------------- AI CHAT ----------------
  void _aiReply(String message) {
    setState(() => _chatMessages.add({'sender': 'ai', 'message': message}));
  }

  void _sendMessage(String msg) {
    if (msg.trim().isEmpty) return;
    setState(() {
      _chatMessages.add({'sender': 'user', 'message': msg.trim()});
      _aiReply('Message received, emergency units are monitoring this chat.');
    });
  }

  Widget _buildAiChatPage() {
    final TextEditingController controller = TextEditingController();
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _chatMessages.length,
            itemBuilder: (context, index) {
              final msg = _chatMessages[index];
              final isUser = msg['sender'] == 'user';
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: isUser ? Colors.blueAccent : Colors.grey[800], borderRadius: BorderRadius.circular(12)),
                  child: Text(msg['message']!, style: const TextStyle(color: Colors.white)),
                ),
              );
            },
          ),
        ),
        Container(
          color: Colors.grey[900],
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(child: TextField(controller: controller, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Type to AI...", hintStyle: TextStyle(color: Colors.white30), border: InputBorder.none))),
              IconButton(icon: const Icon(Icons.send, color: Colors.blueAccent), onPressed: () { _sendMessage(controller.text); controller.clear(); }),
            ],
          ),
        ),
        const SizedBox(height: 100), // Space for Navbar
      ],
    );
  }

  // ---------------- MISC UI ----------------
  Widget _glassContainer({required Widget child, required Color statusColor, bool isBlinking = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isBlinking ? Colors.redAccent : Colors.white10),
      ),
      child: child,
    );
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  Widget _buildGlowingNavbar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(35),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(35), border: Border.all(color: Colors.white24)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navBtn(Icons.home_filled, 0),
              _navBtn(Icons.construction, 1),
              _sosBtn(),
              _navBtn(Icons.notifications, 3),
              _navBtn(Icons.person, 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, int index) => IconButton(icon: Icon(icon, color: _selectedIndex == index ? Colors.blueAccent : Colors.white54), onPressed: () => _onItemTapped(index));

  Widget _sosBtn() {
    return GestureDetector(
      onLongPressStart: (_) => _sosHoldTimer = Timer(const Duration(seconds: 2), _triggerSosAction),
      onLongPressEnd: (_) => _sosHoldTimer?.cancel(),
      child: CircleAvatar(backgroundColor: Colors.redAccent, radius: 28, child: const Icon(Icons.sos, color: Colors.white, size: 30)),
    );
  }

  // ---------------- INCOMING CALL LOGIC ----------------
  void _listenIncomingCalls() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseFirestore.instance.collection('calls').where('calleeId', isEqualTo: user.uid).where('status', isEqualTo: 'ringing').snapshots().listen((snap) {
      if (snap.docs.isNotEmpty) _showIncomingCallPopup(snap.docs.first['callerName'], snap.docs.first.id);
      else { _incomingCallOverlay?.remove(); _incomingCallOverlay = null; }
    });
  }

  void _showIncomingCallPopup(String name, String id) {
    _incomingCallOverlay?.remove();
    _incomingCallOverlay = OverlayEntry(builder: (context) => Positioned(top: 100, left: 20, right: 20, child: Material(color: Colors.transparent, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)), child: Column(children: [Text("$name is calling...", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ElevatedButton(onPressed: () => FirebaseFirestore.instance.collection('calls').doc(id).update({'status': 'answered'}), child: const Text("Answer")), ElevatedButton(onPressed: () => FirebaseFirestore.instance.collection('calls').doc(id).update({'status': 'declined'}), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Decline"))])])))));
    Overlay.of(context).insert(_incomingCallOverlay!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: _screens),
          Positioned(bottom: 20, left: 20, right: 20, child: _buildGlowingNavbar()),
        ],
      ),
    );
  }
}