import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html_unescape/html_unescape.dart';

class SimpleHtmlViewer extends StatefulWidget {
  final String htmlContent;
  final double initialHeight; // Allow overriding default height

  const SimpleHtmlViewer({
    super.key,
    required this.htmlContent,
    this.initialHeight = 1.0, // Start with minimal height
  });

  @override
  State<SimpleHtmlViewer> createState() => _SimpleHtmlViewerState();
}

class _SimpleHtmlViewerState extends State<SimpleHtmlViewer> {
  late final WebViewController _controller;
  bool _isLoading = true;
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
                });
              },
              onPageFinished: (String url) {
                _evaluateHeight(); // Get height when page is loaded
                setState(() {
                  _isLoading = false;
                });
              },
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
          }
          img { 
            max-width: 100%; 
            height: auto; 
            display: inline-block;
          }
          table {
            max-width: 100%;
            display: block;
            overflow-x: auto;
            border-collapse: collapse;
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
        </style>
      </head>
      <body>
        $content
        <script>
          // Run after DOM is loaded
          document.addEventListener('DOMContentLoaded', function() {
            // Fix common email rendering issues
            document.querySelectorAll('img').forEach(img => {
              if (img.src && img.src.startsWith('cid:')) {
                img.style.display = 'none';
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
              Height.postMessage(height);
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
        // Don't render at all if height is zero
        if (height <= 0) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          width: double.infinity,
          height: height,
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
