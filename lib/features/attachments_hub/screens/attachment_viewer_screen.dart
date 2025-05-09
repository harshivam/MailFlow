import 'package:flutter/material.dart';
import 'package:mail_merge/features/attachments_hub/models/attachment.dart';
import 'package:mail_merge/user/repository/account_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

class AttachmentViewerScreen extends StatefulWidget {
  final EmailAttachment attachment;

  const AttachmentViewerScreen({super.key, required this.attachment});

  @override
  State<AttachmentViewerScreen> createState() => _AttachmentViewerScreenState();
}

class _AttachmentViewerScreenState extends State<AttachmentViewerScreen> {
  bool _loading = true;
  String? _filePath;
  String? _errorMessage;
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _downloadAndPrepareFile();
  }

  Future<void> _downloadAndPrepareFile() async {
    try {
      // Get token for this account
      final accountRepo = AccountRepository();
      final accounts = await accountRepo.getAllAccounts();
      final account = accounts.firstWhere(
        (acc) => acc.id == widget.attachment.accountId,
        orElse: () => throw Exception('Account not found'),
      );

      // Download the file
      final response = await http.get(
        Uri.parse(widget.attachment.downloadUrl),
        headers: {'Authorization': 'Bearer ${account.accessToken}'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to download: HTTP ${response.statusCode}');
      }

      // Get a temporary directory
      final tempDir = await getTemporaryDirectory();

      // Ensure proper filename and extension
      String safeFilename = _getSafeFilename(
        widget.attachment.name,
        widget.attachment.contentType,
      );
      final file = File('${tempDir.path}/$safeFilename');

      // Write the file
      await file.writeAsBytes(response.bodyBytes);

      // Also save to downloads for convenience
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        final downloadFile = File('${downloadsDir.path}/$safeFilename');
        await file.copy(downloadFile.path);
      }

      // Update state
      if (mounted) {
        setState(() {
          _filePath = file.path;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error downloading attachment: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _getSafeFilename(String filename, String contentType) {
    // Implement the same _getSafeFilename method from AttachmentItem class
    // (Code omitted for brevity since we already defined it in AttachmentItem)

    // If filename doesn't have extension but we know the content type, add it
    if (!filename.contains('.')) {
      // Map of common MIME types to file extensions
      final extensionMap = {
        'application/pdf': '.pdf',
        'image/jpeg': '.jpg',
        'image/png': '.png',
        'image/gif': '.gif',
        'application/msword': '.doc',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
            '.docx',
        'application/vnd.ms-excel': '.xls',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
            '.xlsx',
        'application/vnd.ms-powerpoint': '.ppt',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation':
            '.pptx',
        'text/plain': '.txt',
        'application/zip': '.zip',
        'audio/mpeg': '.mp3',
        'video/mp4': '.mp4',
      };

      // Get extension for content type or default to .bin
      final extension = extensionMap[contentType.toLowerCase()] ?? '.bin';
      return '$filename$extension';
    }
    return filename;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.attachment.name),
        actions: [
          if (_filePath != null) ...[
            IconButton(icon: Icon(Icons.share), onPressed: _shareFile),
            IconButton(
              icon: Icon(Icons.open_in_new),
              onPressed: _openFileExternally,
            ),
          ],
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildPdfNavigationBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Downloading attachment...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Error loading attachment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700]),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _errorMessage = null;
                  });
                  _downloadAndPrepareFile();
                },
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filePath == null) {
      return Center(child: Text('Unable to load attachment'));
    }

    // Display based on file type
    if (widget.attachment.contentType.contains('pdf')) {
      return PDFView(
        filePath: _filePath!,
        enableSwipe: true,
        swipeHorizontal: true,
        autoSpacing: true,
        pageFling: true,
        pageSnap: true,
        onRender: (pages) {
          setState(() {
            _totalPages = pages!;
            _currentPage = 1;
          });
        },
        onPageChanged: (page, total) {
          setState(() {
            _currentPage = page! + 1;
          });
        },
        onError: (error) {
          setState(() {
            _errorMessage = error.toString();
          });
        },
      );
    } else if (widget.attachment.contentType.contains('image')) {
      return Center(
        child: Image.file(
          File(_filePath!),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Could not display image'),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _openFileExternally,
                  child: Text('Open with another app'),
                ),
              ],
            );
          },
        ),
      );
    } else {
      // For other file types, show preview options
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.attachment.icon,
                size: 72,
                color: Theme.of(context).primaryColor,
              ),
              SizedBox(height: 16),
              Text(
                widget.attachment.name,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                '${widget.attachment.formattedSize} • ${widget.attachment.contentType}',
                style: TextStyle(color: Colors.grey[700]),
              ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                icon: Icon(Icons.open_in_new),
                label: Text('Open with external app'),
                onPressed: _openFileExternally,
              ),
              SizedBox(height: 16),
              OutlinedButton.icon(
                icon: Icon(Icons.share),
                label: Text('Share file'),
                onPressed: _shareFile,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget? _buildPdfNavigationBar() {
    // Only show bottom navigation for PDFs with multiple pages
    if (!widget.attachment.contentType.contains('pdf') ||
        _totalPages <= 1 ||
        _loading ||
        _errorMessage != null) {
      return null;
    }

    return Container(
      color: Theme.of(context).primaryColor,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed:
                _currentPage > 1
                    ? () {
                      // PDF view uses zero-based indexing
                      final pdfViewController = PdfViewerController();
                      pdfViewController.previousPage(
                        curve: Curves.ease,
                        duration: Duration(milliseconds: 300),
                      );
                    }
                    : null,
          ),
          Text(
            'Page $_currentPage of $_totalPages',
            style: TextStyle(color: Colors.white),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward, color: Colors.white),
            onPressed:
                _currentPage < _totalPages
                    ? () {
                      // PDF view uses zero-based indexing
                      final pdfViewController = PdfViewerController();
                      pdfViewController.nextPage(
                        curve: Curves.ease,
                        duration: Duration(milliseconds: 300),
                      );
                    }
                    : null,
          ),
        ],
      ),
    );
  }

  Future<void> _shareFile() async {
    if (_filePath == null) return;

    try {
      await Share.shareXFiles([
        XFile(_filePath!),
      ], text: 'Sharing "${widget.attachment.name}" from MailFlow');
    } catch (e) {
      print('Error sharing file: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sharing file: $e')));
    }
  }

  Future<void> _openFileExternally() async {
    if (_filePath == null) return;

    try {
      final result = await OpenFile.open(_filePath!);
      if (result.type != 'done') {
        throw Exception(result.message);
      }
    } catch (e) {
      print('Error opening file: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening file: $e')));
    }
  }
}

// A simple controller for PDFView
class PdfViewerController {
  void nextPage({required Duration duration, required Curve curve}) {
    // This would need to be implemented with a real controller
    // This is just a placeholder
  }

  void previousPage({required Duration duration, required Curve curve}) {
    // This would need to be implemented with a real controller
    // This is just a placeholder
  }
}
