import 'package:flutter/material.dart';
import 'package:mail_merge/features/attachments_hub/models/attachment.dart';
import 'package:mail_merge/features/attachments_hub/services/attachment_service.dart';
import 'package:mail_merge/features/attachments_hub/widgets/attachment_item.dart';
import 'package:mail_merge/features/email/widgets/email_shimmer.dart';
import 'package:mail_merge/core/services/event_bus.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AttachmentsScreen extends StatefulWidget {
  final String? accountId;

  const AttachmentsScreen({Key? key, this.accountId}) : super(key: key);

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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentAccountId = widget.accountId;
    _loadAttachments();

    // Listen for account removal events
    _accountSubscription = eventBus.on<AccountRemovedEvent>().listen((_) {
      if (mounted) {
        _loadAttachments(refresh: true);
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
      _loadAttachments(refresh: true);
    }
  }

  @override
  void dispose() {
    _accountSubscription?.cancel();
    _refreshSubscription?.cancel();
    super.dispose();
  }

  // Load attachments with filtering options
  Future<void> _loadAttachments({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
        _isRateLimited = false; // Reset rate limit flag on manual refresh
      });
    } else if (_isLoading == false) {
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

      // Load attachments with progress updates
      try {
        final attachments = await _attachmentService.fetchAllAttachments(
          accountId: widget.accountId,
          fileType: fileType,
          refresh: refresh,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress;
              });
            }
          },
        );

        print('DEBUG: Got ${attachments.length} attachments');
        if (attachments.isNotEmpty) {
          print(
            'DEBUG: First attachment: ${attachments.first.name}, from ${attachments.first.senderName}',
          );
        }

        if (mounted) {
          setState(() {
            _attachments = attachments;
            _isLoading = false;
            _isRefreshing = false;
            _isRateLimited = false;
          });
        }
      } catch (e) {
        if (e.toString().contains('429')) {
          setState(() {
            _isRateLimited = true;
            _isLoading = false;
            _isRefreshing = false;
          });
        } else {
          rethrow;
        }
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

  // Add a method to clear attachment cache near the bottom of the _AttachmentsScreenState class
  Future<void> _clearAttachmentCache() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Clear cached data in preferences
      await _attachmentService.clearCache();

      // Delete all files in temp directory
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final files = tempDir.listSync();
        for (var file in files) {
          if (file is File) {
            await file.delete();
            print('Deleted cached file: ${file.path}');
          }
        }
      }

      // Reload attachments
      await _loadAttachments(refresh: true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared successfully')),
      );
    } catch (e) {
      print('Error clearing cache: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error clearing cache: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    // Show shimmer loading effect when first loading
    if (_isLoading && _attachments.isEmpty) {
      return const EmailShimmerList();
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
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        // Increase this value to make cards taller
        childAspectRatio: 0.68, // Changed from 0.75 to make items taller
      ),
      itemCount: _attachments.length,
      itemBuilder: (context, index) {
        final attachment = _attachments[index];
        return AttachmentItem(
          attachment: attachment,
          onViewDetails: (attachment) {
            print('View details for ${attachment.name}');
          },
        );
      },
    );
  }
}
