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
      Navigator.pop(context);
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
      // Ginawa nating false ito para tayo ang mag-control ng spacing
      resizeToAvoidBottomInset: false,
      floatingActionButton: _buildAddButton(),
      // Inangat natin ang FAB para hindi matabunan ng Nav Bar
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          _buildMainBackground(),
          SafeArea( // Sinisigurado nito na hindi tatama sa notch or system bars
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

                // ANNOUNCEMENT LIST
                Expanded(
                  child: ListView( // Pinalitan ng ListView para mas madaling lagyan ng padding sa dulo
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 140), // 140 padding sa bottom para iwas sa Nav Bar
                    children: [
                      const Text(
                        "RECENT UPDATES",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 2),
                      ),
                      const SizedBox(height: 15),
                      _buildRecentUpdatesList(),
                    ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 100), // Inangat ang button para nasa taas ng Nav Bar
      child: FloatingActionButton.extended(
        onPressed: () => _showAddAnnouncementPanel(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        label: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.9),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_comment_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Text("NEW BROADCAST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // PANEL WITH KEYBOARD AWARENESS
  void _showAddAnnouncementPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _buildGlassSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Create Broadcast", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              _customTextField(_titleController, "Title", 1, maxLength: 50),
              const SizedBox(height: 15),
              _customTextField(_messageController, "Write message...", 5, maxLength: 250),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: _isSending ? null : _postUpdate,
                  child: _isSending ? const CircularProgressIndicator(color: Colors.white) : const Text("RELEASE ANNOUNCEMENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassSheet({required Widget child}) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
      child: Container(
        padding: const EdgeInsets.fromLTRB(25, 25, 25, 30),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
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
                color: Colors.white.withOpacity(0.04),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: ListTile(
                onTap: () => _showEditPanel(context, docs[index].id, data),
                leading: const Icon(Icons.campaign_rounded, color: Colors.blueAccent),
                title: Text(data['title'] ?? "", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(data['message'] ?? "", style: const TextStyle(color: Colors.white38, fontSize: 12), maxLines: 1),
                trailing: const Icon(Icons.edit_note_rounded, color: Colors.white24),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCrystalBackButton() {
    return InkWell(
      onTap: widget.onBack,
      child: Container(
        height: 45, width: 45,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white24)),
        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _customTextField(TextEditingController ctrl, String hint, int lines, {int? maxLength}) {
    return TextField(
      controller: ctrl,
      maxLines: lines,
      maxLength: maxLength,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.blueAccent)),
      ),
    );
  }

  void _showEditPanel(BuildContext context, String docId, Map<String, dynamic> data) {
    TextEditingController eTitle = TextEditingController(text: data['title']);
    TextEditingController eMsg = TextEditingController(text: data['message']);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _buildGlassSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Edit Broadcast", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _customTextField(eTitle, "Title", 1, maxLength: 50),
              const SizedBox(height: 15),
              _customTextField(eMsg, "Message", 4, maxLength: 250),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () { FirebaseFirestore.instance.collection('broadcasts').doc(docId).delete(); Navigator.pop(context); }, child: const Text("DELETE", style: TextStyle(color: Colors.redAccent)))),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton(onPressed: () { FirebaseFirestore.instance.collection('broadcasts').doc(docId).update({'title': eTitle.text, 'message': eMsg.text}); Navigator.pop(context); }, child: const Text("SAVE"))),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}