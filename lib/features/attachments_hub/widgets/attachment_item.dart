import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mail_merge/features/attachments_hub/models/attachment.dart';
import 'package:mail_merge/features/email/screens/email_detail_screen.dart';
import 'package:mail_merge/user/services/auth_service.dart';
import 'package:mail_merge/utils/date_formatter.dart';
import 'package:mail_merge/user/repository/account_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:marquee/marquee.dart';
import 'package:mail_merge/utils/file_utils.dart';

class AttachmentItem extends StatelessWidget {
  final EmailAttachment attachment;
  final Function(EmailAttachment)? onViewDetails;

  const AttachmentItem({
    super.key,
    required this.attachment,
    this.onViewDetails,
  });

  // Consolidate duplicate file type handling
  Map<String, dynamic> _getFileTypeProperties(String contentType) {
    if (contentType.contains('image')) {
      return {'color': Colors.lightBlue, 'icon': Icons.image};
    }
    if (contentType.contains('pdf')) {
      return {'color': Colors.red, 'icon': Icons.picture_as_pdf};
    }
    if (contentType.contains('word') || contentType.contains('document')) {
      return {'color': Colors.blue, 'icon': Icons.description};
    }
    if (contentType.contains('excel') || contentType.contains('spreadsheet')) {
      return {'color': Colors.green, 'icon': Icons.table_chart};
    }
    if (contentType.contains('presentation') ||
        contentType.contains('powerpoint')) {
      return {'color': Colors.orange, 'icon': Icons.slideshow};
    }
    if (contentType.contains('zip') || contentType.contains('rar')) {
      return {'color': Colors.purple, 'icon': Icons.folder_zip};
    }
    if (contentType.contains('audio')) {
      return {'color': Colors.amber, 'icon': Icons.audiotrack};
    }
    if (contentType.contains('video')) {
      return {'color': Colors.pink, 'icon': Icons.movie};
    }

    // Default
    return {'color': Colors.grey, 'icon': Icons.insert_drive_file};
  }

  // Helper method to get background color based on file type
  Color _getBackgroundColor() {
    return _getFileTypeProperties(attachment.contentType)['color'][50]!;
  }

  // Helper method to get icon color based on file type
  Color _getIconColor() {
    return _getFileTypeProperties(attachment.contentType)['color'][700]!;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!, width: 0.5),
      ),
      child: InkWell(
        onTap: () => _viewAttachment(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File icon
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _getBackgroundColor(),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        attachment.icon,
                        size: 40,
                        color: _getIconColor(),
                      ),
                    ),
                  ),

                  // Favorite icon indicator for future feature
                  if (attachment.isFavorite == true)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // File name - using Expanded to prevent overflow
              SizedBox(
                height: 40, // Fixed height to accommodate two lines of text
                child: Text(
                  attachment.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 2),

              // File size
              Text(
                attachment.formattedSize,
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
              const SizedBox(height: 2),

              // Date
              Text(
                formatEmailDate(attachment.date.toIso8601String()),
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),

              // Fix vertical spacing with fixed height instead of Spacer
              const SizedBox(height: 6),

              // From email text
              SizedBox(
                height: 17, // Give it a fixed height for the marquee
                child:
                    attachment.senderEmail.length > 15
                        ? Marquee(
                          text: 'From: ${attachment.senderEmail}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                          scrollAxis: Axis.horizontal,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          blankSpace: 20.0,
                          velocity: 30.0, // Speed of the marquee
                          pauseAfterRound: Duration(seconds: 1),
                          startPadding: 10.0,
                          accelerationDuration: Duration(seconds: 1),
                          accelerationCurve: Curves.linear,
                          decelerationDuration: Duration(milliseconds: 500),
                          decelerationCurve: Curves.easeOut,
                        )
                        : Text(
                          'From: ${attachment.senderEmail}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Update this method to simplify the options:
  void _viewAttachment(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.open_in_new),
                  title: Text('Open attachment'),
                  onTap: () {
                    Navigator.pop(context);
                    _openAttachment(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('View original email'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => EmailDetailScreen(
                              // EmailDetailScreen expects a Map<String, dynamic> 'email' parameter
                              email: {
                                'id': attachment.emailId,
                                'name': attachment.senderName,
                                'from': attachment.senderEmail,
                                'message': attachment.emailSubject,
                                'time': attachment.date.toIso8601String(),
                                'accountId':
                                    attachment
                                        .accountId, // Include accountId in the map
                                'accountName':
                                    'Email Account', // Fallback value since we don't have this
                                'provider':
                                    'Gmail', // Fallback value since we don't have this
                                'snippet':
                                    'original email containing this attachment', // Default snippet
                              },
                            ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Download to device'),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadAttachment(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Share'),
                  onTap: () {
                    Navigator.pop(context);
                    _showError(context, 'Share feature coming soon');
                  },
                ),
              ],
            ),
          ),
    );
  }

  // Fix the _openAttachment method by moving the file declaration to the top
  Future<void> _openAttachment(BuildContext context) async {
    try {
      // Show loading indicator only while downloading
      final messenger = ScaffoldMessenger.of(context);

      // Get temporary directory for saving the file
      final tempDir = await getTemporaryDirectory();

      // Ensure the filename has the correct extension and is safe
      final safeFilename = FileUtils.getSafeFilename(
        attachment.name,
        attachment.contentType,
      );

      // IMPORTANT: Move file declaration to the top of the method
      final file = File('${tempDir.path}/$safeFilename');

      final loadingSnackbar = SnackBar(
        content: Text('Preparing attachment...'),
      );
      ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
      snackbarController;

      if (!await file.exists()) {
        // Only show loading during download, not when opening
        snackbarController = messenger.showSnackBar(loadingSnackbar);

        // Get a fresh token for this account
        final accessToken = await _getValidToken(attachment.accountId);

        print('Downloading file from: ${attachment.downloadUrl}');

        // Download the file with authorization
        final response = await http.get(
          Uri.parse(attachment.downloadUrl),
          headers: {'Authorization': 'Bearer $accessToken'},
        );

        if (response.statusCode != 200) {
          print('Failed download with status code: ${response.statusCode}');
          throw Exception('Failed to download: HTTP ${response.statusCode}');
        }

        // Process the API response based on provider
        try {
          // Check if this is from Gmail API (contains base64 data in JSON format)
          if (response.headers['content-type']?.contains('application/json') ??
              false) {
            try {
              // Try to parse as Gmail JSON response with base64 data
              final jsonResponse = jsonDecode(response.body);
              if (jsonResponse.containsKey('data')) {
                // This is a Gmail attachment
                final base64Data = jsonResponse['data'];
                if (base64Data == null) {
                  throw Exception('Invalid attachment data');
                }
                await FileUtils.writeBase64ToFile(base64Data, file.path);
              } else if (jsonResponse.containsKey('contentBytes')) {
                // This is an Outlook attachment - Microsoft Graph API uses 'contentBytes' field
                print('Found Outlook attachment with contentBytes field');
                final base64Data = jsonResponse['contentBytes'];
                if (base64Data == null) {
                  throw Exception('Invalid Outlook attachment data');
                }
                await FileUtils.writeBase64ToFile(base64Data, file.path);
              } else {
                // Unknown JSON format
                print(
                  'JSON response does not contain expected fields, treating as binary',
                );
                await file.writeAsBytes(response.bodyBytes);
              }
            } catch (e) {
              print('Error parsing JSON, falling back to binary: $e');
              // If JSON parsing fails, try writing the response as binary
              await file.writeAsBytes(response.bodyBytes);
            }
          } else {
            // Direct binary file (typical for Outlook)
            print(
              'Content-type: ${response.headers['content-type']}, treating as binary',
            );
            await file.writeAsBytes(response.bodyBytes);
          }

          // Debug the file after writing
          if (await file.exists()) {
            final fileSize = await file.length();
            print(
              'File successfully written to ${file.path}, size: $fileSize bytes',
            );

            // Analyze the first few bytes if it's an image
            if (attachment.contentType.contains('image/')) {
              final bytes = await file.readAsBytes();
              _analyzeImageData(bytes, file.path);
            }
          }
        } catch (e) {
          print('Error processing attachment data: $e');
          throw Exception('Invalid attachment format: $e');
        }
      } else {
        print('File already exists at: ${file.path}');
      }

      // Hide loading indicator if it was shown
      if (snackbarController != null) {
        messenger.hideCurrentSnackBar();
      }

      // Open with system viewer directly - no custom viewers
      await OpenFile.open(file.path);
    } catch (e) {
      print('Error opening attachment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open attachment: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Updated download method to avoid using FilePicker
  Future<void> _downloadAttachment(BuildContext context) async {
    try {
      // Show loading indicator
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Downloading attachment...')),
      );

      // For Android 10+, use the MediaStore API
      Directory? targetDir;
      String finalPath = "";

      if (Platform.isAndroid) {
        // Try to use the app's external storage first (more reliable on newer Android)
        targetDir = await getExternalStorageDirectory();
        targetDir ??= await getApplicationDocumentsDirectory();
      } else {
        // On iOS use the documents directory
        targetDir = await getApplicationDocumentsDirectory();
      }

      // Get a fresh token for this account
      final accessToken = await _getValidToken(attachment.accountId);

      // Download the file with authorization
      final response = await http.get(
        Uri.parse(attachment.downloadUrl),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        // Get appropriate directory based on platform
        Directory? downloadsDir;
        if (Platform.isAndroid) {
          // First try to use the Downloads directory (Android only)
          try {
            // This doesn't always work on newer Android, but try first
            downloadsDir = Directory('/storage/emulated/0/Download');
            if (!(await downloadsDir.exists())) {
              downloadsDir = null;
            }
          } catch (e) {
            print('Error accessing public Downloads: $e');
            downloadsDir = null;
          }

          // Fall back to app-specific directory
          downloadsDir ??= await getExternalStorageDirectory();

          // Last resort
          downloadsDir ??= await getApplicationDocumentsDirectory();
        } else {
          // On iOS use the documents directory
          downloadsDir = await getApplicationDocumentsDirectory();
        }

        // Ensure the filename has the correct extension
        final filename = _ensureFileExtension(
          attachment.name,
          attachment.contentType,
        );
        final file = File('${downloadsDir.path}/$filename');

        // NEW CODE: Decode Base64 data from Gmail API
        try {
          // Parse the JSON response
          final jsonResponse = jsonDecode(response.body);

          // Extract the base64 data
          final base64Data = jsonResponse['data'];
          if (base64Data == null) {
            throw Exception('Invalid attachment data');
          }

          await FileUtils.writeBase64ToFile(base64Data, file.path);
        } catch (e) {
          print('Error processing attachment data: $e');
          throw Exception('Invalid attachment format: $e');
        }

        // Near line 436 - Update the snackbar section to open file without showing unnecessary messages
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Downloaded to ${file.path}'),
            action: SnackBarAction(
              label: 'OPEN',
              onPressed: () async {
                // Simply open the file without showing any additional messages
                await OpenFile.open(file.path);
              },
            ),
          ),
        );
      } else {
        throw Exception('Failed to download: ${response.statusCode}');
      }
    } catch (e) {
      print('Error downloading attachment: $e');
      _showError(context, 'Failed to download attachment: ${e.toString()}');
    }
  }

  // Helper method to ensure filename has proper extension
  String _ensureFileExtension(String filename, String contentType) {
    // If filename already has extension, return as is
    if (filename.contains('.')) {
      return filename;
    }

    // Expanded map of content types to extensions
    final extensionMap = {
      'application/pdf': '.pdf',
      'image/jpeg': '.jpg',
      'image/jpg': '.jpg',
      'image/png': '.png',
      'image/gif': '.gif',
      'image/webp': '.webp',
      'image/bmp': '.bmp',
      'image/tiff': '.tiff',
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
      'text/html': '.html',
      'text/css': '.css',
      'text/javascript': '.js',
      'application/zip': '.zip',
      'application/x-rar-compressed': '.rar',
      'application/x-7z-compressed': '.7z',
      'application/java-archive': '.jar',
      'audio/mpeg': '.mp3',
      'audio/wav': '.wav',
      'audio/ogg': '.ogg',
      'video/mp4': '.mp4',
      'video/mpeg': '.mpeg',
      'video/quicktime': '.mov',
      'video/x-msvideo': '.avi',
    };

    // Extract main content type for fallback matching
    final mainType = contentType.split('/')[0];

    // Try exact match first
    if (extensionMap.containsKey(contentType)) {
      return '$filename${extensionMap[contentType]}';
    }

    // Try partial match
    for (var entry in extensionMap.entries) {
      if (contentType.contains(entry.key)) {
        return '$filename${entry.value}';
      }
    }

    // Fallback to type category
    switch (mainType) {
      case 'image':
        return '$filename.jpg';
      case 'text':
        return '$filename.txt';
      case 'audio':
        return '$filename.mp3';
      case 'video':
        return '$filename.mp4';
      default:
        return '$filename.bin';
    }
  }

  // Helper method to show error messages
  void _showError(BuildContext context, String message) {
    print('Showing error: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // Add this function to help with image data debugging
  void _analyzeImageData(List<int> bytes, String filename) {
    if (bytes.length < 16) {
      print('WARNING: File data is too small: ${bytes.length} bytes');
      return;
    }

    print('First 16 bytes: ${bytes.sublist(0, 16)}');

    // Check for common image signatures
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
      print('$filename appears to be a valid JPEG file');
    } else if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      print('$filename appears to be a valid PNG file');
    } else if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      print('$filename appears to be a valid GIF file');
    } else if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
      print('$filename appears to be a valid BMP file');
    } else {
      print(
        '$filename has unknown image format signature: ${bytes.sublist(0, 4)}',
      );
    }
  }

  // Add this helper method inside the AttachmentItem class, before the end of the class
  Future<String> _getValidToken(String accountId) async {
    try {
      final AccountRepository accountRepo = AccountRepository();
      final accounts = await accountRepo.getAllAccounts();
      final account = accounts.firstWhere(
        (acc) => acc.id == accountId,
        orElse: () => throw Exception('Account not found'),
      );

      // Check if token will expire soon (in next 5 minutes)
      if (DateTime.now()
          .add(const Duration(minutes: 5))
          .isAfter(account.tokenExpiry)) {
        // Token expiring soon, refresh it
        print('Token expiring soon, refreshing before download');
        final authService = AuthService();
        final freshToken = await authService.getAccessToken(accountId);
        if (freshToken != null) {
          return freshToken;
        }
      }

      return account.accessToken;
    } catch (e) {
      print('Error getting valid token: $e');
      throw Exception('Authentication error: $e');
    }
  }
}
