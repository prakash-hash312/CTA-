import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import '../colors/app_color.dart';
import '../services/api_services.dart';
import 'homeworkuploadscreen.dart';

class HomeworkDetailScreen extends StatefulWidget {
  final int hwAssignId;
  final int hwContentId;
  final String hwType;
  final int studId;
  final int batch;
  final int weekId;
  final String dueDate;

  const HomeworkDetailScreen({
    super.key,
    required this.hwAssignId,
    required this.hwContentId,
    required this.hwType,
    required this.studId,
    required this.batch,
    required this.weekId,
    required this.dueDate,
  });

  @override
  State<HomeworkDetailScreen> createState() => _HomeworkDetailScreenState();
}

class _HomeworkDetailScreenState extends State<HomeworkDetailScreen> {
  late Future<List<Map<String, dynamic>>> _detailFuture;
  final HtmlUnescape _unescape = HtmlUnescape();

  // 🔹 Audio + File Picker variables
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordedPath;

  List<File> _pickedFiles = [];
  final List<String> _allowedExtensions = ['jpeg', 'jpg', 'png', 'docx'];
  final int _maxFiles = 10;
  final int _maxSizeBytes = 3 * 1024 * 1024; // 3 MB

  @override
  void initState() {
    super.initState();
    _detailFuture = apiService.fetchHomeworkDetail(
      hwContentId: widget.hwContentId,
      hwType: widget.hwType,
    );
  }

  // Build content box with white background
  Widget _buildContentBox(String htmlString) {
    final decoded = _unescape.convert(htmlString);
    final plainText = decoded
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();

    return GestureDetector(
      onTap: () => _showFullDescription(plainText),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.15, // ✅ FIXED SIZE
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          plainText,
          maxLines: 6,                 // ✅ PREVIEW ONLY
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  void _showFullDescription(String text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),

                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.kDarkBlue,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: SingleChildScrollView(
                      controller: controller,
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }



  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade800, size: 26),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.isNotEmpty ? value : '-',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFE9F0FF),
        appBar: AppBar(
          elevation: 0,
          title: const Text(
            'Homework Details',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          centerTitle: true,
          backgroundColor: AppColors.appbarblue,
          foregroundColor: Colors.white,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFCAC5C5),
            ),
          ),
        ),
      
        // ✅ BODY uses FutureBuilder (same as you did)
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _detailFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.kDarkBlue),
              );
            }
            if (snap.hasError) {
              return Center(
                child: Text(
                  '❌ ${snap.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            if (snap.data == null || snap.data!.isEmpty) {
              return const Center(child: Text('No homework details found.'));
            }
      
            final hw = snap.data!.first;
      
            // ✅ Due Date handling (your logic kept)
            String dueDateStr = '-';
            final raw = hw['due_date'];
            if (raw != null) {
              final s = raw.toString().trim();
              final dt = DateTime.tryParse(s);
              if (dt != null) {
                dueDateStr = DateFormat('yyyy-MM-dd').format(dt);
              } else if (s.isNotEmpty && s != '-') {
                dueDateStr = s.contains('T') ? s.split('T').first : s;
              }
            }
            if (dueDateStr == '-' && widget.dueDate.isNotEmpty && widget.dueDate != '-') {
              final dt = DateTime.tryParse(widget.dueDate);
              if (dt != null) {
                dueDateStr = DateFormat('yyyy-MM-dd').format(dt);
              } else {
                dueDateStr = widget.dueDate;
              }
            }
      
            final subject = (hw['hw_subject'] ?? '').toString().trim();
      
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔵 TOP GRADIENT CARD (✅ now includes SUBJECT)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0A3D91), Color(0xFF1565C0)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Text(
                          //   hw['week_name']?.toString() ?? 'Week',
                          //   style: const TextStyle(
                          //     color: Colors.white70,
                          //     fontSize: 14,
                          //   ),
                          // ),
                          const SizedBox(height: 6),
                          if (subject.isNotEmpty)
                            Text(
                              subject,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
      
                    const SizedBox(height: 20),
      
                    // 📘 DESCRIPTION
                     Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildContentBox(hw['hw_content']?.toString() ?? ''),
      
                    const SizedBox(height: 20),
      
                    // 📄 HOMEWORK INFORMATION
                     Text(
                      'Homework Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 10),
      
                    _infoTile(
                      icon: Icons.calendar_today,
                      label: 'Due Date',
                      value: dueDateStr,
                    ),
                    _infoTile(
                      icon: Icons.folder,
                      label: 'Accepted',
                      value: hw['files_supported']?.toString() ?? '-',
                    ),
                    _infoTile(
                      icon: Icons.insert_drive_file,
                      label: 'Max Files',
                      value: hw['max_file_count']?.toString() ?? '-',
                    ),
                    _infoTile(
                      icon: Icons.star,
                      label: 'Marks',
                      value: '${hw['total_marks'] ?? '-'} Marks',
                    ),
      
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      
        // ✅ FIXED: bottomNavigationBar also uses FutureBuilder so hw is available
        bottomNavigationBar: FutureBuilder<List<Map<String, dynamic>>>(
          future: _detailFuture,
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
      
            final hw = snap.data!.first;
      
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final activeStudId =
                        apiService.currentStudentId ??
                        apiService.currentUserId ??
                        widget.studId;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HomeworkUploadScreen(
                          hwAssignId: widget.hwAssignId,
                          hwContentId: hw['hw_content_id'] ?? 0,
                          hwType: widget.hwType,
                          studId: activeStudId,
                          batch: widget.batch,
                          weekId: widget.weekId,
                          dueDate: widget.dueDate,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Upload Submission',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
