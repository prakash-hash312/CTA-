import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../colors/app_color.dart';

import '../models/file_viewer_screen.dart';
import '../services/api_services.dart';
import 'Homeworkscreen.dart';

class UploadedFilesScreen extends StatefulWidget {
  final int hwAssignId;
  final String hwType;
  final int studId;
  final int batch;
  final int weekId;
  final String dueDate;


  const UploadedFilesScreen({
    super.key,
    required this.hwAssignId,
    required this.hwType,
    required this.studId,
    required this.batch,
    required this.weekId,
    required this.dueDate,
  });

  @override
  State<UploadedFilesScreen> createState() => _UploadedFilesScreenState();
}

class _UploadedFilesScreenState extends State<UploadedFilesScreen> {
  late Future<List<Map<String, dynamic>>> _filesFuture;
  final Map<int, bool> _downloadingFiles = {};
  int? _activeStudId;
  bool _isTurningIn = false;
  bool _isTurnedIn = false;

  String get _turnedInPrefsKey =>
      'turned_in_${widget.studId}_${widget.hwAssignId}_${widget.weekId}';

  int _resolveActiveStudId() =>
      _activeStudId ??
      apiService.currentStudentId ??
      apiService.currentUserId ??
      widget.studId;

  String get _uploadCacheKey =>
      'uploaded_files_${_resolveActiveStudId()}_${widget.hwAssignId}';

  Future<void> _loadTurnedInFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final turnedIn = prefs.getBool(_turnedInPrefsKey) ?? false;
    if (!mounted) return;
    setState(() => _isTurnedIn = turnedIn);
  }

  // Helper method to merge cached and server files
  Future<List<Map<String, dynamic>>> _loadAndMergeUploadedFiles() async {
    try {
      // Fetch from server
      final serverFiles = await apiService.fetchUploadedHomeworkFiles(
        hwAssignId: widget.hwAssignId,
        hwType: widget.hwType.trim(),
        studId: _resolveActiveStudId(),
      );

      // Get cached filenames
      final prefs = await SharedPreferences.getInstance();
      final cachedNames = prefs.getStringList(_uploadCacheKey) ?? [];

      debugPrint('📊 Merge Report:');
      debugPrint('   Server files: ${serverFiles.length}');
      debugPrint('   Cached files: ${cachedNames.length}');

      // Create a set of server file names for fast lookup
      final serverFileNames =
          serverFiles.map((f) => f['file_name'].toString()).toSet();

      // Add cached files that are not in server list
      for (final cachedName in cachedNames) {
        if (!serverFileNames.contains(cachedName)) {
          serverFiles.add({
            'file_name': cachedName,
            'submitted_date': DateTime.now().toIso8601String(),
            'file_path': '', // No path for cached-only files
          });
          debugPrint('   ➕ Added from cache: $cachedName');
        }
      }

      debugPrint('   Total merged: ${serverFiles.length}');
      return serverFiles;
    } catch (e) {
      debugPrint('❌ Error merging files: $e');
      rethrow;
    }
  }

  // String _getFullFileUrl(String rawPath) {
  //   if (rawPath.isEmpty) return '';
  //
  //   // Clean up whitespace
  //   final cleanPath = rawPath.trim();
  //
  //   debugPrint('🔍 DEBUG _getFullFileUrl:');
  //   debugPrint('   Input: $cleanPath');
  //
  //   // Handle paths like "~/CTA_homework/..." or "CTA_homework/..."
  //   String pathToUse = cleanPath;
  //
  //   if (cleanPath.startsWith('~/')) {
  //     pathToUse = cleanPath.substring(2); // Remove ~/ prefix
  //   }
  //
  //   // Remove leading slashes
  //   while (pathToUse.startsWith('/')) {
  //     pathToUse = pathToUse.substring(1);
  //   }
  //
  //   final fullUrl = 'https://www.ivpsemi.in/$pathToUse';
  //
  //   debugPrint('   Output: $fullUrl');
  //   debugPrint('');
  //
  //   return fullUrl;
  // }
  String _getFullFileUrl(String rawPath) {
    if (rawPath.isEmpty) return '';

    final cleanPath = rawPath.trim();

    // Remove the ~/ prefix if present
    String pathWithoutTilde = cleanPath;
    if (cleanPath.startsWith('~/')) {
      pathWithoutTilde = cleanPath.substring(2);
    }

    // Remove leading slashes
    while (pathWithoutTilde.startsWith('/')) {
      pathWithoutTilde = pathWithoutTilde.substring(1);
    }

    // TRY THESE FORMATS (uncomment the one that works):

    // Option 1: Direct path conversion
    // final fullUrl = 'https://www.ivpsemi.in/$pathWithoutTilde';

    // Option 2: Remove the student-specific folders (3/19233)
    // This assumes files are stored in: /CTA_homework/2025/filename
    List<String> parts = pathWithoutTilde.split('/');
    // parts = ['CTA_homework', '2025', '3', '19233', 'filename.ext']
    // We want: ['CTA_homework', '2025', 'filename.ext']
    if (parts.length >= 5) {
      parts = [parts[0], parts[1], parts.last]; // Keep only CTA_homework/2025/filename
    }
    final fullUrl = 'https://www.ivpsemi.in/${parts.join('/')}';

    debugPrint('🔍 File URL:');
    debugPrint('   Raw: $cleanPath');
    debugPrint('   Generated: $fullUrl');

    return fullUrl;
  }


  @override
  void initState() {
    super.initState();
    _loadTurnedInFlag();
    _filesFuture = _initializeAndLoad().then((files) {
      // DEBUG: Print the merged response
      debugPrint('');
      debugPrint('========== MERGED FILES (Server + Cache) ==========');
      for (var file in files) {
        debugPrint('File: ${file['file_name']}');
        debugPrint('  Path: ${file['file_path']}');
      }
      debugPrint('====================================================');
      debugPrint('');
      return files;
    });
  }

  Future<List<Map<String, dynamic>>> _initializeAndLoad() async {
    _activeStudId = await apiService.resolveActiveStudentId() ??
        apiService.currentUserId ??
        widget.studId;
    return _loadAndMergeUploadedFiles();
  }

  String _formatDate(String dateTimeStr) {
    try {
      final date = DateTime.parse(dateTimeStr);
      return '${date.day}-${date.month}-${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTimeStr;
    }
  }

  Future<void> _refreshFiles() async {
    setState(() {
      _filesFuture = _loadAndMergeUploadedFiles();
    });
  }

  // void _showSnackBar(String message) {
  //   if (!mounted) return;
  //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  // }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }


  Future<void> _downloadAndOpenFile(
      String fileUrl,
      String fileName,
      int index,
      ) async {
    setState(() {
      _downloadingFiles[index] = true;
    });

    try {
      // Get the directory to save the file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);

      // Check if file already exists locally
      if (await file.exists()) {
        // File exists, open it directly
        final result = await OpenFilex.open(filePath);
        if (result.type != ResultType.done) {
          _showSnackBar('❌ Could not open file: ${result.message}');
        }
      } else {
        // Download the file
        final response = await http.get(Uri.parse(fileUrl));

        if (response.statusCode == 200) {
          // Save file to local storage
          await file.writeAsBytes(response.bodyBytes);

          // Open the file
          final result = await OpenFilex.open(filePath);
          if (result.type == ResultType.done) {
            _showSnackBar('✅ File opened successfully');
          } else {
            _showSnackBar('❌ Could not open file: ${result.message}');
          }
        } else {
          _showSnackBar('❌ Failed to download file: ${response.statusCode}');
        }
      }
    } catch (e) {
      _showSnackBar('❌ Error: $e');
    } finally {
      setState(() {
        _downloadingFiles[index] = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Uploaded Files"),
        backgroundColor: AppColors.kDarkBlue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: _isTurnedIn ? Colors.grey.shade200 : null,
      body: RefreshIndicator(
        onRefresh: _refreshFiles,
        color: AppColors.kDarkBlue,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _filesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.kDarkBlue),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Text(
                  '❌ Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No uploaded files found.'));
            }

            final files = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final fileName = file['file_name'] ?? 'Unnamed File';
                final date = file['submitted_date'] ?? '';
                final rawPath = file['file_path'] ?? '';
                final fullUrl = _getFullFileUrl(rawPath);
                final isDownloading = _downloadingFiles[index] ?? false;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: AppColors.kLightBlue.withOpacity(0.3),
                    ),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.insert_drive_file,
                              color: AppColors.kDarkBlue,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                fileName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '📅 ${_formatDate(date)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // ORIGINAL PROBLEMATIC CODE (in View button):
                            // Add this debugging code to see what URL is being generated:

                            TextButton.icon(
                              onPressed: () {
                                if (fullUrl.isEmpty) {
                                  _showSnackBar('❌ No valid file URL');
                                  return;
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FileViewerScreen(
                                      fileUrl: fullUrl,
                                      fileName: fileName,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.visibility, color: AppColors.kDarkBlue),
                              label: const Text('View', style: TextStyle(color: AppColors.kDarkBlue)),
                            ),




                            const SizedBox(width: 10),
                            TextButton.icon(
                              onPressed: _isTurnedIn
                                  ? null
                                  : () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirm Delete'),
                                    content: Text(
                                      'Are you sure you want to delete "$fileName"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.pop(ctx); // Close dialog first

                                          // Show loading indicator
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (_) => const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          );

                                          try {
                                            // Call DELETE API
                                            final response = await apiService.deleteHomeworkFile(
                                              homeworkType: widget.hwType.trim().isEmpty
                                                  ? 'Regular Homework'
                                                  : widget.hwType.trim(),
                                              batch: widget.batch,
                                              weekId: widget.weekId,
                                              studId: _resolveActiveStudId(),
                                              fileName: fileName,
                                            );

                                            // Close loading dialog
                                            if (mounted) Navigator.pop(context);

                                            // Check response
    // after getting `response` from apiService.deleteHomeworkFile(...)
    if (response['success'] == true) {
    // refresh list from server rather than removing locally
    await _refreshFiles();
    _showSnackBar('✅ ${response['message'] ?? 'File deleted successfully'}');
    } else {
      _showSnackBar('❌ ${response['message'] ?? 'Failed to delete file'}');
    }
                                          } catch (e) {
                                            // Close loading dialog
                                            if (mounted) Navigator.pop(context);

                                            _showSnackBar('❌ Error deleting file: $e');
                                            debugPrint('Delete error: $e');
                                          }
                                        },
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: Icon(
                                Icons.delete,
                                size: 18,
                                color: _isTurnedIn ? Colors.grey : Colors.red,
                              ),
                              label: Text(
                                'Delete',
                                style: TextStyle(
                                  color: _isTurnedIn ? Colors.grey : Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                            ),

                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),

      // 🔹 Added Turn In Button Below
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: ElevatedButton.icon(
          onPressed: (_isTurningIn || _isTurnedIn)
              ? null
              : () async {
                  setState(() => _isTurningIn = true);
            try {
              final safeHwType = widget.hwType.trim().isEmpty ? 'Regular Homework' : widget.hwType.trim();

              debugPrint('--- 🟣 TURN IN FLOW STARTED ---');
              debugPrint('🧾 StudId=${widget.studId}, Batch=${widget.batch}, Week=${widget.weekId}, Type=$safeHwType');
              debugPrint('🔹 HwAssignId=${widget.hwAssignId}');

              // 1️⃣ Fetch uploaded files (latest from server)
              final uploadedFiles = await apiService.fetchUploadedHomeworkFiles(
                hwAssignId: widget.hwAssignId,
                hwType: safeHwType,
                studId: _resolveActiveStudId(),
              );

              if (uploadedFiles.isEmpty) {
                _showSnackBar('❌ No uploaded files found to turn in!');
                return;
              }

              // Extract filenames
              final uploadedFileNames = uploadedFiles.map((f) => f['file_name'].toString()).toList();
              debugPrint('📁 Files to turn in → $uploadedFileNames');

              // 2️⃣ Call API
              final response = await apiService.turnInHomework(
                hwType: safeHwType,
                batch: widget.batch,
                weekId: widget.weekId,
                studId: _resolveActiveStudId(),
                hwAssignId: widget.hwAssignId,
                userId: apiService.currentUserId ?? 0,
                uploadedFiles: uploadedFileNames,
              );

              debugPrint('✅ [TurnInHomework] Response: $response');

              // 3️⃣ Handle Success
              if (response['success'] == true) {
                _showSnackBar('✅ ${response['message']}');
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(_turnedInPrefsKey, true);
                if (mounted) setState(() => _isTurnedIn = true);
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeWorkScreen()),
                  (route) => false,
                );
              } else {
                throw Exception(response['message'] ?? 'Turn In failed.');
              }
            } catch (e) {
              debugPrint('❌ [TurnInHomework] Failed → $e');
              _showSnackBar('❌ Failed to Turn In: $e');
            } finally {
              if (mounted) setState(() => _isTurningIn = false);
            }
          },


          icon: _isTurningIn
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send, color: Colors.white),
          label: Text(
            _isTurningIn ? 'Turning In...' : 'Turn In Homework',
            style: const TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade900,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            shape: const StadiumBorder(),
            elevation: 0,
          ),
          ),
        ),
      ),
    );
  }
}
