import 'package:flutter/material.dart';
import 'package:mail_merge/features/attachments_hub/models/attachment.dart';
import 'package:mail_merge/features/attachments_hub/services/attachment_service.dart';
import 'package:mail_merge/features/attachments_hub/widgets/attachment_item.dart';
import 'package:mail_merge/features/email/widgets/email_shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mail_merge/core/services/event_bus.dart';
import 'dart:async';

class Attachmentsscreen extends StatefulWidget {
  final String? accountId;

  const Attachmentsscreen({super.key, this.accountId});

  @override
  State<Attachmentsscreen> createState() => _AttachmentsscreenState();
}

class _AttachmentsscreenState extends State<Attachmentsscreen>
    with AutomaticKeepAliveClientMixin {
  List<EmailAttachment> _attachments = [];
  bool _isLoading = true;
  bool _loadingFromCache = false;
  String? _currentAccountId;
  StreamSubscription? _accountSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentAccountId = widget.accountId;
    _loadCachedAttachments();
    _loadAttachments();

    // Listen for account removal events
    _accountSubscription = eventBus.on<AccountRemovedEvent>().listen((_) {
      if (mounted) {
        _loadAttachments(refresh: true);
      }
    });
  }

  @override
  void didUpdateWidget(Attachmentsscreen oldWidget) {
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
    super.dispose();
  }

  // Load cached attachments for immediate display
  Future<void> _loadCachedAttachments() async {
    try {
      _loadingFromCache = true;
      // Fix: Use the public method instead of the private one
      final attachments = await AttachmentService.getCachedAttachments();

      if (attachments.isNotEmpty) {
        // Filter by account if needed
        final filteredAttachments =
            widget.accountId != null && widget.accountId!.isNotEmpty
                ? attachments
                    .where((a) => a.accountId == widget.accountId)
                    .toList()
                : attachments;

        if (mounted) {
          setState(() {
            _attachments = filteredAttachments;
          });
        }
      }

      _loadingFromCache = false;
    } catch (e) {
      print('Error loading cached attachments: $e');
      _loadingFromCache = false;
    }
  }

  // Load attachments from the server
  Future<void> _loadAttachments({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final attachments = await AttachmentService.fetchAllAttachments(
        accountId: widget.accountId,
      );

      if (mounted) {
        setState(() {
          _attachments = attachments;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading attachments: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Show shimmer loading effect when first loading with no cached data
    if (_isLoading && _attachments.isEmpty && !_loadingFromCache) {
      return const EmailShimmerList();
    }

    // Main content with pull-to-refresh
    return RefreshIndicator(
      onRefresh: () => _loadAttachments(refresh: true),
      child:
          _attachments.isEmpty ? _buildEmptyState() : _buildAttachmentsList(),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(), // Enable scrolling on empty list
      children: [
        SizedBox(height: MediaQuery.of(context).size.height / 4),
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
        const SizedBox(height: 8),
        const Text(
          'Pull down to refresh',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildAttachmentsList() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _attachments.length,
      itemBuilder: (context, index) {
        final attachment = _attachments[index];
        return AttachmentItem(attachment: attachment);
      },
    );
  }
}
