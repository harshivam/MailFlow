import 'package:uuid/uuid.dart';

enum AccountProvider {
  gmail,
  outlook,
  rediffmail;

  String get displayName {
    switch (this) {
      case AccountProvider.gmail:
        return 'Gmail';
      case AccountProvider.outlook:
        return 'Outlook';
      case AccountProvider.rediffmail:
        return 'Rediffmail';
    }
  }

  String get iconAsset {
    switch (this) {
      case AccountProvider.gmail:
        return 'assets/images/gmail_icon.png';
      case AccountProvider.outlook:
        return 'assets/images/outlook_icon.png';
      case AccountProvider.rediffmail:
        return 'assets/images/rediffmail_icon.png';
    }
  }
}

class EmailAccount {
  final String id;
  final String email;
  final String displayName;
  final AccountProvider provider;
  final String accessToken;
  final String refreshToken;
  final DateTime tokenExpiry;
  final bool isDefault;
  final String? photoUrl;

  EmailAccount({
    String? id,
    required this.email,
    required this.displayName,
    required this.provider,
    required this.accessToken,
    required this.refreshToken,
    required this.tokenExpiry,
    this.isDefault = false,
    this.photoUrl,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'provider': provider.index,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'tokenExpiry': tokenExpiry.millisecondsSinceEpoch,
      'isDefault': isDefault,
      'photoUrl': photoUrl,
    };
  }

  factory EmailAccount.fromJson(Map<String, dynamic> json) {
    return EmailAccount(
      id: json['id'],
      email: json['email'],
      displayName: json['displayName'],
      provider: AccountProvider.values[json['provider']],
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
      tokenExpiry: DateTime.fromMillisecondsSinceEpoch(json['tokenExpiry']),
      isDefault: json['isDefault'] ?? false,
      photoUrl: json['photoUrl'],
    );
  }

  EmailAccount copyWith({
    String? id,
    String? email,
    String? displayName,
    AccountProvider? provider,
    String? accessToken,
    String? refreshToken,
    DateTime? tokenExpiry,
    bool? isDefault,
    String? photoUrl,
  }) {
    return EmailAccount(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      provider: provider ?? this.provider,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenExpiry: tokenExpiry ?? this.tokenExpiry,
      isDefault: isDefault ?? this.isDefault,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}