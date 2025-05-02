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

  // Track last API request time
  static DateTime _lastApiRequest = DateTime.now().subtract(
    Duration(minutes: 1),
  );
  static const _minRequestInterval = Duration(milliseconds: 500);

  // Throttle API requests to prevent rate limiting
  Future<void> _throttleApiRequests() async {
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(_lastApiRequest);

    if (timeSinceLastRequest < _minRequestInterval) {
      // Wait the remaining time before making another request
      final waitTime = _minRequestInterval - timeSinceLastRequest;
      await Future.delayed(waitTime);
    }

    // Update last request time
    _lastApiRequest = DateTime.now();
  }

  // Update the fetchAllAttachments method to better use cache
  Future<List<EmailAttachment>> fetchAllAttachments({
    int pageSize = 6,
    int page = 0,
    Function(double)? onProgress,
    String? accountId,
    String? fileType,
    required bool refresh,
  }) async {
    try {
      // FAST PATH: Always show cached data immediately
      onProgress?.call(0.1);
      final cachedAttachments = await _loadCachedAttachments();
      
      // Apply filters to cached data
      final filteredCachedAttachments = _filterAttachments(
        cachedAttachments,
        accountId: accountId,
        fileType: fileType,
      );
      
      onProgress?.call(0.3);
      
      // Immediately return cached data for first render
      if (cachedAttachments.isNotEmpty && !refresh) {
        // Also trigger background refresh if cache is stale
        if (await _isCacheStale()) {
          _refreshAttachmentsInBackground(accountId: accountId);
        }
        
        onProgress?.call(1.0);
        return _getPaginatedResults(filteredCachedAttachments, page, pageSize);
      }
      
      // If refresh requested or no cache, use API but with optimization
      if (refresh || cachedAttachments.isEmpty) {
        onProgress?.call(0.4);
        
        final emailService = UnifiedEmailService();
        
        // OPTIMIZATION: Use smaller limits for faster loading
        // When refresh=true, use limited query for speed
        final attachments = await emailService.fetchAllAttachments(
          accountId: accountId,
          maxEmails: refresh ? 5 : 10, // Use smaller batch for manual refresh
          maxAttachments: refresh ? 15 : 30, // Fewer attachments for faster response
        );
        
        onProgress?.call(0.7);
        
        // Merge with cache to maintain a complete dataset
        List<EmailAttachment> mergedAttachments;
        if (cachedAttachments.isNotEmpty) {
          mergedAttachments = _efficientMergeAttachments(cachedAttachments, attachments);
        } else {
          mergedAttachments = attachments;
        }
        
        onProgress?.call(0.8);
        
        // Save to cache
        await _cacheAttachments(mergedAttachments);
        
        // Update timestamp
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          'last_attachment_refresh',
          DateTime.now().millisecondsSinceEpoch,
        );
        
        // If this was a limited refresh, trigger a full background refresh
        if (refresh && mergedAttachments.isNotEmpty) {
          _completeRefreshInBackground(accountId);
        }
        
        // Apply filters and return
        final filteredAttachments = _filterAttachments(
          mergedAttachments,
          accountId: accountId,
          fileType: fileType,
        );
        
        onProgress?.call(1.0);
        return _getPaginatedResults(filteredAttachments, page, pageSize);
      }
      
      // Fallback - should never reach here
      onProgress?.call(1.0);
      return _getPaginatedResults(filteredCachedAttachments, page, pageSize);
    } catch (e) {
      print('Error fetching attachments: $e');
      // Return cached data on error
      final cachedAttachments = await _loadCachedAttachments();
      final filteredCachedAttachments = _filterAttachments(
        cachedAttachments,
        accountId: accountId, 
        fileType: fileType,
      );
      return _getPaginatedResults(filteredCachedAttachments, page, pageSize);
    }
  }

  // More efficient merging that prioritizes speed
  List<EmailAttachment> _efficientMergeAttachments(
    List<EmailAttachment> existing,
    List<EmailAttachment> fresh,
  ) {
    // Create a map using a fast lookup key
    final Map<String, EmailAttachment> mergedMap = {};
    
    // Add all existing attachments
    for (var attachment in existing) {
      final key = '${attachment.emailId}:${attachment.id}';
      mergedMap[key] = attachment;
    }
    
    // Add or update with fresh attachments
    for (var attachment in fresh) {
      final key = '${attachment.emailId}:${attachment.id}';
      mergedMap[key] = attachment;
    }
    
    // Convert back to list - sorted by date
    return mergedMap.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // New background method for full refresh
  Future<void> _completeRefreshInBackground(String? accountId) async {
    // Wait 5 seconds to let UI become responsive first
    await Future.delayed(const Duration(seconds: 5));
    
    try {
      final emailService = UnifiedEmailService();
      print('Starting complete background refresh');
      
      // Full refresh with larger limits
      final attachments = await emailService.fetchAllAttachments(
        accountId: accountId,
        maxEmails: 20,       // Larger batch for background
        maxAttachments: 60,  // More attachments for completeness
      );
      
      if (attachments.isNotEmpty) {
        final existingAttachments = await _loadCachedAttachments();
        final mergedAttachments = _mergeAttachments(
          existingAttachments, 
          attachments,
        );
        
        await _cacheAttachments(mergedAttachments);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          'last_attachment_refresh',
          DateTime.now().millisecondsSinceEpoch,
        );
        
        // Notify UI of refresh completion
        eventBus.fire(AttachmentsRefreshedEvent());
      }
    } catch (e) {
      print('Error in complete background refresh: $e');
    }
  }

  // Add a method to check if cache is stale
  Future<bool> _isCacheStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRefresh = prefs.getInt('last_attachment_refresh') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Cache is stale if it's more than 30 minutes old
      return (now - lastRefresh) > (30 * 60 * 1000);
    } catch (e) {
      print('Error checking cache freshness: $e');
      return true; // Consider cache stale if there's an error
    }
  }

  // Add a method to check if cache is very stale
  Future<bool> _isCacheVeryStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRefresh = prefs.getInt('last_attachment_refresh') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Cache is very stale if it's more than 2 hours old
      return (now - lastRefresh) > (2 * 60 * 60 * 1000);
    } catch (e) {
      print('Error checking cache freshness: $e');
      return true; // Consider cache very stale if there's an error
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
      // Account filter (only when not in unified inbox)
      if (accountId != null && accountId.isNotEmpty) {
        if (attachment.accountId != accountId) return false;
      }

      // File type filter
      if (fileType != null && fileType.isNotEmpty && fileType != 'All') {
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
          case 'others':
            // All files that don't match the above types
            matches =
                !attachment.contentType.contains('image') &&
                !attachment.contentType.contains('pdf') &&
                !attachment.contentType.contains('doc') &&
                !attachment.contentType.contains('text') &&
                !attachment.contentType.contains('excel') &&
                !attachment.contentType.contains('sheet');
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

  // Update the background refresh method

  Future<void> _refreshAttachmentsInBackground({String? accountId}) async {
    try {
      // Add throttling to prevent too many requests
      await _throttleApiRequests();

      final emailService = UnifiedEmailService();
      print('Starting background attachment refresh');

      // Use the parameters correctly here
      final attachments = await emailService.fetchAllAttachments(
        accountId: accountId,
        maxEmails: 10, // Use the named parameter correctly
        maxAttachments: 30, // Use the named parameter correctly
      );
      print('Background fetch complete with ${attachments.length} attachments');

      // Rest of the method remains the same...
      if (attachments.isNotEmpty) {
        final existingAttachments = await _loadCachedAttachments();
        final mergedAttachments = _mergeAttachments(
          existingAttachments,
          attachments,
        );
        await _cacheAttachments(mergedAttachments);

        // Update last refresh timestamp
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          'last_attachment_refresh',
          DateTime.now().millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      print('Error in background refresh: $e');
    }
  }

  // Merge new attachments with existing ones (avoid duplicates)
  List<EmailAttachment> _mergeAttachments(
    List<EmailAttachment> existing,
    List<EmailAttachment> fresh,
  ) {
    // Create a map to identify duplicates by content characteristics
    final Map<String, EmailAttachment> mergedAttachments = {};

    // Helper function to create a content-based key
    String getContentKey(EmailAttachment attachment) {
      // Create a normalized filename by removing any path info and converting to lowercase
      final normalizedName = attachment.name.split('/').last.toLowerCase();

      // Create a key based on name, size and type (all content-focused attributes)
      return '$normalizedName|${attachment.size}|${attachment.contentType}';
    }

    // First, add all existing attachments using content-based key
    for (var attachment in existing) {
      final contentKey = getContentKey(attachment);
      mergedAttachments[contentKey] = attachment;
    }

    // Then process fresh attachments
    for (var attachment in fresh) {
      final contentKey = getContentKey(attachment);

      if (!mergedAttachments.containsKey(contentKey)) {
        // This is a new unique attachment
        mergedAttachments[contentKey] = attachment;
      } else {
        // This is likely a duplicate - keep the newest one
        final existingAttachment = mergedAttachments[contentKey]!;

        // Keep the newer one
        if (attachment.date.isAfter(existingAttachment.date)) {
          mergedAttachments[contentKey] = attachment;
        }
      }
    }

    // Convert back to list and sort by date (newest first)
    return mergedAttachments.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
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

  // Get paginated results
  List<EmailAttachment> _getPaginatedResults(
    List<EmailAttachment> attachments,
    int page,
    int pageSize,
  ) {
    final startIndex = page * pageSize;
    if (startIndex >= attachments.length) {
      return []; // No more items for this page
    }

    final endIndex =
        (startIndex + pageSize) > attachments.length
            ? attachments.length
            : (startIndex + pageSize);

    return attachments.sublist(startIndex, endIndex);
  }
}
