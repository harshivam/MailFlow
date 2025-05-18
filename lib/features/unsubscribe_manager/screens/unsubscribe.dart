import 'package:flutter/material.dart';
import 'package:mail_merge/features/unsubscribe_manager/models/subscription_email.dart';
import 'package:mail_merge/features/unsubscribe_manager/services/unsubscribe_service.dart';
import 'package:mail_merge/features/unsubscribe_manager/widgets/subscription_item.dart';
import 'package:mail_merge/features/unsubscribe_manager/widgets/subscription_shimmer.dart';
import 'package:mail_merge/core/services/event_bus.dart';
import 'dart:async';

class UnsubscribeScreen extends StatefulWidget {
  final String? accountId;

  const UnsubscribeScreen({super.key, this.accountId});

  @override
  _UnsubscribeScreenState createState() => _UnsubscribeScreenState();
}

class _UnsubscribeScreenState extends State<UnsubscribeScreen>
    with AutomaticKeepAliveClientMixin {
  final UnsubscribeService _unsubscribeService = UnsubscribeService();
  List<SubscriptionEmail> _subscriptions = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _allSelected = false;
  bool _isBatchUnsubscribing = false;
  double _loadingProgress = 0.0;

  // Keep track of account ID for filtering
  String? _currentAccountId;

  // Stream subscriptions
  StreamSubscription? _unsubscribeEventSubscription;
  StreamSubscription? _toastSubscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentAccountId = widget.accountId;
    _loadSubscriptions();

    // Listen for unsubscribe completion events
    _unsubscribeEventSubscription = eventBus
        .on<UnsubscribeCompletedEvent>()
        .listen((event) {
          if (mounted) {
            _handleUnsubscribeCompleted(event.emailId, event.success);
          }
        });

    // Listen for toast events
    _toastSubscription = eventBus.on<ShowToastEvent>().listen((event) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(event.message)));
      }
    });
  }

  @override
  void didUpdateWidget(UnsubscribeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.accountId != _currentAccountId) {
      _currentAccountId = widget.accountId;
      _loadSubscriptions();
    }
  }

  @override
  void dispose() {
    _unsubscribeEventSubscription?.cancel();
    _toastSubscription?.cancel();
    super.dispose();
  }

  // Load subscriptions from API or cache
  Future<void> _loadSubscriptions({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final subscriptions = await _unsubscribeService.fetchSubscriptions(
        accountId: _currentAccountId,
        refresh: refresh,
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
          // Option 1: Keep all subscriptions but show the unsubscribed ones at the bottom
          subscriptions.sort((a, b) {
            if (a.unsubscribeSuccess && !b.unsubscribeSuccess) return 1;
            if (!a.unsubscribeSuccess && b.unsubscribeSuccess) return -1;
            return b.date.compareTo(a.date); // Sort by date for same status
          });
          _subscriptions = subscriptions;

          // Option 2 (alternative): Filter out unsubscribed items
          // _subscriptions = subscriptions.where((sub) => !sub.unsubscribeSuccess).toList();

          _isLoading = false;
          _isRefreshing = false;
          _allSelected = false;
        });
      }
    } catch (e) {
      print('Error loading subscriptions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });

        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load subscription emails'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Toggle selection for a single subscription
  void _toggleSelection(SubscriptionEmail subscription) {
    final index = _subscriptions.indexWhere((s) => s.id == subscription.id);

    if (index >= 0) {
      setState(() {
        _subscriptions[index] = _subscriptions[index].copyWith(
          isSelected: !_subscriptions[index].isSelected,
        );

        // Check if all are selected
        _updateAllSelectedState();
      });
    }
  }

  // Toggle all selections
  void _toggleSelectAll() {
    final newValue = !_allSelected;

    setState(() {
      _allSelected = newValue;

      // Update all subscription items
      _subscriptions =
          _subscriptions.map((subscription) {
            // Only allow selection of items that can be unsubscribed
            if (!subscription.unsubscribeSuccess) {
              return subscription.copyWith(isSelected: newValue);
            }
            return subscription;
          }).toList();
    });
  }

  // Update the all selected state based on individual selections
  void _updateAllSelectedState() {
    final selectableCount =
        _subscriptions.where((s) => !s.unsubscribeSuccess).length;

    final selectedCount =
        _subscriptions
            .where((s) => s.isSelected && !s.unsubscribeSuccess)
            .length;

    setState(() {
      _allSelected = selectableCount > 0 && selectableCount == selectedCount;
    });
  }

  // Handle a single unsubscribe
  Future<void> _unsubscribe(SubscriptionEmail subscription) async {
    // Update the UI state first for responsiveness
    final index = _subscriptions.indexWhere((s) => s.id == subscription.id);

    if (index >= 0) {
      setState(() {
        _subscriptions[index] = _subscriptions[index].copyWith(
          isUnsubscribing: true,
        );
      });

      try {
        // Perform the unsubscribe operation
        final success = await _unsubscribeService.unsubscribe(subscription);

        // Update is handled by event listener
      } catch (e) {
        print('Error unsubscribing: $e');

        // Reset the UI state
        if (mounted) {
          setState(() {
            _subscriptions[index] = _subscriptions[index].copyWith(
              isUnsubscribing: false,
            );
          });

          // Show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to unsubscribe from ${subscription.sender}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Batch unsubscribe selected items
  Future<void> _batchUnsubscribe() async {
    final selectedSubscriptions =
        _subscriptions
            .where(
              (s) =>
                  s.isSelected && !s.unsubscribeSuccess && !s.isUnsubscribing,
            )
            .toList();

    if (selectedSubscriptions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No subscriptions selected')));
      return;
    }

    // Update UI to show processing state
    setState(() {
      _isBatchUnsubscribing = true;

      // Update individual items
      for (var i = 0; i < _subscriptions.length; i++) {
        if (_subscriptions[i].isSelected &&
            !_subscriptions[i].unsubscribeSuccess &&
            !_subscriptions[i].isUnsubscribing) {
          _subscriptions[i] = _subscriptions[i].copyWith(isUnsubscribing: true);
        }
      }
    });

    try {
      // Perform the batch unsubscribe
      await _unsubscribeService.batchUnsubscribe(selectedSubscriptions);

      // Individual updates are handled by the event listener

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unsubscribed from ${selectedSubscriptions.length} ${selectedSubscriptions.length == 1 ? 'subscription' : 'subscriptions'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error in batch unsubscribe: $e');

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unsubscribing from selected subscriptions'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBatchUnsubscribing = false;
        });
      }
    }
  }

  // Handle unsubscribe completion event
  void _handleUnsubscribeCompleted(String emailId, bool success) {
    final index = _subscriptions.indexWhere((s) => s.id == emailId);

    if (index >= 0 && mounted) {
      setState(() {
        _subscriptions[index] = _subscriptions[index].copyWith(
          isUnsubscribing: false,
          unsubscribeSuccess: success,
          isSelected: false, // Deselect after unsubscribe
        );

        // Update all selected state
        _updateAllSelectedState();
      });
    }
  }

  // Clear cache and refresh
  Future<void> _clearCache() async {
    await _unsubscribeService.clearCache();
    _loadSubscriptions(refresh: true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cache cleared, refreshing subscriptions')),
    );
  }

  // Add this method to your UnsubscribeScreen class
  Widget _buildInfoBanner() {
    return Container(
      margin: EdgeInsets.symmetric( vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'About Unsubscribe Manager',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'This tool helps you unsubscribe from email newsletters and marketing communications. '
            'When you click "Unsubscribe", we\'ll guide you through the process and track your progress.',
            style: TextStyle(fontSize: 12),
          ),
          SizedBox(height: 8),
          Text(
            'Note: Some unsubscribe processes may require multiple steps or confirmation emails.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Unsubscribe Manager'),
        actions: [
          // Refresh button
          IconButton(
            icon:
                _isRefreshing
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : Icon(Icons.refresh),
            onPressed:
                _isRefreshing ? null : () => _loadSubscriptions(refresh: true),
            tooltip: 'Refresh',
          ),

          // Clear cache button
          IconButton(
            icon: Icon(Icons.cleaning_services),
            onPressed: _isLoading || _isRefreshing ? null : _clearCache,
            tooltip: 'Clear cache',
          ),
        ],
      ),
      body: _buildContent(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildContent() {
    if (_isLoading && !_isRefreshing) {
      return Column(
        children: [
          _buildStatusHeader(),
          Expanded(child: SubscriptionShimmerList()),
        ],
      );
    }

    return Column(
      children: [
        // Header with select all
        _buildStatusHeader(),
        // List of subscriptions
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadSubscriptions(refresh: true),
            child:
                _subscriptions.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount:
                          _subscriptions.length + 1, // +1 for the info banner
                      itemBuilder: (context, index) {
                        // Show info banner at the top of the list
                        if (index == 0) {
                          return _buildInfoBanner();
                        }

                        // Adjust index to account for the banner
                        final subscriptionIndex = index - 1;
                        return SubscriptionItem(
                          subscription: _subscriptions[subscriptionIndex],
                          onToggleSelect: _toggleSelection,
                          onUnsubscribe: _unsubscribe,
                        );
                      },
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusHeader() {
    // Progress indicator for loading/refreshing
    Widget progressIndicator =
        _isRefreshing
            ? LinearProgressIndicator(
              value: _loadingProgress > 0 ? _loadingProgress : null,
              backgroundColor: Colors.transparent,
            )
            : SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        progressIndicator,

        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Select all checkbox
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _allSelected,
                  onChanged: (_) => _toggleSelectAll(),
                ),
              ),
              SizedBox(width: 8),

              // Select all text
              Text(
                'Select All',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),

              Spacer(),

              // Count of subscriptions
              Text(
                '${_subscriptions.length} subscriptions',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),

        Divider(height: 1),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildInfoBanner(),
        SizedBox(height: 100), // Space between banner and empty state content
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mark_email_read, size: 80, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'No subscription emails found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Pull down to refresh and find subscriptions',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    // Count selected items
    final selectedCount =
        _subscriptions
            .where((s) => s.isSelected && !s.unsubscribeSuccess)
            .length;

    if (selectedCount == 0) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Text(
              '$selectedCount selected',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),

            Spacer(),

            // Unsubscribe selected button
            ElevatedButton(
              onPressed: _isBatchUnsubscribing ? null : _batchUnsubscribe,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:
                  _isBatchUnsubscribing
                      ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Text('Unsubscribe Selected'),
            ),
          ],
        ),
      ),
    );
  }
}
