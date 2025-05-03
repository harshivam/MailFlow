import 'package:flutter/foundation.dart';

class SubscriptionEmail {
  final String id;
  final String sender;
  final String senderEmail;
  final String subject;
  final DateTime date;
  final String unsubscribeUrl;
  final String unsubscribeEmail;
  final String accountId;
  final String accountName;
  final String snippet;
  bool isSelected;
  bool isUnsubscribing;
  bool unsubscribeSuccess;

  SubscriptionEmail({
    required this.id,
    required this.sender,
    required this.senderEmail,
    required this.subject,
    required this.date,
    required this.unsubscribeUrl,
    required this.unsubscribeEmail,
    required this.accountId,
    required this.accountName,
    required this.snippet,
    this.isSelected = false,
    this.isUnsubscribing = false,
    this.unsubscribeSuccess = false,
  });

  // Create a copy with some properties changed
  SubscriptionEmail copyWith({
    bool? isSelected,
    bool? isUnsubscribing,
    bool? unsubscribeSuccess,
  }) {
    return SubscriptionEmail(
      id: id,
      sender: sender,
      senderEmail: senderEmail,
      subject: subject,
      date: date,
      unsubscribeUrl: unsubscribeUrl,
      unsubscribeEmail: unsubscribeEmail,
      accountId: accountId,
      accountName: accountName,
      snippet: snippet,
      isSelected: isSelected ?? this.isSelected,
      isUnsubscribing: isUnsubscribing ?? this.isUnsubscribing,
      unsubscribeSuccess: unsubscribeSuccess ?? this.unsubscribeSuccess,
    );
  }

  // To JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'senderEmail': senderEmail,
      'subject': subject,
      'date': date.toIso8601String(),
      'unsubscribeUrl': unsubscribeUrl,
      'unsubscribeEmail': unsubscribeEmail,
      'accountId': accountId,
      'accountName': accountName,
      'snippet': snippet,
      'unsubscribeSuccess': unsubscribeSuccess,
    };
  }

  // From JSON for cache retrieval
  factory SubscriptionEmail.fromJson(Map<String, dynamic> json) {
    return SubscriptionEmail(
      id: json['id'],
      sender: json['sender'],
      senderEmail: json['senderEmail'],
      subject: json['subject'],
      date: DateTime.parse(json['date']),
      unsubscribeUrl: json['unsubscribeUrl'],
      unsubscribeEmail: json['unsubscribeEmail'],
      accountId: json['accountId'],
      accountName: json['accountName'],
      snippet: json['snippet'],
      unsubscribeSuccess: json['unsubscribeSuccess'] ?? false,
    );
  }
}
