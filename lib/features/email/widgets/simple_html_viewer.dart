import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html_unescape/html_unescape.dart';

class SimpleHtmlViewer extends StatefulWidget {
  final String htmlContent;

  const SimpleHtmlViewer({Key? key, required this.htmlContent})
    : super(key: key);

  @override
  State<SimpleHtmlViewer> createState() => _SimpleHtmlViewerState();
}

class _SimpleHtmlViewerState extends State<SimpleHtmlViewer> {
  late final WebViewController _controller;
  bool _isLoading = true;
  final HtmlUnescape _unescape = HtmlUnescape();
  double _webViewHeight = 1; // Start with minimal height
  final _defaultHeight = 300.0; // Fallback height if calculation fails
  final _heightNotifier = ValueNotifier<double>(
    300.0,
  ); // Use ValueNotifier for dynamic updates

  @override
  void initState() {
    super.initState();

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

  void _evaluateHeight() {
    _controller
        .runJavaScriptReturningResult('''
      (function() {
        // Get the full height of content
        const height = Math.max(
          document.body.scrollHeight,
          document.documentElement.scrollHeight,
          document.body.offsetHeight,
          document.documentElement.offsetHeight
        );
        
        // Send it to Flutter
        Height.postMessage(height);
        
        // Add resize observer to handle dynamic content changes
        const resizeObserver = new ResizeObserver(entries => {
          const height = Math.max(
            document.body.scrollHeight,
            document.documentElement.scrollHeight,
            document.body.offsetHeight,
            document.documentElement.offsetHeight
          );
          Height.postMessage(height);
        });
        
        resizeObserver.observe(document.body);
        
        return height;
      })();
    ''')
        .then((result) {
          // Handle the initial height
          try {
            final height = double.tryParse(
              result.toString().replaceAll('"', ''),
            );
            if (height != null && height > 100) {
              _heightNotifier.value = height;
            }
          } catch (e) {
            print('Error parsing height: $e');
          }
        });
  }

  String _processHtmlContent(String content) {
    // Pre-process the content to fix common issues
    String processed = content;

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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _heightNotifier,
      builder: (context, height, child) {
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
