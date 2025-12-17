import 'dart:async';
import 'dart:io';
import 'package:cta_design_prakash/screen/uploaded_file_screen.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../colors/app_color.dart';
import '../services/api_services.dart';
import 'Homeworkscreen.dart';

class HomeworkUploadScreen extends StatefulWidget {
  final int hwContentId;
  final String hwType;
  final int studId;
  final int batch;
  final int weekId;
  final String dueDate;
  final int hwAssignId;

  const HomeworkUploadScreen({
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
  State<HomeworkUploadScreen> createState() => _HomeworkUploadScreenState();
}

class _HomeworkUploadScreenState extends State<HomeworkUploadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTab = 0;
  bool _isTurningIn = false;

  List<File> _uploadedFiles = [];
  List<Map<String, dynamic>> _serverFiles = [];
  bool _isLoadingServerFiles = false;

  final List<String> _allowedExtensions = [
    'jpeg',
    'jpg',
    'png',
    'docx',
    'pdf',
    'txt',
    'mp3',
    'wav',
    'm4a'
  ];
  final int _maxFiles = 10;
  final int _maxDocFiles = 6;
  final int _maxAudioFiles = 4;
  final int _maxSizeBytes = 1 * 1024 * 1024;

  final Set<String> _audioExtensions = {'mp3', 'wav', 'm4a'};

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  double _volume = 1.0;

  String? _tempRecordedPath;
  String? _recordedPath;

  Timer? _recTimer;
  int _recSeconds = 0;

  bool _showRecordingDialog = false;
  bool _recordingComplete = false;

  // ------------------- UI HELPERS (ONLY STYLING) -------------------
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE6EEF8)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  ButtonStyle _primaryButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.kDarkBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  ButtonStyle _darkButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF3A3F47),
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _buildBottomActionBar() {
    final hasAnyFiles = _uploadedFiles.isNotEmpty || _serverFiles.isNotEmpty;

    if (!hasAnyFiles) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: _isTurningIn ? null : () => _submitHomework(isDraft: true),
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(), // pill shape
                    side: BorderSide(color: Colors.blue.shade800, width: 1.6),
                    foregroundColor: Colors.blue.shade800,
                    backgroundColor: Colors.transparent,
                  ),
                  child: const Text(
                    'Save Draft',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _isTurningIn ? null : _showTurnInConfirmationDialog,
                  style: ElevatedButton.styleFrom(
                    shape: const StadiumBorder(), // pill shape
                    elevation: 0,
                    backgroundColor: Colors.blue.shade900,
                    foregroundColor: Colors.white,
                  ),
                  child: _isTurningIn
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                      : const Text(
                    'Turn In',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ------------------- LOGIC (UNCHANGED) -------------------
  bool _isAudioFile(File f) {
    final name = f.path.split('/').last;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return _audioExtensions.contains(ext);
  }

  bool _isDocumentFile(File f) {
    final name = f.path.split('/').last;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return !_audioExtensions.contains(ext);
  }

  bool _isServerAudioFile(String fileName) {
    final ext =
    fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    return _audioExtensions.contains(ext);
  }

  int get _currentDocCount =>
      _uploadedFiles.where((f) => _isDocumentFile(f)).length +
          _serverFiles
              .where((f) => !_isServerAudioFile(f['file_name'] ?? ''))
              .length;

  int get _currentAudioCount =>
      _uploadedFiles.where((f) => _isAudioFile(f)).length +
          _serverFiles.where((f) => _isServerAudioFile(f['file_name'] ?? '')).length;

  int get _totalFileCount => _uploadedFiles.length + _serverFiles.length;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _fetchServerFiles() async {
    setState(() => _isLoadingServerFiles = true);
    try {
      debugPrint('📥 Fetching server files for hwAssignId=${widget.hwAssignId}');
      final safeHwType =
      widget.hwType.trim().isEmpty ? 'Regular Homework' : widget.hwType.trim();
      final files = await apiService.fetchUploadedHomeworkFiles(
        hwAssignId: widget.hwAssignId,
        hwType: safeHwType,
      );
      setState(() {
        _serverFiles = files;
        _isLoadingServerFiles = false;
      });
      debugPrint('✅ Loaded ${files.length} files from server');
    } catch (e) {
      debugPrint('❌ Failed to fetch server files: $e');
      setState(() => _isLoadingServerFiles = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load uploaded files: $e'),
              backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _deleteServerFile(Map<String, dynamic> file) async {
    final fileName = file['file_name'] ?? '';
    if (fileName.isEmpty) return;
    try {
      debugPrint('🗑️ Deleting server file: $fileName');
      final safeHwType =
      widget.hwType.trim().isEmpty ? 'Regular Homework' : widget.hwType.trim();
      final result = await apiService.deleteHomeworkFile(
        homeworkType: safeHwType,
        batch: widget.batch,
        weekId: widget.weekId,
        studId: widget.studId,
        fileName: fileName,
      );
      if (result['success'] == true) {
        setState(() {
          _serverFiles.removeWhere((f) => f['file_name'] == fileName);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${result['message'] ?? 'File deleted successfully'}'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (result['statusCode'] == 404) {
        setState(() {
          _serverFiles.removeWhere((f) => f['file_name'] == fileName);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ File removed from list (stored in legacy location)'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        throw Exception(result['message'] ?? 'Failed to delete file');
      }
    } catch (e) {
      debugPrint('❌ Delete failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to delete: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cacheUploadedNames(List<String> names) async {
    if (names.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'uploaded_files_${widget.hwAssignId}';
      final existing = prefs.getStringList(key) ?? [];
      final merged = <String>{...existing, ...names}.toList();
      await prefs.setStringList(key, merged);
      debugPrint('💾 Cached ${merged.length} files for hwAssignId=${widget.hwAssignId}');
    } catch (e) {
      debugPrint('❌ Cache error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _currentTab = _tabController.index);
    });
    _fetchServerFiles();
  }

  Future<void> _pickFiles() async {
    if (_totalFileCount >= _maxFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already have 10 files. Cannot add more!')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
    );
    if (result == null) return;

    final picked = result.files
        .where((e) => e.path != null)
        .map((e) => File(e.path!))
        .toList();

    for (var f in picked) {
      final name = f.path.split('/').last;
      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
      final size = await f.length();

      if (!_allowedExtensions.contains(ext)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $name: invalid file type ($ext not allowed)')),
        );
        return;
      }

      if (size > _maxSizeBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $name: exceeds 1 MB size limit')),
        );
        return;
      }
    }

    final pickedDocs = picked.where((f) => _isDocumentFile(f)).length;
    final pickedAudio = picked.where((f) => _isAudioFile(f)).length;

    if (_currentDocCount + pickedDocs > _maxDocFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Document limit exceeded. You can upload maximum $_maxDocFiles documents.\nCurrently uploaded documents: $_currentDocCount.',
          ),
        ),
      );
      return;
    }

    if (_currentAudioCount + pickedAudio > _maxAudioFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Audio limit exceeded. You can upload maximum $_maxAudioFiles recordings.\nCurrently uploaded recordings: $_currentAudioCount.',
          ),
        ),
      );
      return;
    }

    if (_totalFileCount + picked.length > _maxFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ You can upload only up to $_maxFiles files total.\nCurrently you already have $_totalFileCount files.',
          ),
        ),
      );
      return;
    }

    setState(() => _uploadedFiles.addAll(picked));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${picked.length} file(s) added successfully.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final tmp = Directory.systemTemp.path;
        final path = '$tmp/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        _recTimer?.cancel();
        _recSeconds = 0;
        _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() => _recSeconds++);
        });

        setState(() {
          _isRecording = true;
          _recordingComplete = false;
          _tempRecordedPath = path;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied.')),
        );
      }
    } catch (e) {
      debugPrint('Start recording failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('Stop recorder error: $e');
    }

    _recTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordingComplete = true;
    });

    if (_tempRecordedPath != null) {
      final f = File(_tempRecordedPath!);
      if (await f.exists()) {
        final len = await f.length();
        if (len > _maxSizeBytes) {
          try {
            await f.delete();
          } catch (_) {}
          setState(() {
            _tempRecordedPath = null;
            _recordedPath = null;
            _recSeconds = 0;
            _recordingComplete = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recording exceeds 1 MB — please shorten and re-record.'),
            ),
          );
          return;
        }

        if (_currentAudioCount + 1 > _maxAudioFiles) {
          try {
            await f.delete();
          } catch (_) {}
          setState(() {
            _tempRecordedPath = null;
            _recordedPath = null;
            _recSeconds = 0;
            _recordingComplete = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot record — audio limit of $_maxAudioFiles recordings reached.'),
            ),
          );
          return;
        }

        setState(() {
          _recordedPath = _tempRecordedPath;
          _tempRecordedPath = null;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _discardRecording() {
    if (_recordedPath != null) {
      try {
        File(_recordedPath!).deleteSync();
      } catch (_) {}
    }
    setState(() {
      _recordedPath = null;
      _tempRecordedPath = null;
      _recSeconds = 0;
      _recordingComplete = false;
      _showRecordingDialog = false;
    });
  }

  Future<void> _saveRecording() async {
    if (_recordedPath == null) return;

    final audioFile = File(_recordedPath!);
    if (!await audioFile.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recorded file not found.')),
      );
      _discardRecording();
      return;
    }

    if (_currentAudioCount >= _maxAudioFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot save — audio limit ($_maxAudioFiles) reached.')),
      );
      return;
    }

    if (_totalFileCount >= _maxFiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save — already have 10 files.')),
      );
      return;
    }

    setState(() {
      _uploadedFiles.add(audioFile);
      _recordedPath = null;
      _recSeconds = 0;
      _recordingComplete = false;
      _showRecordingDialog = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎧 Audio saved to uploaded list'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _recTimer?.cancel();
    _tabController.dispose();
    try {
      _recorder.stop();
    } catch (_) {}
    _player.dispose();
    super.dispose();
  }

  // ------------------- UI WIDGETS (SAME LOGIC, BETTER LOOK) -------------------
  Widget _buildUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upload Card
          GestureDetector(
            onTap: _pickFiles,
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: Colors.white,
                // gradient: const LinearGradient(
                //   begin: Alignment.topLeft,
                //   end: Alignment.bottomRight,
                //   colors: [
                //     Color(0xFFF7FBFF),
                //     Color(0xFFEAF3FF),
                //   ],
                // ),
                border: Border.all(color: const Color(0xFFD6E6FF)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0A3D91), Color(0xFF1565C0)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.cloud_upload_outlined,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Upload Homework',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap to browse files\n(Max 10 files)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),
          _buildUploadedFilesSection(),
        ],
      ),
    );
  }

  Widget _buildRecordAudioCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 190, // 👈 keeps visual consistency
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white,
        // gradient: const LinearGradient(
        //   begin: Alignment.topLeft,
        //   end: Alignment.bottomRight,
        //   colors: [
        //     Color(0xFFF7FBFF),
        //     Color(0xFFEAF3FF),
        //   ],
        // ),
        border: Border.all(color: Color(0xFFD6E6FF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min, // ✅ VERY IMPORTANT
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 🎤 MIC BADGE
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _isRecording
                  ? const LinearGradient(
                colors: [Colors.redAccent, Colors.red],
              )
                  : const LinearGradient(
                colors: [Color(0xFF0A3D91), Color(0xFF1565C0)],
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isRecording ? Colors.red : Colors.blue)
                      .withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              _isRecording ? Icons.mic : Icons.mic_none,
              size: 34,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 14),

          // 📝 TITLE
          Text(
            _isRecording
                ? 'Recording...'
                : (_recordingComplete ? 'Recording Ready' : 'Record Audio'),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A237E),
            ),
          ),

          if (_isRecording) ...[
            const SizedBox(height: 6),
            Text(
              '${(_recSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recSeconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 🎯 ACTION BUTTONS
          if (!_recordingComplete)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  _isRecording ? Colors.red : Colors.blue.shade900,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                child: Text(
                  _isRecording ? 'Stop Recording' : 'Start Recording',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _discardRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.grey.shade700,
                      shape: const StadiumBorder(),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    child: const Text(
                      'Discard',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveRecording,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      side: BorderSide(color: Colors.green.shade400),
                    ),
                    child: const Text(
                      'Save Audio',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }



  Widget _buildRecordTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRecordAudioCard(),
          const SizedBox(height: 18),
          _buildUploadedFilesSection(),
        ],
      ),
    );
  }

  Widget _buildUploadedFilesSection() {
    final hasAnyFiles = _uploadedFiles.isNotEmpty || _serverFiles.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // const Icon(Icons.folder, color: Color(0xFFFFC107), size: 26),
            // const SizedBox(width: 8),
            Text(
              'Uploaded Files',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.blue.shade800),
            ),
            const Spacer(),
            if (_isLoadingServerFiles)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (!hasAnyFiles && !_isLoadingServerFiles)
          Container(
            width: double.infinity,
            decoration: _cardDecoration(),
            padding: const EdgeInsets.all(22),
            child: Center(
              child: Text(
                'No files uploaded yet',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ),
          )
        else ...[
          ..._serverFiles.map((file) => _buildServerFileItem(file)).toList(),
          ..._uploadedFiles.map((file) => _buildFileItem(file)).toList(),
        ],
      ],
    );
  }

  Widget _buildServerFileItem(Map<String, dynamic> file) {
    final fileName = file['file_name'] ?? 'Unknown';
    final filePath = file['file_path'] ?? '';
    final isAudio = _isServerAudioFile(fileName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isAudio ? const Color(0xFFE3F2FD) : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isAudio ? Icons.audiotrack : Icons.insert_drive_file,
              color: isAudio ? const Color(0xFF1976D2) : const Color(0xFF388E3C),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          TextButton(
            onPressed: () {
              if (filePath.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('File path: $filePath')),
                );
              }
            },
            child: const Text('View', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: () => _deleteServerFile(file),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFD32F2F))),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(File file) {
    final name = file.path.split('/').last;
    final isAudio = _isAudioFile(file);

    return FutureBuilder<int>(
      future: file.length(),
      builder: (context, snapshot) {
        final size = snapshot.data ?? 0;
        final sizeStr = _formatFileSize(size);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: _cardDecoration(),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAudio ? Icons.audiotrack : Icons.insert_drive_file,
                  color: const Color(0xFF1976D2),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sizeStr,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async => OpenFilex.open(file.path),
                child: const Text('View', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              TextButton(
                onPressed: () => setState(() => _uploadedFiles.remove(file)),
                child: const Text('Delete',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFD32F2F))),
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------- YOUR EXISTING SUBMIT + TURNIN FLOW (UNCHANGED) -------------------
  Future<void> _submitHomework({required bool isDraft}) async {
    if (_uploadedFiles.isEmpty && _serverFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least one file!')),
      );
      return;
    }

    try {
      final safeHwType =
      widget.hwType.trim().isEmpty ? 'Regular Homework' : widget.hwType.trim();

      List<String> allUploadedNames = [];

      if (_uploadedFiles.isNotEmpty) {
        final uploadResponse = await apiService.uploadHomeworkFiles(
          studentId: widget.studId,
          batch: widget.batch,
          weekId: widget.weekId,
          homeworkType: safeHwType,
          files: _uploadedFiles,
        );

        final fileSection = uploadResponse['data'] ??
            uploadResponse['files'] ??
            uploadResponse['uploadedFiles'] ??
            uploadResponse['FileNames'];

        if (fileSection is List && fileSection.isNotEmpty) {
          allUploadedNames.addAll(fileSection.map((e) {
            if (e is Map && e.containsKey('FileName')) {
              return e['FileName'].toString();
            }
            return e.toString();
          }));
        } else {
          allUploadedNames.addAll(_uploadedFiles.map((f) => f.path.split('/').last));
        }
      }

      final serverFileNames = _serverFiles
          .map((f) => f['file_name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      allUploadedNames.addAll(serverFileNames);
      await _cacheUploadedNames(allUploadedNames);

      final draftResponse = await apiService.draftHomework(
        hwType: safeHwType,
        batch: widget.batch,
        weekId: widget.weekId,
        studId: widget.studId,
        hwAssignId: widget.hwAssignId,
        userId: apiService.currentUserId!,
        uploadedFiles: allUploadedNames,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ $draftResponse'), backgroundColor: Colors.green),
      );

      setState(() => _uploadedFiles.clear());
      await _fetchServerFiles();

      if (!isDraft) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UploadedFilesScreen(
              hwAssignId: widget.hwAssignId,
              hwType: safeHwType,
              studId: widget.studId,
              batch: widget.batch,
              weekId: widget.weekId,
              dueDate: widget.dueDate,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed: $e')),
      );
    }
  }

  void _showTurnInConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Turn In Homework?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'Do you want to Turn In the homework?\n\nAfter turn in no modifications will be allowed!',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performTurnIn();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Turn In', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performTurnIn() async {
    setState(() => _isTurningIn = true);
    try {
      final safeHwType =
      widget.hwType.trim().isEmpty ? 'Regular Homework' : widget.hwType.trim();

      final uploadedFiles = await apiService.fetchUploadedHomeworkFiles(
        hwAssignId: widget.hwAssignId,
        hwType: safeHwType,
      );

      if (uploadedFiles.isEmpty) {
        _showSnackBar('❌ No uploaded files found to turn in!');
        return;
      }

      final uploadedFileNames =
      uploadedFiles.map((f) => f['file_name'].toString()).toList();

      final response = await apiService.turnInHomework(
        hwType: safeHwType,
        batch: widget.batch,
        weekId: widget.weekId,
        studId: widget.studId,
        hwAssignId: widget.hwAssignId,
        userId: apiService.currentUserId ?? 0,
        uploadedFiles: uploadedFileNames,
      );

      if (response['success'] == true) {
        _showSnackBar('✅ ${response['message']}');
        await Future.delayed(const Duration(seconds: 3));
        await apiService.fetchStudentHomeWork();

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
      _showSnackBar('❌ Failed to Turn In: $e');
    } finally {
      if (mounted) setState(() => _isTurningIn = false);
    }
  }

  // ------------------- MAIN BUILD (UI IMPROVED, LOGIC SAME) -------------------
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFE9F0FF),
        appBar: AppBar(
          elevation: 0,
          title: const Text('Homework Upload',
              style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.appbarblue,
          centerTitle: true,
          foregroundColor: Colors.white,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1.0),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFCAC5C5)),
          ),
        ),
        body: Column(
          children: [
            // ✅ Rounded Segmented Tabs (no functionality change)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Expanded(
                      child: _segTab(
                        title: 'Upload File',
                        active: _currentTab == 0,
                        onTap: () => _tabController.animateTo(0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _segTab(
                        title: 'Record Audio',
                        active: _currentTab == 1,
                        onTap: () => _tabController.animateTo(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildUploadTab(),
                  _buildRecordTab(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomActionBar(),
      ),
    );
  }

  Widget _segTab({
    required String title,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
            colors: [Color(0xFF0A3D91), Color(0xFF1565C0)],
          )
              : null,
          color: active ? null : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : const Color(0xFF757575),
          ),
        ),
      ),
    );
  }
}
