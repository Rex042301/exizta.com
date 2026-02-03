import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUpdates extends StatefulWidget {
  final VoidCallback onBack;
  const AdminUpdates({super.key, required this.onBack});

  @override
  State<AdminUpdates> createState() => _AdminUpdatesState();
}

class _AdminUpdatesState extends State<AdminUpdates> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  Future<void> _postUpdate() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      _showSnackBar("Please fill in all fields");
      return;
    }
    setState(() => _isSending = true);
    try {
      await FirebaseFirestore.instance.collection('broadcasts').add({
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'Alert',
      });
      _titleController.clear();
      _messageController.clear();
      Navigator.pop(context); // Close the sheet after sending
      _showSnackBar("Broadcast sent successfully!");
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.blueAccent.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // FLOAT BUTTON TO ADD NEW ANNOUNCEMENT
      floatingActionButton: _buildAddButton(),
      body: Stack(
        children: [
          // BACKGROUND CONSISTENCY
          _buildMainBackground(),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                  child: Row(
                    children: [
                      _buildCrystalBackButton(),
                      const SizedBox(width: 15),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Broadcasts",
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
                          ),
                          Text("MANAGE ANNOUNCEMENTS", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ],
                      ),
                    ],
                  ),
                ),

                // ANNOUNCEMENT LIST (Priority Area)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "RECENT UPDATES",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 2),
                        ),
                        const SizedBox(height: 15),
                        _buildRecentUpdatesList(),
                        const SizedBox(height: 100), // Space for FAB
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI BUILDERS ---

  Widget _buildMainBackground() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Color(0xFF001A33), Colors.black],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
        ),
        _buildGlowCircle(top: -50, right: -50, color: Colors.blueAccent),
        _buildGlowCircle(bottom: 50, left: -80, color: Colors.indigoAccent),
      ],
    );
  }

  Widget _buildGlowCircle({double? top, double? bottom, double? left, double? right, required Color color}) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Container(
        width: 300, height: 300,
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
          BoxShadow(color: color.withOpacity(0.12), blurRadius: 100, spreadRadius: 50)
        ]),
      ),
    );
  }

  Widget _buildAddButton() {
    return FloatingActionButton.extended(
      onPressed: () => _showAddAnnouncementPanel(),
      backgroundColor: Colors.transparent,
      elevation: 0,
      label: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 15)],
            ),
            child: const Row(
              children: [
                Icon(Icons.add_comment_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text("NEW BROADCAST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddAnnouncementPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGlassSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Create Broadcast", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            _customTextField(_titleController, "Title", 1),
            const SizedBox(height: 15),
            _customTextField(_messageController, "Write message...", 5),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _isSending ? null : _postUpdate,
                child: const Text("RELEASE ANNOUNCEMENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassSheet({required Widget child}) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 30, left: 25, right: 25, top: 25),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white10),
        ),
        child: child,
      ),
    );
  }

  Widget _buildRecentUpdatesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('broadcasts').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(0.03),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: ListTile(
                onTap: () => _showEditPanel(context, docs[index].id, data),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.campaign_rounded, color: Colors.blueAccent, size: 22),
                ),
                title: Text(data['title'] ?? "", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(data['message'] ?? "", style: const TextStyle(color: Colors.white38, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.edit_note_rounded, color: Colors.white24),
              ),
            );
          },
        );
      },
    );
  }

  // --- REUSED COMPONENTS ---

  Widget _buildCrystalBackButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: widget.onBack,
          child: Container(
            height: 45, width: 45,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white24, width: 0.5),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _customTextField(TextEditingController ctrl, String hint, int lines) {
    return TextField(
      controller: ctrl,
      maxLines: lines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.blueAccent)),
      ),
    );
  }

  // Edit Panel is almost same as Add Panel logic
  void _showEditPanel(BuildContext context, String docId, Map<String, dynamic> data) {
    TextEditingController eTitle = TextEditingController(text: data['title']);
    TextEditingController eMsg = TextEditingController(text: data['message']);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildGlassSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Update Broadcast", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _customTextField(eTitle, "Title", 1),
            const SizedBox(height: 15),
            _customTextField(eMsg, "Message", 4),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () {
                  FirebaseFirestore.instance.collection('broadcasts').doc(docId).delete();
                  Navigator.pop(context);
                }, child: const Text("DELETE", style: TextStyle(color: Colors.redAccent)))),
                Expanded(child: ElevatedButton(onPressed: () {
                  FirebaseFirestore.instance.collection('broadcasts').doc(docId).update({
                    'title': eTitle.text,
                    'message': eMsg.text,
                  });
                  Navigator.pop(context);
                }, child: const Text("SAVE"))),
              ],
            )
          ],
        ),
      ),
    );
  }
}