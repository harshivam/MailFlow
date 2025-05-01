import 'package:mail_merge/features/attachments_hub/models/attachment.dart';
import 'package:mail_merge/features/email/services/unified_email_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AttachmentService {
  // Fetch all attachments from all emails
  static Future<List<EmailAttachment>> fetchAllAttachments({
    String? accountId,
  }) async {
    try {
      // First check cache for quick loading
      final cachedAttachments = await _loadCachedAttachments();
      if (cachedAttachments.isNotEmpty) {
        // Filter by account if needed
        if (accountId != null && accountId.isNotEmpty) {
          return cachedAttachments
              .where((attachment) => attachment.accountId == accountId)
              .toList();
        }
        return cachedAttachments;
      }

      // If no cache or cache is empty, fetch from email service
      final emailService = UnifiedEmailService();
      final attachments = await emailService.fetchAllAttachments();

      // Cache the results for future use
      await _cacheAttachments(attachments);

      // Filter by account if needed
      if (accountId != null && accountId.isNotEmpty) {
        return attachments
            .where((attachment) => attachment.accountId == accountId)
            .toList();
      }

      return attachments;
    } catch (e) {
      print('Error fetching attachments: $e');
      return [];
    }
  }

  // Add a public method to access cached attachments
  static Future<List<EmailAttachment>> getCachedAttachments() async {
    return _loadCachedAttachments();
  }

  // Load cached attachments
  static Future<List<EmailAttachment>> _loadCachedAttachments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_attachments');

      if (cachedData != null) {
        final List<dynamic> decodedData = jsonDecode(cachedData);

        return decodedData
            .map(
              (item) =>
                  EmailAttachment.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }

      return [];
    } catch (e) {
      print('Error loading cached attachments: $e');
      return [];
    }
  }

  // Cache attachments for faster loading next time
  static Future<void> _cacheAttachments(
    List<EmailAttachment> attachments,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_attachments',
        jsonEncode(attachments.map((a) => a.toJson()).toList()),
      );
    } catch (e) {
      print('Error caching attachments: $e');
    }
  }

  // Clear the attachments cache
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_attachments');
    } catch (e) {
      print('Error clearing attachment cache: $e');
    }
  }
}
