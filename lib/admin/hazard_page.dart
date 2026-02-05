import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HazardPage extends StatefulWidget {
  const HazardPage({super.key});

  @override
  State<HazardPage> createState() => _HazardPageState();
}

class _HazardPageState extends State<HazardPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? userRole;
  bool isLoading = true;
  String searchQuery = "";
  String selectedSeverity = "Medium"; // Default severity

  @override
  void initState() {
    super.initState();
    _getUserRole();
  }

  Future<void> _getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          userRole = doc.data()?['role'];
          isLoading = false;
        });
      }
    }
  }

  // --- CRUD OPERATIONS ---
  Future<void> _addHazard() async {
    if (_titleController.text.isEmpty || _descController.text.isEmpty) return;
    await FirebaseFirestore.instance.collection('hazards').add({
      'title': _titleController.text,
      'description': _descController.text,
      'location': _locationController.text,
      'severity': selectedSeverity,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _titleController.clear();
    _descController.clear();
    _locationController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = userRole == 'admin';
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("HAZARD ALERTS",
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          _buildBackgroundGlows(),
          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
              : SafeArea(
            child: Column(children: [
              _buildSearchBar(),
              if (isAdmin) _buildAdminInput(),
              Expanded(child: _buildHazardList(isAdmin)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: _buildGlassBox(
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Search hazards or locations...",
            hintStyle: TextStyle(color: Colors.white24),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminInput() {
    return _buildGlassBox(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("ADMIN: REPORT HAZARD",
            style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 15),
        _buildTextField(_titleController, "Hazard Title (e.g. Flooding)", Icons.gpp_maybe),
        const SizedBox(height: 10),
        _buildTextField(_locationController, "Location", Icons.location_on),
        const SizedBox(height: 10),
        _buildTextField(_descController, "Description/Instructions", Icons.info_outline),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ["Low", "Medium", "High"].map((s) {
            bool isSelected = selectedSeverity == s;
            return ChoiceChip(
              label: Text(s, style: TextStyle(color: isSelected ? Colors.black : Colors.white)),
              selected: isSelected,
              selectedColor: Colors.orangeAccent,
              backgroundColor: Colors.white10,
              onSelected: (val) => setState(() => selectedSeverity = s),
            );
          }).toList(),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _addHazard,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("POST ALERT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        )
      ]),
    );
  }

  Widget _buildHazardList(bool isAdmin) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('hazards').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs.where((doc) {
          var d = doc.data() as Map<String, dynamic>;
          return d['title'].toString().toLowerCase().contains(searchQuery) ||
              d['location'].toString().toLowerCase().contains(searchQuery);
        }).toList();

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            Color sevColor = data['severity'] == "High" ? Colors.redAccent : (data['severity'] == "Medium" ? Colors.orangeAccent : Colors.yellowAccent);

            return _buildGlassBox(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.report_problem, color: sevColor, size: 20),
                  const SizedBox(width: 10),
                  Text(data['severity'].toString().toUpperCase(),
                      style: TextStyle(color: sevColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  const Spacer(),
                  if (isAdmin)
                    IconButton(
                      icon: Icon(Icons.delete_sweep, color: Colors.white24, size: 20),
                      onPressed: () => docs[index].reference.delete(),
                    ),
                ]),
                const SizedBox(height: 10),
                Text(data['title'] ?? 'Hazard Alert',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(data['location'] ?? 'Global',
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text(data['description'] ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
                const SizedBox(height: 15),
                const Divider(color: Colors.white10),
                Text("Reported: ${data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate().toString().substring(0,16) : 'Just now'}",
                    style: const TextStyle(color: Colors.white24, fontSize: 10)),
              ]),
            );
          },
        );
      },
    );
  }

  // --- REUSABLE COMPONENTS ---
  Widget _buildGlassBox({required Widget child, EdgeInsets? margin, EdgeInsets? padding}) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08))),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String lbl, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.orangeAccent, size: 18),
        labelText: lbl, labelStyle: const TextStyle(color: Colors.white38),
        filled: true, fillColor: Colors.black.withOpacity(0.3),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.orangeAccent)),
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return Stack(children: [
      Positioned(top: -100, right: -50, child: _glow(Colors.orangeAccent.withOpacity(0.1))),
      Positioned(bottom: -50, left: -100, child: _glow(Colors.redAccent.withOpacity(0.05))),
    ]);
  }

  Widget _glow(Color color) => Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 200, spreadRadius: 50)]));
}