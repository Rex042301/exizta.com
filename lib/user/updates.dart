import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UserUpdates extends StatelessWidget {
  const UserUpdates({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Pure Black Theme
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                "Community Updates",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Text("Latest announcements and discussions", style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 25),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('broadcasts')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var doc = snapshot.data!.docs[index];
                        return _buildGlowingUpdateCard(context, doc);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 100), // Space para sa Floating Navbar
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET: CARD WITH COMMENT BUTTON ---
  Widget _buildGlowingUpdateCard(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    String formattedTime = data['timestamp'] != null
        ? DateFormat('MMM dd, hh:mm a').format((data['timestamp'] as Timestamp).toDate())
        : "Recently";

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.white.withOpacity(0.08), blurRadius: 15, spreadRadius: 1),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(data['title'] ?? "Update", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white))),
                    _typeBadge(data['type'] ?? "Info"),
                  ],
                ),
                Text(formattedTime, style: const TextStyle(fontSize: 11, color: Colors.white38)),
                const SizedBox(height: 15),
                Text(data['message'] ?? "", style: const TextStyle(color: Colors.white70, height: 1.5)),
                const Divider(color: Colors.white10, height: 30),

                // --- COMMENT BUTTON ---
                GestureDetector(
                  onTap: () => _showCommentSheet(context, doc.id),
                  child: Row(
                    children: [
                      const Icon(Icons.mode_comment_outlined, color: Colors.blueAccent, size: 20),
                      const SizedBox(width: 8),
                      const Text("View Comments", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      // Count of comments (Optional: Pwedeng lagyan ng Stream para sa count)
                      const Icon(Icons.chevron_right, color: Colors.white24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- COMMENT BOTTOM SHEET ---
  void _showCommentSheet(BuildContext context, String broadcastId) {
    final TextEditingController commentController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 15),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text("Comments", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),

              // --- LIST OF COMMENTS ---
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('broadcasts')
                      .doc(broadcastId)
                      .collection('comments')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var comments = snapshot.data!.docs;
                    if (comments.isEmpty) return const Center(child: Text("No comments yet.", style: TextStyle(color: Colors.white38)));

                    return ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        var c = comments[index].data() as Map<String, dynamic>;
                        return ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.person, color: Colors.white)),
                          title: Text(c['userName'] ?? "Anonymous", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(c['text'] ?? "", style: const TextStyle(color: Colors.white70)),
                        );
                      },
                    );
                  },
                ),
              ),

              // --- COMMENT INPUT FIELD ---
              Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Write a comment...",
                          hintStyle: const TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: () async {
                        if (commentController.text.isNotEmpty && user != null) {
                          await FirebaseFirestore.instance
                              .collection('broadcasts')
                              .doc(broadcastId)
                              .collection('comments')
                              .add({
                            'text': commentController.text,
                            'userId': user.uid,
                            'userName': user.email?.split('@')[0] ?? "User",
                            'timestamp': FieldValue.serverTimestamp(),
                          });
                          commentController.clear();
                        }
                      },
                      icon: const Icon(Icons.send, color: Colors.blueAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // (Isama rito ang _typeBadge at _buildEmptyState mula sa dating code...)
  Widget _typeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
      ),
      child: Text(type.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 80, color: Colors.white10),
          Text("No announcements yet", style: TextStyle(color: Colors.white24, fontSize: 16)),
        ],
      ),
    );
  }
}