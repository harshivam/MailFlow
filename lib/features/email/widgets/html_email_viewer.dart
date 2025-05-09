import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

class HtmlEmailViewer extends StatefulWidget {
  final String htmlContent;

  const HtmlEmailViewer({super.key, required this.htmlContent});

  @override
  State<HtmlEmailViewer> createState() => _HtmlEmailViewerState();
}

class _HtmlEmailViewerState extends State<HtmlEmailViewer> {
  late WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    // Create the controller with initial settings
    controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) => setState(() => isLoading = true),
              onPageFinished: (_) => setState(() => isLoading = false),
              // Handle external links
              onNavigationRequest: (NavigationRequest request) {
                if (request.url.startsWith('http')) {
                  // Let URL launcher handle external links
                  _launchUrl(request.url);
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadHtmlString(_wrapHtml(widget.htmlContent));
  }

  // Launch external URLs
  void _launchUrl(String url) {
    // You'll need to implement URL launching here
    print('Should launch URL: $url');
    // Using built-in URL launcher would require additional imports
  }

  // Wrap the HTML content with proper styling
  String _wrapHtml(String htmlContent) {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            font-family: Arial, sans-serif;
            font-size: 16px;
            line-height: 1.6;
            color: #333;
            padding: 0;
            margin: 0;
          }
          img {
            max-width: 100%;
            height: auto;
          }
          a {
            color: #0066cc;
          }
          pre, code {
            white-space: pre-wrap;
            word-wrap: break-word;
          }
        </style>
      </head>
      <body>
        $htmlContent
      </body>
      </html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: controller),
        if (isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
