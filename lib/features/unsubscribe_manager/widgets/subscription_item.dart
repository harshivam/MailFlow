import 'package:flutter/material.dart';
import 'package:mail_merge/features/unsubscribe_manager/models/subscription_email.dart';
import 'package:mail_merge/utils/date_formatter.dart';

class SubscriptionItem extends StatelessWidget {
  final SubscriptionEmail subscription;
  final Function(SubscriptionEmail) onToggleSelect;
  final Function(SubscriptionEmail) onUnsubscribe;

  const SubscriptionItem({
    super.key,
    required this.subscription,
    required this.onToggleSelect,
    required this.onUnsubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Create status color based on subscription state
    Color statusColor = Colors.blue;
    String statusText = 'Unsubscribe';
    bool canUnsubscribe = true;

    if (subscription.isUnsubscribing) {
      statusColor = Colors.orange;
      statusText = 'Processing...';
      canUnsubscribe = false;
    } else if (subscription.unsubscribeSuccess) {
      statusColor = Colors.green;
      // Fix this misleading text
      statusText = 'Marked Done'; // Changed from 'Unsubscribed*'
      canUnsubscribe = false;
    }

    String statusDetail = '';
    if (subscription.unsubscribeSuccess) {
      statusDetail = 'Processed in app'; // Clearer explanation
    }

    // Determine provider directly based on accountId
    final String providerName = _determineProvider(subscription.accountId);

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side:
            subscription.isSelected
                ? BorderSide(color: Colors.grey[700]!, width: 2)
                : BorderSide(color: Colors.grey[300]!, width: 0.5),
      ),
      child: InkWell(
        onTap: () => onToggleSelect(subscription),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with checkbox, sender and date
              Row(
                children: [
                  // Selection checkbox
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: subscription.isSelected,
                      onChanged: (_) => onToggleSelect(subscription),
                      activeColor: Colors.grey[700],
                    ),
                  ),
                  SizedBox(width: 8),

                  // Sender info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscription.sender,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subscription.senderEmail,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Date
                  Text(
                    DateFormatter.formatRelativeDate(subscription.date),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),

              // Divider
              Divider(height: 16),

              // Subject
              Text(
                subscription.subject,
                style: TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              SizedBox(height: 8),

              // Account info and unsubscribe button
              Row(
                children: [
                  // Account badge - EXACT MATCH TO HOME INBOX
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getProviderColor(providerName).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${subscription.accountName} ($providerName)',
                      style: TextStyle(
                        fontSize: 10,
                        color: _getProviderColor(providerName),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  Spacer(),

                  // Unsubscribe button
                  ElevatedButton(
                    onPressed:
                        canUnsubscribe
                            ? () {
                              // Show immediate visual feedback in the UI
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Processing unsubscribe request...',
                                  ),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                              onUnsubscribe(subscription);
                            }
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor,
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size(100, 30),
                      elevation: 0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        subscription.isUnsubscribing
                            ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : Text(
                              statusText,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                        if (statusDetail.isNotEmpty)
                          Text(
                            statusDetail,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to determine provider from accountId
  String _determineProvider(String accountId) {
    // For testing, hardcode a few known account IDs
    // In production, we would need a reliable way to map accountId to provider
    if (accountId.contains('gmail') || accountId.contains('google')) {
      return 'Gmail';
    } else if (accountId.contains('outlook') ||
        accountId.contains('microsoft')) {
      return 'Outlook';
    } else if (accountId.contains('yahoo')) {
      return 'Yahoo';
    } else {
      return 'Gmail'; // Default to Gmail for visibility
    }
  }

  // COPIED DIRECTLY from EmailItem to ensure exact same behavior
  Color _getProviderColor(String provider) {
    switch (provider.toLowerCase()) {
      case 'gmail':
        return Colors.red;
      case 'outlook':
        return Colors.blue;
      case 'yahoo':
        return Colors
            .grey[700]!; // Changed from purple to grey to match your preference
      default:
        return Colors.grey[700]!;
    }
  }
}
