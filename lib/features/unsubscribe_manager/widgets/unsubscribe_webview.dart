import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:mail_merge/features/unsubscribe_manager/models/subscription_email.dart';
import 'package:mail_merge/core/services/event_bus.dart';

class UnsubscribeWebView extends StatefulWidget {
  final SubscriptionEmail subscription;
  final bool closeOnSuccess;

  const UnsubscribeWebView({
    super.key,
    required this.subscription,
    this.closeOnSuccess = true,
  });

  @override
  State<UnsubscribeWebView> createState() => _UnsubscribeWebViewState();
}

class _UnsubscribeWebViewState extends State<UnsubscribeWebView> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _unsubscribeDetected = false;
  String _currentUrl = '';

  // Success indicator text patterns
  final List<String> _successPatterns = [
    'successfully unsubscribed',
    'you are unsubscribed',
    'unsubscribe successful',
    'has been unsubscribed',
    'unsubscribe confirmed',
    'email removed',
    'you have been removed',
    'preferences updated',
    'subscription canceled',
    'subscription cancelled',
    'thank you for unsubscribing',
  ];

  // Success indicator URL patterns
  final List<String> _successUrlPatterns = [
    'success',
    'confirmed',
    'thank-you',
    'thankyou',
    'confirmation-complete',
    // Remove 'unsubscribe' and 'preferences' - too generic
  ];

  @override
  void initState() {
    super.initState();
    // Create the controller in initState with initial settings
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (String url) {
                setState(() {
                  _isLoading = true;
                  _currentUrl = url;
                });
                _checkUrlForSuccess(url);
              },
              onPageFinished: (String url) async {
                setState(() {
                  _isLoading = false;
                });

                // Check page content for success indications
                await _checkPageContentForSuccess();

                // Try to automate form submission
                await _attemptAutoSubmission();
              },
              onNavigationRequest: (NavigationRequest request) {
                _checkUrlForSuccess(request.url);
                return NavigationDecision.navigate;
              },
            ),
          )
          ..addJavaScriptChannel(
            'UnsubscribeStatus',
            onMessageReceived: (JavaScriptMessage message) {
              if (message.message == 'success') {
                _unsubscribeDetected = true;
                _handleSuccess();
              }
            },
          )
          ..loadRequest(Uri.parse(widget.subscription.unsubscribeUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Unsubscribe: ${widget.subscription.sender}'),
        actions: [
          // Make manual confirmation button more obvious
          ElevatedButton(
            onPressed: _markAsUnsubscribed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('CONFIRM COMPLETE'),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          if (_isLoading) LinearProgressIndicator(),

          // WebView
          Expanded(child: WebViewWidget(controller: _controller)),

          // Bottom info panel
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instructions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('1. Complete any forms or verifications required'),
                Text('2. If you see a confirmation page, tap CONFIRM above'),
                Text(
                  '3. If multiple steps are required, continue through all prompts',
                ),
                SizedBox(height: 8),
                if (_unsubscribeDetected)
                  Text(
                    'Success detected! Unsubscribe appears to be complete.',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton:
          _unsubscribeDetected
              ? FloatingActionButton.extended(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                  side: BorderSide(
                    color: const Color.fromARGB(255, 179, 137, 213),
                    width: 2,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context, true);
                },
                label: Text('Confirm & Close'),
                icon: Icon(Icons.check),
                backgroundColor: Colors.green,
              )
              : null,
    );
  }

  // Check URL for success patterns
  void _checkUrlForSuccess(String url) {
    final lowercaseUrl = url.toLowerCase();
    for (var pattern in _successUrlPatterns) {
      if (lowercaseUrl.contains(pattern)) {
        // Don't immediately mark as success based only on URL
        // - many URLs contain 'unsubscribe' but aren't confirmation pages
        // Instead, use as one signal combined with page content
        _checkPageContentForSuccess();
        break;
      }
    }
  }

  // Check page content for success indications
  Future<void> _checkPageContentForSuccess() async {
    try {
      // Inject JavaScript to analyze page content
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          const bodyText = document.body.innerText.toLowerCase();
          const successPatterns = ${_successPatterns.map((p) => '"$p"').toList()};
          
          for (const pattern of successPatterns) {
            if (bodyText.includes(pattern)) {
              // Find the matching text with some context
              const regex = new RegExp('.{0,20}' + pattern + '.{0,20}', 'i');
              const match = bodyText.match(regex);
              
              // Return the matched success text or just true
              return match ? match[0] : 'true';
            }
          }
          
          // Check if there are any form submissions left
          const forms = document.querySelectorAll('form');
          const buttons = document.querySelectorAll('button, input[type="submit"]');
          
          // Look for common form elements related to unsubscribe
          const unsubForms = Array.from(forms).filter(form => {
            return form.innerHTML.toLowerCase().includes('unsubscribe') || 
                   form.action.toLowerCase().includes('unsubscribe');
          });
          
          // Look for common button text related to unsubscribe
          const unsubButtons = Array.from(buttons).filter(btn => {
            const btnText = btn.innerText.toLowerCase();
            return btnText.includes('unsubscribe') || 
                   btnText.includes('confirm') || 
                   btnText.includes('yes');
          });
          
          // If we found unsubscribe forms/buttons that need interaction
          if (unsubForms.length > 0 || unsubButtons.length > 0) {
            return 'needs_interaction';
          }
          
          return 'false';
        })();
      ''');

      // Handle the result
      final String resultString = result.toString();
      if (resultString != 'false' &&
          resultString != '"false"' &&
          resultString != 'needs_interaction' &&
          resultString != '"needs_interaction"') {
        if (!_unsubscribeDetected) {
          setState(() {
            _unsubscribeDetected = true;
          });
        }
      }
    } catch (e) {
      print('Error checking page content: $e');
    }
  }

  // Attempt to automatically submit forms
  Future<void> _attemptAutoSubmission() async {
    try {
      await _controller.runJavaScript('''
        (function() {
          // Find unsubscribe forms
          const forms = document.querySelectorAll('form');
          const unsubForms = Array.from(forms).filter(form => {
            const formHtml = form.innerHTML.toLowerCase();
            const formAction = (form.action || '').toLowerCase();
            
            return formHtml.includes('unsubscribe') || 
                   formHtml.includes('opt out') ||
                   formHtml.includes('opt-out') ||
                   formAction.includes('unsubscribe') ||
                   formAction.includes('opt-out');
          });
          
          // Find unsubscribe buttons
          const buttons = document.querySelectorAll('button, input[type="submit"]');
          const unsubButtons = Array.from(buttons).filter(btn => {
            const btnText = (btn.innerText || btn.value || '').toLowerCase();
            return btnText.includes('unsubscribe') || 
                   btnText.includes('confirm') || 
                   btnText.includes('yes');
          });
          
          // If we found a single unsubscribe form with no required fields, submit it
          if (unsubForms.length === 1) {
            const form = unsubForms[0];
            const requiredFields = form.querySelectorAll('[required]');
            
            if (requiredFields.length === 0) {
              console.log('Auto-submitting unsubscribe form');
              form.submit();
              return true;
            }
          }
          
          // If we found a single clear unsubscribe button, click it
          if (unsubButtons.length === 1) {
            const button = unsubButtons[0];
            console.log('Auto-clicking unsubscribe button');
            button.click();
            return true;
          }
          
          return false;
        })();
      ''');
    } catch (e) {
      print('Error attempting auto submission: $e');
    }
  }

  // Mark the subscription as unsubscribed
  void _markAsUnsubscribed() {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Did you complete ALL steps?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Did you complete all steps required to unsubscribe from ${widget.subscription.sender}?',
                ),
                SizedBox(height: 8),
                Text(
                  'Note: You must complete the entire process on the website.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('NO, STILL WORKING'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleSuccess();
                },
                child: Text('YES, COMPLETED EVERYTHING'),
              ),
            ],
          ),
    );
  }

  // Handle successful unsubscribe
  void _handleSuccess() {
    // Fire event to update UI
    eventBus.fire(UnsubscribeCompletedEvent(widget.subscription.id, true));

    // Show feedback and close
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Successfully unsubscribed from ${widget.subscription.sender}',
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    // Return success result and close screen
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pop(context, true);
      }
    });
  }
}
