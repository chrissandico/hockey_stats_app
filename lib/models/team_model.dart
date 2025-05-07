import 'package:flutter/material.dart';

class Team {
  final String id;
  final String name;
  final String logoPath;
  final Color primaryColor;
  final Color secondaryColor;
  
  Team({
    required this.id,
    required this.name,
    required this.logoPath,
    required this.primaryColor,
    required this.secondaryColor,
  });
  
  /// Create a Team object from a JSON map
  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String,
      name: json['name'] as String,
      logoPath: json['logoPath'] as String,
      primaryColor: _hexToColor(json['primaryColor'] as String),
      secondaryColor: _hexToColor(json['secondaryColor'] as String),
    );
  }
  
  /// Convert a hex color string to a Color object
  static Color _hexToColor(String hexString) {
    final hexColor = hexString.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }
  
  /// Convert the Team object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logoPath': logoPath,
      'primaryColor': '#${primaryColor.value.toRadixString(16).substring(2, 8)}',
      'secondaryColor': '#${secondaryColor.value.toRadixString(16).substring(2, 8)}',
    };
  }
  
  @override
  String toString() {
    return 'Team{id: $id, name: $name, logoPath: $logoPath}';
  }
}
