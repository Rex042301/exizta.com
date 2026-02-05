import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  String _search = "";
  String _filter = "all";
  final ScrollController _horizontalScroll = ScrollController();

  // --- CSV Export Function ---
  Future<void> _exportUsersToCSV() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection("users").get();
      List<List<dynamic>> rows = [];
      rows.add(["ID", "Name", "Email", "Phone", "Role", "Status"]);

      for (var i = 0; i < snapshot.docs.length; i++) {
        var data = snapshot.docs[i].data();
        rows.add([
          (i + 1).toString(),
          data["name"] ?? "N/A",
          data["email"] ?? "N/A",
          data["phone"] ?? "N/A",
          data["role"] ?? "user",
          data["status"] ?? "active",
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/Aiper_User_Export.csv";
      final file = File(path);
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(path)], text: 'Aiper User Database Export');
    } catch (e) {
      _showSnackBar("Export failed: $e", Colors.redAccent);
    }
  }

  // --- ADMIN ACTIONS: EDIT ---
  void _showEditDialog(String uid, Map<String, dynamic> data) {
    final nameCtrl = TextEditingController(text: data["name"] ?? "");
    String selectedRole = data["role"] ?? "user";
    String selectedStatus = data["status"] ?? "active";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white10),
        ),
        title: const Text("Edit User Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField("Full Name", nameCtrl),
              const SizedBox(height: 15),
              _buildDialogDropdown("Role", selectedRole, ["user", "admin"], (v) {
                setDialogState(() => selectedRole = v!);
              }),
              const SizedBox(height: 15),
              _buildDialogDropdown("Status", selectedStatus, ["active", "blocked", "verified"], (v) {
                setDialogState(() => selectedStatus = v!);
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () async {
              await FirebaseFirestore.instance.collection("users").doc(uid).update({
                "name": nameCtrl.text.trim(),
                "role": selectedRole,
                "status": selectedStatus,
              });
              if (!mounted) return;
              Navigator.pop(context);
              _showSnackBar("User updated successfully!", Colors.blueAccent);
            },
            child: const Text("SAVE CHANGES"),
          ),
        ],
      ),
    );
  }

  // --- ADMIN ACTIONS: DELETE ---
  void _confirmDelete(String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.redAccent, width: 0.5),
        ),
        title: const Text("Confirm Delete", style: TextStyle(color: Colors.white)),
        content: const Text("Sigurado ka ba? Hindi na maibabalik ang account na ito kapag binura.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection("users").doc(uid).delete();
              if (!mounted) return;
              Navigator.pop(context);
              _showSnackBar("User deleted from database.", Colors.redAccent);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildMainBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.2),
                          ),
                          child: Column(
                            children: [
                              _searchBar(),
                              _filterButtons(),
                              Expanded(
                                child: Scrollbar(
                                  controller: _horizontalScroll,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _horizontalScroll,
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: SizedBox(
                                      width: 1100,
                                      child: Column(
                                        children: [
                                          _tableHeader(),
                                          Expanded(child: _buildUserList()),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  // --- UI COMPONENTS ---

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("users").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));

        final allDocs = snapshot.data!.docs;
        final filteredDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;

          final name = (data["name"] ?? "").toString().toLowerCase();
          final email = (data["email"] ?? "").toString().toLowerCase();
          final status = (data["status"] ?? "active").toString().toLowerCase();

          final matchesFilter = _filter == "all" || status == _filter;
          final matchesSearch = name.contains(_search) || email.contains(_search);

          return matchesFilter && matchesSearch;
        }).toList();

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _excelRow(data, index + 1, doc.id);
          },
        );
      },
    );
  }

  Widget _excelRow(Map<String, dynamic> data, int id, String uid) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1)))),
      child: Row(
        children: [
          _ExcelCell("#${id.toString().padLeft(2, '0')}", 70, color: Colors.blueAccent, isBold: true),
          _ExcelCell(data["name"] ?? "N/A", 180),
          _ExcelCell(data["email"] ?? "N/A", 250),
          _ExcelCell(data["phone"] ?? "N/A", 150),
          _ExcelCell(data["role"]?.toString().toUpperCase() ?? "USER", 120),
          _excelWidgetCell(_statusBadge(data["status"] ?? "active"), 120),
          _excelWidgetCell(_actionButtons(uid, data), 110),
        ],
      ),
    );
  }

  Widget _actionButtons(String uid, Map<String, dynamic> data) {
    return Row(children: [
      IconButton(icon: const Icon(Icons.edit_note_rounded, color: Colors.blueAccent), onPressed: () => _showEditDialog(uid, data)),
      IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), onPressed: () => _confirmDelete(uid)),
    ]);
  }

  // (Helper Widgets below...)
  Widget _buildMainBackground() {
    return Stack(
      children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.black, Color(0xFF001A33), Colors.black], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
        _buildGlowCircle(top: -100, left: -50, color: Colors.blueAccent),
        _buildGlowCircle(bottom: 100, right: -80, color: Colors.indigoAccent),
      ],
    );
  }

  Widget _buildGlowCircle({double? top, double? bottom, double? left, double? right, required Color color}) {
    return Positioned(top: top, bottom: bottom, left: left, right: right, child: Container(width: 350, height: 350, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 120, spreadRadius: 60)])));
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18), onPressed: () => Navigator.pop(context)),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("User Database", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 1)),
              Text("MANAGE ACCOUNTS & ROLES", style: TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          const Spacer(),
          IconButton(onPressed: _exportUsersToCSV, icon: const Icon(Icons.file_download_outlined, color: Colors.greenAccent)),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        onChanged: (v) => setState(() => _search = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: "Search user...",
          prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
          filled: true, fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  Widget _filterButtons() {
    final filters = ["all", "active", "blocked"];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        children: filters.map((f) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(f.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
            backgroundColor: _filter == f ? Colors.blueAccent : Colors.white12,
            onPressed: () => setState(() => _filter = f),
          ),
        )).toList(),
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      color: Colors.white.withOpacity(0.05),
      child: const Row(
        children: [
          _ExcelCell("ID", 70, isHeader: true),
          _ExcelCell("NAME", 180, isHeader: true),
          _ExcelCell("EMAIL", 250, isHeader: true),
          _ExcelCell("PHONE", 150, isHeader: true),
          _ExcelCell("ROLE", 120, isHeader: true),
          _ExcelCell("STATUS", 120, isHeader: true),
          _ExcelCell("ACTIONS", 110, isHeader: true),
        ],
      ),
    );
  }

  Widget _excelWidgetCell(Widget child, double width) {
    return Container(width: width, height: 55, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.centerLeft, child: child);
  }

  Widget _statusBadge(String status) {
    final color = status == "blocked" ? Colors.redAccent : Colors.greenAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildDialogField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: Colors.white38),
        filled: true, fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDialogDropdown(String label, String value, List<String> items, Function(String?) onChange) {
    return DropdownButtonFormField<String>(
      value: value, dropdownColor: Colors.grey[900],
      style: const TextStyle(color: Colors.white),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
      onChanged: onChange,
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }
}

class _ExcelCell extends StatelessWidget {
  final String text; final double width; final bool isHeader; final Color? color; final bool isBold;
  const _ExcelCell(this.text, this.width, {this.isHeader = false, this.color, this.isBold = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width, height: 55, padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.centerLeft,
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1)))),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color ?? (isHeader ? Colors.white38 : Colors.white70), fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal, fontSize: isHeader ? 11 : 13)),
    );
  }
}