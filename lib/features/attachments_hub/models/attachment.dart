import 'package:flutter/material.dart';

class EmailAttachment {
  final String id;
  final String name;
  final String contentType;
  final int size;
  final String downloadUrl;
  final String emailId;
  final String emailSubject;
  final String senderName;
  final String senderEmail;
  final DateTime date;
  final String accountId;

  const EmailAttachment({
    required this.id,
    required this.name,
    required this.contentType,
    required this.size,
    required this.downloadUrl,
    required this.emailId,
    required this.emailSubject,
    required this.senderName,
    required this.senderEmail,
    required this.date,
    required this.accountId,
  });

  // Get appropriate icon based on file type
  IconData get icon {
    if (contentType.contains('image')) return Icons.image;
    if (contentType.contains('pdf')) return Icons.picture_as_pdf;
    if (contentType.contains('word') || contentType.contains('document'))
      return Icons.description;
    if (contentType.contains('excel') || contentType.contains('spreadsheet'))
      return Icons.table_chart;
    if (contentType.contains('presentation') ||
        contentType.contains('powerpoint'))
      return Icons.slideshow;
    if (contentType.contains('zip') || contentType.contains('rar'))
      return Icons.folder_zip;
    if (contentType.contains('audio')) return Icons.audiotrack;
    if (contentType.contains('video')) return Icons.video_file;
    return Icons.attach_file;
  }

  // Get formatted size (KB, MB, etc.)
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1048576) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1048576).toStringAsFixed(1)} MB';
  }

  // Factory method to create from JSON
  factory EmailAttachment.fromJson(Map<String, dynamic> json) {
    return EmailAttachment(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      contentType: json['contentType'] ?? 'application/octet-stream',
      size: json['size'] ?? 0,
      downloadUrl: json['downloadUrl'] ?? '',
      emailId: json['emailId'] ?? '',
      emailSubject: json['emailSubject'] ?? '',
      senderName: json['senderName'] ?? '',
      senderEmail: json['senderEmail'] ?? '',
      date:
          json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      accountId: json['accountId'] ?? '',
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contentType': contentType,
      'size': size,
      'downloadUrl': downloadUrl,
      'emailId': emailId,
      'emailSubject': emailSubject,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'date': date.toIso8601String(),
      'accountId': accountId,
    };
  }
}
