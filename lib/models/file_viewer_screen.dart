import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../colors/app_color.dart';


class FileViewerScreen extends StatefulWidget {
  final String fileUrl;
  final String fileName;
  final Map<String, String>? headers;

  const FileViewerScreen({
    super.key,
    required this.fileUrl,
    required this.fileName,
    this.headers,
  });

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  late InAppWebViewController webViewController;
  bool isLoading = true;

  Future<void> _openInExternalBrowser() async {
    final uri = Uri.tryParse(widget.fileUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid URL')));
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open in browser')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileName.length > 30
              ? '${widget.fileName.substring(0, 30)}...'
              : widget.fileName,
        ),
        backgroundColor: AppColors.kDarkBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in browser',
            onPressed: _openInExternalBrowser,
          ),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(widget.fileUrl),
              headers: widget.headers,
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;
            },
            onLoadStop: (controller, url) {
              setState(() {
                isLoading = false;
              });
            },
            onLoadError: (controller, url, code, message) {
              setState(() {
                isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('❌ Failed to load file: $message')),
              );
            },
          ),
          if (isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: AppColors.kDarkBlue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Opening ${widget.fileName}...',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}