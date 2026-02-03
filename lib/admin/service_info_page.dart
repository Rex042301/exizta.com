import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceInformationPage extends StatefulWidget {
  const ServiceInformationPage({super.key});

  @override
  State<ServiceInformationPage> createState() => _ServiceInformationPageState();
}

class _ServiceInformationPageState extends State<ServiceInformationPage> {
  final _firestore = FirebaseFirestore.instance;

  // Function para sa styling ng Header Cells
  Widget _buildHeaderCell(String label) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
          fontSize: 12,
        ),
      ),
    );
  }

  // Function para sa styling ng Data Cells (Excel Style)
  Widget _buildDataCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text("SERVICE TEAM MASTERLIST", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined, color: Colors.blueAccent),
            onPressed: () => _showAddEntryDialog(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // --- Dashboard Stats (Top Bar) ---
            Row(
              children: [
                _buildSimpleStat("TOTAL TEAMS", "available_services"),
                const SizedBox(width: 10),
                _buildSimpleStat("ACTIVE CALLS", "service_requests"),
              ],
            ),
            const SizedBox(height: 20),

            // --- Excel-Type Table ---
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('service_requests').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    var docs = snapshot.data!.docs;

                    return SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 0,
                          horizontalMargin: 0,
                          headingRowHeight: 45,
                          dataRowMinHeight: 50,
                          dataRowMaxHeight: 50,
                          headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
                          // Border configuration para sa columns at rows
                          border: TableBorder.all(color: Colors.white10, width: 0.5),
                          columns: [
                            DataColumn(label: _buildHeaderCell("TEAM TYPE")),
                            DataColumn(label: _buildHeaderCell("CONTACT NAME")),
                            DataColumn(label: _buildHeaderCell("CONTACT NO.")),
                            DataColumn(label: _buildHeaderCell("LOCATION / ADDR")),
                            DataColumn(label: _buildHeaderCell("STATUS")),
                            DataColumn(label: _buildHeaderCell("ACTION")),
                          ],
                          rows: docs.map((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            return DataRow(
                              cells: [
                                DataCell(_buildDataCell(data['serviceType'] ?? "-")),
                                DataCell(_buildDataCell(data['contactName'] ?? data['buildingName'] ?? "-")),
                                DataCell(_buildDataCell(data['phoneNumber'] ?? "-")),
                                DataCell(_buildDataCell(data['address'] ?? "-")),
                                DataCell(
                                  _buildDataCell(data['status'] ?? "Active"),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 16, color: Colors.blueAccent),
                                        onPressed: () {}, // Add Edit Logic
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                                        onPressed: () => _firestore.collection('service_requests').doc(doc.id).delete(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STAT CARD ---
  Widget _buildSimpleStat(String label, String collection) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          border: Border.all(color: Colors.white10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection(collection).snapshots(),
              builder: (context, snap) {
                return Text(
                  snap.hasData ? snap.data!.docs.length.toString() : "0",
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- ADD ENTRY DIALOG ---
  void _showAddEntryDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final typeController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Insert New Record", style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField(typeController, "Team Type (e.g. BFP, PNP)"),
              const SizedBox(height: 10),
              _buildField(nameController, "Contact Person"),
              const SizedBox(height: 10),
              _buildField(phoneController, "Contact Number"),
              const SizedBox(height: 10),
              _buildField(addressController, "Address/Location"),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              _firestore.collection('service_requests').add({
                'serviceType': typeController.text,
                'contactName': nameController.text,
                'phoneNumber': phoneController.text,
                'address': addressController.text,
                'status': 'Active',
                'timestamp': FieldValue.serverTimestamp(),
              });
              Navigator.pop(context);
            },
            child: const Text("SAVE TO SHEET"),
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}