import 'package:flutter/material.dart';

class CustomFilter {
  final String id;
  final String name;
  final String keyword;
  final IconData icon;
  final Color color;
  final DateTime createdAt;
  
  const CustomFilter({
    required this.id,
    required this.name,
    required this.keyword,
    this.icon = Icons.filter_list,
    this.color = Colors.blueAccent,
    required this.createdAt,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'keyword': keyword,
    'icon': icon.codePoint,
    'iconFontFamily': icon.fontFamily,
    'color': color.value,
    'createdAt': createdAt.toIso8601String(),
  };
  
  factory CustomFilter.fromJson(Map<String, dynamic> json) => CustomFilter(
    id: json['id'],
    name: json['name'],
    keyword: json['keyword'],
    icon: IconData(
      json['icon'], 
      fontFamily: json['iconFontFamily'] ?? 'MaterialIcons'
    ),
    color: Color(json['color']),
    createdAt: DateTime.parse(json['createdAt']),
  );
}