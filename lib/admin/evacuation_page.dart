import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class EvacuationPage extends StatefulWidget {
  const EvacuationPage({super.key});

  @override
  State<EvacuationPage> createState() => _EvacuationPageState();
}

class _EvacuationPageState extends State<EvacuationPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? userRole;
  bool isLoading = true;
  String searchQuery = "";
  String selectedStatus = "Available";

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
  Future<void> _addEvac() async {
    if (_nameController.text.isEmpty || _addressController.text.isEmpty) return;
    await FirebaseFirestore.instance.collection('evacuations').add({
      'name': _nameController.text,
      'address': _addressController.text,
      'capacity': _capacityController.text.isEmpty ? 'Not Specified' : _capacityController.text,
      'status': selectedStatus,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _nameController.clear();
    _addressController.clear();
    _capacityController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _openMaps(String name) async {
    final String query = Uri.encodeComponent(name);
    final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$query";
    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl));
    }
  }

  void _showEditSheet(String docId, Map<String, dynamic> data) {
    final eName = TextEditingController(text: data['name']);
    final eAddress = TextEditingController(text: data['address']);
    final eCapacity = TextEditingController(text: data['capacity']);
    String eStatus = data['status'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20),
            decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _buildTextField(eName, "Center Name", Icons.home_work),
              const SizedBox(height: 10),
              _buildTextField(eAddress, "Full Address", Icons.location_on),
              const SizedBox(height: 10),
              _buildTextField(eCapacity, "Capacity", Icons.people),
              const SizedBox(height: 15),
              DropdownButton<String>(
                value: eStatus,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                items: ["Available", "Full", "Warning"]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) => setModalState(() => eStatus = val!),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    FirebaseFirestore.instance.collection('evacuations').doc(docId).update({
                      'name': eName.text,
                      'address': eAddress.text,
                      'capacity': eCapacity.text,
                      'status': eStatus
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                  child: const Text("UPDATE CENTER"),
                ),
              ),
              const SizedBox(height: 30),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = userRole == 'admin';
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("EVACUATION CENTERS",
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 2)),
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
              ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
              : SafeArea(
            child: Column(children: [
              _buildSearchBar(),
              if (isAdmin) _buildAdminInput(),
              Expanded(child: _buildEvacList(isAdmin)),
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
            hintText: "Search safe zones...",
            hintStyle: TextStyle(color: Colors.white24),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: Colors.greenAccent),
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
        const Text("ADMIN: ADD CENTER",
            style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5)),
        const SizedBox(height: 15),
        _buildTextField(_nameController, "Center Name", Icons.business),
        const SizedBox(height: 10),
        _buildTextField(_addressController, "Address", Icons.map),
        const SizedBox(height: 10),
        _buildTextField(_capacityController, "Capacity", Icons.bolt),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _addEvac,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text("SAVE CENTER",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        )
      ]),
    );
  }

  Widget _buildEvacList(bool isAdmin) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('evacuations')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs.where((doc) {
          var d = doc.data() as Map<String, dynamic>;
          return d['name'].toString().toLowerCase().contains(searchQuery) ||
              d['address'].toString().toLowerCase().contains(searchQuery);
        }).toList();

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            var id = docs[index].id;
            Color statusColor = data['status'] == "Full"
                ? Colors.redAccent
                : (data['status'] == "Warning" ? Colors.orangeAccent : Colors.greenAccent);

            return _buildGlassBox(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(15),
              child: Column(children: [
                Row(children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(data['status'].toString().toUpperCase(),
                      style: TextStyle(
                          color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (isAdmin) ...[
                    IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white24, size: 18),
                        onPressed: () => _showEditSheet(id, data)),
                    IconButton(
                        icon: Icon(Icons.delete,
                            color: Colors.red.withOpacity(0.5), size: 18),
                        onPressed: () => docs[index].reference.delete()),
                  ]
                ]),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(data['name'] ?? 'Unknown',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(data['address'] ?? 'No Address',
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  trailing: IconButton(
                      icon: const Icon(Icons.directions, color: Colors.greenAccent, size: 28),
                      onPressed: () => _openMaps(data['name'])),
                ),
                const Divider(color: Colors.white10),
                Row(children: [
                  const Icon(Icons.people_outline, color: Colors.white38, size: 14),
                  const SizedBox(width: 5),
                  Text("Capacity: ${data['capacity']}",
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ])
              ]),
            );
          },
        );
      },
    );
  }

  Widget _buildGlassBox({required Widget child, EdgeInsets? margin, EdgeInsets? padding}) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1))),
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
        prefixIcon: Icon(icon, color: Colors.greenAccent, size: 18),
        labelText: lbl,
        labelStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.greenAccent)),
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return Stack(children: [
      Positioned(top: -100, left: -50, child: _glow(Colors.greenAccent.withOpacity(0.12))),
      Positioned(bottom: -100, right: -50, child: _glow(Colors.blueAccent.withOpacity(0.08))),
    ]);
  }

  Widget _glow(Color color) => Container(
      width: 400,
      height: 400,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color, blurRadius: 150, spreadRadius: 50)]));
}