import 'package:flutter/material.dart';
import 'package:mail_merge/features/attachments_hub/models/attachment.dart';
import 'package:mail_merge/features/attachments_hub/services/attachment_service.dart';
import 'package:mail_merge/features/attachments_hub/widgets/attachment_grid.dart';
import 'package:mail_merge/features/attachments_hub/widgets/attachment_item.dart';
import 'package:mail_merge/features/attachments_hub/widgets/attachment_shimmer.dart';
import 'package:mail_merge/core/services/event_bus.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class AttachmentsScreen extends StatefulWidget {
  final String? accountId;

  const AttachmentsScreen({super.key, this.accountId});

  @override
  State<AttachmentsScreen> createState() => _AttachmentsScreenState();
}

class _AttachmentsScreenState extends State<AttachmentsScreen>
    with AutomaticKeepAliveClientMixin {
  final AttachmentService _attachmentService = AttachmentService();
  List<EmailAttachment> _attachments = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _currentAccountId;
  StreamSubscription? _accountSubscription;
  StreamSubscription? _refreshSubscription;

  // Filtering options
  String? _selectedFileType;
  final List<String> _fileTypes = [
    'All',
    'Images',
    'Documents',
    'Spreadsheets',
    'Others',
  ];
  double _loadingProgress = 0.0;
  bool _isRateLimited = false;

  // Pagination variables
  int _currentPage = 0;
  bool _hasMoreAttachments = true;
  bool _isLoadingMore = false;

  // Add a boolean flag for unified inbox
  bool _isUnifiedInbox = true; // Default to true

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentAccountId = widget.accountId;
    _isUnifiedInbox = widget.accountId == null;

    // OPTIMIZATION: Use a two-phase loading strategy
    _loadAttachmentsOptimized();

    // Determine unified inbox status at initialization
    _isUnifiedInbox = widget.accountId == null;

    // Add this check to force refresh on FIRST load only
    _checkFirstLoad();

    // Listen for account removal events
    _accountSubscription = eventBus.on<AccountRemovedEvent>().listen((_) {
      if (mounted) {
        _loadAttachments(refresh: true);
      }
    });

    // Listen for unified inbox toggle events
    eventBus.on<UnifiedInboxToggleEvent>().listen((event) {
      if (mounted) {
        setState(() {
          _isUnifiedInbox = event.isEnabled;
          // Reload attachments without API calls by filtering the cache
          _loadAttachments(refresh: false);
        });
      }
    });

    // Listen for attachment refresh events
    _refreshSubscription = eventBus.on<AttachmentsRefreshedEvent>().listen((_) {
      if (mounted) {
        _loadAttachments();
      }
    });
  }

  @override
  void didUpdateWidget(AttachmentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If account ID changed, refresh attachments
    if (widget.accountId != _currentAccountId) {
      print(
        'DEBUG: AttachmentsScreen account ID changed from $_currentAccountId to ${widget.accountId}',
      );
      _currentAccountId = widget.accountId;

      // Update unified inbox flag
      _isUnifiedInbox = widget.accountId == null;

      // Reload attachments (preferably from cache)
      _loadAttachments(refresh: false);
    }
  }

  @override
  void dispose() {
    _accountSubscription?.cancel();
    _refreshSubscription?.cancel();
    super.dispose();
  }

  // Load attachments with filtering options
  Future<void> _loadAttachments({
    bool refresh = false,
    bool loadMore = false,
  }) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
        _isRateLimited = false;
        _currentPage = 0; // Reset to first page
        _hasMoreAttachments = true; // Reset flag
      });
    } else if (loadMore) {
      if (_isLoadingMore || !_hasMoreAttachments) return;

      setState(() {
        _isLoadingMore = true;
      });

      _currentPage++; // Move to next page
    } else {
      // Regular loading
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Filter by type if selected
      String? fileType;
      if (_selectedFileType != null && _selectedFileType != 'All') {
        fileType = _selectedFileType;
      }

      // Load attachments with pagination
      final attachments = await _attachmentService.fetchAllAttachments(
        accountId: widget.accountId,
        fileType: fileType,
        refresh: refresh,
        page: _currentPage,
        pageSize: 6,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _loadingProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          // For first page or refresh, replace all attachments
          if (_currentPage == 0 || refresh) {
            _attachments = attachments;
          } else {
            // For subsequent pages, add to existing attachments
            _attachments.addAll(attachments);
          }

          // If we got fewer than 6 items, there are no more
          _hasMoreAttachments = attachments.length >= 6;

          _isLoading = false;
          _isRefreshing = false;
          _isLoadingMore = false;
          _isRateLimited = false;
        });
      }
    } catch (e) {
      print('Error loading attachments: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  // New optimized loading method
  Future<void> _loadAttachmentsOptimized() async {
    // Phase 1: Super fast loading from cache
    setState(() {
      _isLoading = true;
      _loadingProgress = 0.1;
    });

    try {
      // Get cached data as quickly as possible
      final cachedAttachments = await _attachmentService.getCachedAttachments();

      if (cachedAttachments.isNotEmpty) {
        setState(() {
          _attachments = _filterAttachments(cachedAttachments);
          _loadingProgress = 0.5;
        });
      }

      // Phase 2: Refresh data only if needed
      final prefs = await SharedPreferences.getInstance();
      final hasLoadedBefore =
          prefs.getBool('attachments_loaded_before') ?? false;

      if (!hasLoadedBefore) {
        // First time opening, do a refresh
        await prefs.setBool('attachments_loaded_before', true);
        _loadAttachments(refresh: true);
      } else {
        // Not first time, check if refresh needed
        final lastRefresh = prefs.getInt('last_attachment_refresh') ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        final refreshNeeded =
            (now - lastRefresh) > (30 * 60 * 1000); // 30 minutes

        if (refreshNeeded) {
          _loadAttachments(refresh: false);
        } else {
          setState(() {
            _isLoading = false;
            _loadingProgress = 1.0;
          });
        }
      }
    } catch (e) {
      print('Error in optimized loading: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper to filter attachments locally (very fast)
  List<EmailAttachment> _filterAttachments(List<EmailAttachment> attachments) {
    if (_currentAccountId != null && _currentAccountId!.isNotEmpty) {
      attachments =
          attachments.where((a) => a.accountId == _currentAccountId).toList();
    }

    if (_selectedFileType != null && _selectedFileType != 'All') {
      // Apply file type filter
      attachments =
          attachments.where((a) {
            switch (_selectedFileType) {
              case 'Images':
                return a.contentType.contains('image');
              case 'Documents':
                return a.contentType.contains('pdf') ||
                    a.contentType.contains('doc') ||
                    a.contentType.contains('text');
              // Other cases...
              default:
                return true;
            }
          }).toList();
    }

    return attachments;
  }

  // Load attachments with filtering options

  // Add a method to clear attachment cache near the bottom of the _AttachmentsScreenState class
  Future<void> _clearAttachmentCache() async {
    try {
      // Show loading indicator
      setState(() {
        _isLoading = true;
        _attachments = []; // Empty the list to make the shimmer visible
      });

      // Clear cached data in preferences
      await _attachmentService.clearCache();

      // Delete all downloaded attachment files in temp directory
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final files = tempDir.listSync();
        for (var file in files) {
          if (file is File) {
            try {
              await file.delete();
              print('Deleted cached file: ${file.path}');
            } catch (e) {
              print('Error deleting file ${file.path}: $e');
            }
          }
        }
      }

      // IMPORTANT CHANGE: Set _isLoading to false instead of calling _loadAttachments(refresh: true)
      setState(() {
        _isLoading = false;
        // Keep attachments empty to show the empty state
      });

      // Show a snackbar with a refresh button to let the user decide when to reload
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cache cleared successfully'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'REFRESH',
            onPressed:
                () => _loadAttachments(
                  refresh: true,
                ), // Only refresh when explicitly requested
          ),
        ),
      );
    } catch (e) {
      print('Error clearing cache: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing cache: ${e.toString()}')),
      );

      // Make sure to set loading to false even on error
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Add this new method to track first load
  Future<void> _checkFirstLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final hasLoadedBefore = prefs.getBool('attachments_loaded_before') ?? false;

    if (!hasLoadedBefore) {
      // First time opening the attachment hub, force API fetch
      _loadAttachments(refresh: true);

      // Mark as loaded for future opens
      await prefs.setBool('attachments_loaded_before', true);
    } else {
      // Normal load for subsequent opens
      _loadAttachments();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attachments'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear_cache') {
                _clearAttachmentCache();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'clear_cache',
                    child: ListTile(
                      leading: Icon(Icons.cleaning_services),
                      title: Text('Clear cache'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () => _loadAttachments(refresh: true),
              tooltip: 'Force refresh',
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter options
          _buildFilterBar(),

          // Loading progress indicator
          if (_isLoading && _loadingProgress > 0 && _loadingProgress < 1)
            LinearProgressIndicator(value: _loadingProgress),

          // Main content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  // Build the filter bar
  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children:
            _fileTypes.map((type) {
              final isSelected =
                  _selectedFileType == type ||
                  (_selectedFileType == null && type == 'All');

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedFileType = type == 'All' ? null : type;
                      _loadAttachments(refresh: false);
                    });
                  },
                  backgroundColor: Colors.grey[200],
                  selectedColor: Colors.blue[100],
                ),
              );
            }).toList(),
      ),
    );
  }

  // Build the main content
  Widget _buildContent() {
    // Show shimmer loading effect when loading and either:
    // 1. Attachments are empty, or
    // 2. We're refreshing (pull refresh, force refresh, or cache clear)
    if (_isLoading && (_attachments.isEmpty || _isRefreshing)) {
      return const AttachmentShimmerGrid();
    }

    // Main content with pull-to-refresh
    return RefreshIndicator(
      onRefresh: () => _loadAttachments(refresh: true),
      child:
          _attachments.isEmpty ? _buildEmptyState() : _buildAttachmentsList(),
    );
  }

  // Empty state with illustration
  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height / 4),
        if (_isRateLimited) ...[
          const Icon(Icons.hourglass_empty, size: 80, color: Colors.amber),
          const SizedBox(height: 16),
          const Text(
            'API Rate Limit Reached',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please try again after a few minutes',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ] else ...[
          const Icon(Icons.attach_file, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No attachments found',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Attachments from your emails will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'Pull down to refresh',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  // Grid of attachment items
  Widget _buildAttachmentsList() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AttachmentGrid(
                attachments: _attachments,
                crossAxisCount: 2,

                onAttachmentTap: (attachment) {
                  print('View details for ${attachment.name}');
                  // Your existing attachment tap logic
                },
              ),
            ],
          ),
        ),
        if (_hasMoreAttachments)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child:
                _isLoadingMore
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                      onPressed: () => _loadAttachments(loadMore: true),
                      child: const Text('Show More'),
                    ),
          ),
      ],
    );
  }
}
