import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class SimpleHtmlViewer extends StatefulWidget {
  final String htmlContent;
  final double initialHeight; // Allow overriding default height
  final bool handleExternalLinks; // Option to handle external links

  const SimpleHtmlViewer({
    super.key,
    required this.htmlContent,
    this.initialHeight = 1.0, // Start with minimal height
    this.handleExternalLinks = true, // Enable by default
  });

  @override
  State<SimpleHtmlViewer> createState() => _SimpleHtmlViewerState();
}

class _SimpleHtmlViewerState extends State<SimpleHtmlViewer> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  final HtmlUnescape _unescape = HtmlUnescape();
  final double _webViewHeight = 1; // Start with minimal height
  late final ValueNotifier<double> _heightNotifier;

  @override
  void initState() {
    super.initState();
    _heightNotifier = ValueNotifier<double>(widget.initialHeight);

    // Initialize the controller
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.white)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (String url) {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
              },
              onPageFinished: (String url) {
                _evaluateHeight(); // Get height when page is loaded
                setState(() {
                  _isLoading = false;
                });
              },
              onWebResourceError: (WebResourceError error) {
                // Log all WebView errors for debugging
                print(
                  'WebView error: ${error.description} (${error.errorType})',
                );

                // Only mark as error for specific cases that would prevent content display
                // Most image loading errors should be ignored
                if (error.description.contains('via.placeholder')) {
                  print('Ignoring placeholder image error');
                  return;
                }

                // Only set error state for main frame issues that are critical
                if (error.isForMainFrame == true) {
                  print('Critical main frame WebView error');
                  setState(() {
                    _hasError = true;
                  });
                }
              },
              // Add external link handling from HtmlEmailViewer
              onNavigationRequest:
                  widget.handleExternalLinks
                      ? (NavigationRequest request) {
                        if (request.url.startsWith('http')) {
                          // Handle external links
                          _launchUrl(request.url);
                          return NavigationDecision.prevent;
                        }
                        return NavigationDecision.navigate;
                      }
                      : null,
            ),
          )
          // Add JavaScript channel for height updates
          ..addJavaScriptChannel(
            'Height',
            onMessageReceived: (JavaScriptMessage message) {
              final height = double.tryParse(message.message);
              if (height != null && height > 100) {
                // Sanity check
                _heightNotifier.value = height;
              }
            },
          )
          ..loadHtmlString(_processHtmlContent(widget.htmlContent));
  }

  // Launch URLs method from HtmlEmailViewer
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      if (await url_launcher.canLaunchUrl(uri)) {
        await url_launcher.launchUrl(uri);
      } else {
        debugPrint('Could not launch URL: $url');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  @override
  void dispose() {
    _heightNotifier.dispose();
    super.dispose();
  }

  // Modify the _processHtmlContent method to detect effectively empty content
  String _processHtmlContent(String content) {
    // Pre-process the content to fix common issues
    String processed = content.trim();

    // Quick check for completely empty content
    if (processed.isEmpty || RegExp(r'^\s*$').hasMatch(processed)) {
      // Return minimal HTML with custom marker for empty content
      return '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>body { margin: 0; padding: 0; }</style>
        </head>
        <body data-empty="true"></body>
        </html>
      ''';
    }

    try {
      // Fix HTML entities that might be double-encoded
      processed = _unescape.convert(processed);

      // Fix email-specific issues
      processed = processed
          .replaceAll('3D"', '"')
          .replaceAll('=\r\n', '')
          .replaceAll('=\n', '');
    } catch (e) {
      print('Error pre-processing HTML: $e');
    }

    return _wrapHtml(processed);
  }

  String _wrapHtml(String content) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            padding: 12px; 
            margin: 0; 
            font-size: 16px;
            line-height: 1.5;
            color: #333;
            word-wrap: break-word;
            max-height: 10000px; /* Prevent extremely tall content */
            overflow-y: auto; /* Make tall content scrollable within the WebView */
          }
          img { 
            max-width: 100%; 
            height: auto; 
            display: inline-block;
            max-height: 800px; /* Prevent extremely tall images */
          }
          img.broken-image {
            display: none;
          }
          table {
            max-width: 100%;
            display: block;
            overflow-x: auto;
            border-collapse: collapse;
            max-height: 2000px; /* Prevent extremely tall tables */
            overflow-y: auto;
          }
          pre {
            white-space: pre-wrap;
            word-wrap: break-word;
            background-color: #f5f5f5;
            padding: 10px;
            border-radius: 4px;
            overflow-x: auto;
          }
          a {
            color: #0366d6;
            text-decoration: none;
          }
          /* Add max height for other potentially large elements */
          div, section, article {
            max-height: 5000px;
            overflow-y: auto;
          }
        </style>
      </head>
      <body>
        $content
        <script>
          // Run after DOM is loaded
          document.addEventListener('DOMContentLoaded', function() {
            // Handle image loading errors
            document.querySelectorAll('img').forEach(img => {
              // Hide CID images that won't load
              if (img.src && img.src.startsWith('cid:')) {
                img.style.display = 'none';
              }
              
              // Add error handler for all images
              img.onerror = function() {
                this.classList.add('broken-image');
                console.log('Image failed to load: ' + this.src);
              };
              
              // Force img.src through a local proxy if using placeholder domains
              if (img.src && (
                  img.src.includes('placeholder.com') || 
                  img.src.includes('via.placeholder') ||
                  img.src.includes('placekitten') ||
                  img.src.includes('placehold.it'))) {
                img.classList.add('broken-image');
              }
            });
            
            // Make tables responsive
            document.querySelectorAll('table').forEach(table => {
              if (table.style.width || table.width) {
                table.style.width = '100%';
                table.removeAttribute('width');
              }
            });
            
            // Send initial height
            setTimeout(() => {
              const height = Math.max(
                document.body.scrollHeight,
                document.documentElement.scrollHeight,
                document.body.offsetHeight,
                document.documentElement.offsetHeight
              );
              // Cap height to prevent crashes
              const safeHeight = Math.min(height, 10000);
              Height.postMessage(safeHeight);
            }, 300);
          });
        </script>
      </body>
      </html>
    ''';
  }

  void _evaluateHeight() {
    _controller
        .runJavaScriptReturningResult('''
      (function() {
        // Special case for empty content
        if (document.body.hasAttribute('data-empty')) {
          return 0;
        }
        
        // Rest of your height calculation logic
        const height = Math.max(
          document.body.scrollHeight || 0,
          document.documentElement.scrollHeight || 0,
          document.body.offsetHeight || 0,
          document.documentElement.offsetHeight || 0
        );
        
        // If height is very small (likely empty content), return 0
        if (height < 50) return 0;
        
        return height;
      })();
    ''')
        .then((result) {
          try {
            final height =
                double.tryParse(result.toString().replaceAll('"', '')) ?? 0;
            // Only update if height is greater than zero or it's explicitly zero
            if (result.toString().contains('0') || height > 0) {
              _heightNotifier.value = height;
            }
          } catch (e) {
            print('Error parsing height: $e');
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _heightNotifier,
      builder: (context, height, child) {
        // Only hide completely if there's a critical error
        if (_hasError) {
          print("HTML viewer has critical error, returning minimal container");
          return Container(
            width: double.infinity,
            height: 0, // Zero height will allow fallback to show
          );
        }

        // Allow rendering even with small height - some emails are just short
        if (height < 50 && !_isLoading) {
          print("HTML content height is very small: $height");
        }

        // Cap height to prevent WebView crashes with extremely large content
        double safeHeight = height;
        if (height > 10000) {
          print(
            "WARNING: Limiting extremely tall HTML content from ${height}px to 10000px",
          );
          safeHeight = 10000;
        }

        return SizedBox(
          width: double.infinity,
          // Use minimum height of 100 for visible content, cap at 10000 for safety
          height: safeHeight < 100 && !_isLoading ? 100 : safeHeight,
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        );
      },
    );
  }
}
