import 'package:flutter/material.dart';

class EmergencyAlert {
  final String id;
  final String title;
  final String time;
  final String body;
  final String type;

  EmergencyAlert({
    required this.id,
    required this.title,
    required this.time,
    required this.body,
    required this.type,
  });
}

// Initial Mock Data
List<EmergencyAlert> mockAlerts = [
  EmergencyAlert(
    id: '1',
    title: "Flood Alert: Level 1",
    time: "2 hours ago",
    body: "Keep track of water levels in Tunasan area. Prepare emergency kits.",
    type: "warning",
  ),
  EmergencyAlert(
    id: '2',
    title: "Fire Incident Reported",
    time: "5 hours ago",
    body: "Fire responders are on site at Brgy. Alabang. Please avoid the area.",
    type: "emergency",
  ),
];