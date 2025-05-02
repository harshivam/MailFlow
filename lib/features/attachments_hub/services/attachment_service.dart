import 'dart:convert';
import 'package:mail_merge/features/attachments_hub/models/attachment.dart';
import 'package:mail_merge/features/email/services/unified_email_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mail_merge/core/services/event_bus.dart';

// Event for attachment refresh notifications
class AttachmentsRefreshedEvent {}

class AttachmentService {
  static final AttachmentService _instance = AttachmentService._internal();
  factory AttachmentService() => _instance;
  AttachmentService._internal();

  // Update fetchAllAttachments to handle pagination
  Future<List<EmailAttachment>> fetchAllAttachments({
    int pageSize = 10, // Updated to load 10 at once
    int page = 0, // Page number for pagination
    Function(double)? onProgress,
    String? accountId,
    String? fileType,
    required bool refresh,
  }) async {
    try {
      // Report initial progress
      onProgress?.call(0.1);
      print(
        'AttachmentService: Starting fetchAllAttachments, page=$page, refresh=$refresh',
      );

      // First check cache for quick loading (always use cache for fast initial load)
      final cachedAttachments = await _loadCachedAttachments();
      print(
        'AttachmentService: Found ${cachedAttachments.length} cached attachments',
      );

      // Apply filters first
      final filteredCachedAttachments = _filterAttachments(
        cachedAttachments,
        accountId: accountId,
        fileType: fileType,
      );

      // For initial load (page 0) use cached data to show something quickly
      if (page == 0) {
        // Report completion
        onProgress?.call(1.0);

        // Start a background refresh if needed and it's the first page
        if (refresh || cachedAttachments.isEmpty) {
          _refreshAttachmentsInBackground();
        }

        // Return paginated results (first 10 items)
        final startIndex = 0;
        final endIndex =
            filteredCachedAttachments.length > pageSize
                ? pageSize
                : filteredCachedAttachments.length;

        return filteredCachedAttachments.sublist(startIndex, endIndex);
      }

      // For subsequent pages (page > 0), return paginated cached results
      if (cachedAttachments.isNotEmpty) {
        final startIndex = page * pageSize;

        // If we're asking for a page beyond what we have in cache, start a refresh
        if (startIndex >= filteredCachedAttachments.length) {
          // We need to fetch more data
          if (!refresh) {
            _refreshAttachmentsInBackground();
          }
          // Return empty list if we're beyond available data
          return [];
        }

        final endIndex =
            (startIndex + pageSize) > filteredCachedAttachments.length
                ? filteredCachedAttachments.length
                : (startIndex + pageSize);

        return filteredCachedAttachments.sublist(startIndex, endIndex);
      }

      // If we have no cached data, we need to fetch from API
      onProgress?.call(0.3);
      print('AttachmentService: Fetching fresh data from email service');

      final emailService = UnifiedEmailService();
      List<EmailAttachment> attachments = [];

      try {
        attachments = await emailService.fetchAllAttachments();
        print('AttachmentService: Got ${attachments.length} fresh attachments');

        // Save the timestamp of this refresh
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          'last_attachment_refresh',
          DateTime.now().millisecondsSinceEpoch,
        );

        // Cache the results if we got any
        if (attachments.isNotEmpty) {
          await _cacheAttachments(attachments);
          print('AttachmentService: Cached the attachments successfully');
        }

        onProgress?.call(1.0);

        final filtered = _filterAttachments(
          attachments,
          accountId: accountId,
          fileType: fileType,
        );

        // Return only the requested page of results
        final startIndex = page * pageSize;
        final endIndex =
            (startIndex + pageSize) > filtered.length
                ? filtered.length
                : (startIndex + pageSize);

        return filtered.sublist(startIndex, endIndex);
      } catch (e) {
        print('AttachmentService: Error fetching fresh attachments: $e');

        // If there's a 429 rate limit error, propagate it
        if (e.toString().contains('429')) {
          onProgress?.call(1.0);
          throw Exception('Rate limited: $e');
        }

        // Fall back to cached data if available
        if (cachedAttachments.isNotEmpty) {
          print('AttachmentService: Falling back to cached data');
          onProgress?.call(1.0);

          final filtered = _filterAttachments(
            cachedAttachments,
            accountId: accountId,
            fileType: fileType,
          );

          // Return only the requested page of results
          final startIndex = page * pageSize;
          final endIndex =
              (startIndex + pageSize) > filtered.length
                  ? filtered.length
                  : (startIndex + pageSize);

          return filtered.sublist(startIndex, endIndex);
        }

        // If no cache and error, just return empty list
        onProgress?.call(1.0);
        return [];
      }
    } catch (e) {
      print('AttachmentService: Error in fetchAllAttachments: $e');
      onProgress?.call(1.0);

      // Propagate rate limit errors
      if (e.toString().contains('429')) {
        throw e; // Re-throw the rate limit error
      }

      return [];
    }
  }

  // Apply filters to attachment list
  List<EmailAttachment> _filterAttachments(
    List<EmailAttachment> attachments, {
    String? accountId,
    String? fileType,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return attachments.where((attachment) {
      // Account filter
      if (accountId != null && accountId.isNotEmpty) {
        if (attachment.accountId != accountId) return false;
      }

      // File type filter
      if (fileType != null && fileType.isNotEmpty) {
        bool matches = false;
        switch (fileType.toLowerCase()) {
          case 'images':
            matches = attachment.contentType.contains('image');
            break;
          case 'documents':
            matches =
                attachment.contentType.contains('pdf') ||
                attachment.contentType.contains('doc') ||
                attachment.contentType.contains('text');
            break;
          case 'spreadsheets':
            matches =
                attachment.contentType.contains('excel') ||
                attachment.contentType.contains('sheet');
            break;
          default:
            matches = attachment.contentType.toLowerCase().contains(
              fileType.toLowerCase(),
            );
        }
        if (!matches) return false;
      }

      // Date range filters
      if (startDate != null && attachment.date.isBefore(startDate)) {
        return false;
      }
      if (endDate != null && attachment.date.isAfter(endDate)) {
        return false;
      }

      return true;
    }).toList();
  }

  // Get cached attachments
  Future<List<EmailAttachment>> getCachedAttachments() async {
    return await _loadCachedAttachments();
  }

  // Load cached attachments
  Future<List<EmailAttachment>> _loadCachedAttachments() async {
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

  // Cache attachments
  Future<void> _cacheAttachments(List<EmailAttachment> attachments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_attachments',
        jsonEncode(attachments.map((a) => a.toJson()).toList()),
      );

      // Notify listeners that attachments were updated
      eventBus.fire(AttachmentsRefreshedEvent());
    } catch (e) {
      print('Error caching attachments: $e');
    }
  }

  // Clear cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_attachments');
    } catch (e) {
      print('Error clearing attachment cache: $e');
    }
  }

  // Refresh attachments in background
  Future<void> _refreshAttachmentsInBackground() async {
    try {
      final emailService = UnifiedEmailService();
      print('Starting background attachment refresh');

      // Fetch attachments without blocking UI
      final attachments = await emailService.fetchAllAttachments();
      print('Background fetch complete with ${attachments.length} attachments');

      // Cache results
      if (attachments.isNotEmpty) {
        await _cacheAttachments(attachments);

        // Fire event to notify listeners that new data is available
        eventBus.fire(AttachmentsRefreshedEvent());
      }
    } catch (e) {
      print('Error in background refresh: $e');
    }
  }

  // Mark attachment as favorite (for future feature)
  Future<void> toggleFavorite(EmailAttachment attachment) async {
    try {
      final attachments = await _loadCachedAttachments();

      // Find and update the attachment
      final index = attachments.indexWhere((a) => a.id == attachment.id);
      if (index >= 0) {
        final updated = attachment.copyWith(
          isFavorite: !(attachment.isFavorite ?? false),
        );
        attachments[index] = updated;
        await _cacheAttachments(attachments);
      }
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  // Set category for an attachment (for future feature)
  Future<void> setCategory(EmailAttachment attachment, String category) async {
    try {
      final attachments = await _loadCachedAttachments();

      // Find and update the attachment
      final index = attachments.indexWhere((a) => a.id == attachment.id);
      if (index >= 0) {
        final updated = attachment.copyWith(category: category);
        attachments[index] = updated;
        await _cacheAttachments(attachments);
      }
    } catch (e) {
      print('Error setting category: $e');
    }
  }
}
