import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'uploaded_file.dart';

class UploadsProvider extends ChangeNotifier {
  static const _cacheKey = 'local_uploaded_files';
  final List<UploadedFile> _files = [];

  List<UploadedFile> get files => List.unmodifiable(_files);
  bool _loading = false;
  bool get loading => _loading;

  UploadsProvider() {
    _loadFromPrefs();
  }

  // Add file locally (call after a successful upload to server)
  Future<void> addLocalFile(UploadedFile file) async {
    if (_files.any((f) => f.id == file.id)) return;
    _files.insert(0, file); // newest first
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> removeLocalFileById(String id) async {
    _files.removeWhere((f) => f.id == id);
    await _saveToPrefs();
    notifyListeners();
  }
  // Merge server files with local cache (deduplicates by id/name)
  Future<void> mergeServerFiles(List<UploadedFile> serverFiles) async {
    final serverIds = serverFiles.map((f) => f.id).toSet();

    // Keep local files that aren't in server (offline-only)
    final localOnly = _files.where((f) => !serverIds.contains(f.id)).toList();

    // Combine server files + local-only files (server files take precedence)
    _files.clear();
    _files.addAll(serverFiles);
    _files.addAll(localOnly);

    await _saveToPrefs();
    notifyListeners();
  }

  // This accepts a list of filenames from server and merges (create UploadedFile objects)
  Future<void> mergeServerFileNames(List<String> names) async {
    final serverFiles = names.map((name) => UploadedFile(
      id: name, // or use UUID or server id if available
      name: name,
      url: '', // server URL if known; keep empty if not
      uploadedAt: DateTime.now(), // or parse server date if available
    )).toList();
    await mergeServerFiles(serverFiles); // reuse existing merge function you already had
  }

  // Fetch from server and merge (don't clear local!)
  Future<void> fetchAndMergeFromServer({required String url}) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await http.get(Uri.parse(url)); // adapt to your API
      if (res.statusCode == 200) {
        final List<dynamic> list = json.decode(res.body);
        final serverFiles = list.map((e) => UploadedFile.fromJson(e)).toList();
        await mergeServerFiles(serverFiles);
      } else {
        // handle non-200 as needed
      }
    } catch (e) {
      // handle error
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Persistence
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(_files.map((f) => f.toJson()).toList());
    await prefs.setString(_cacheKey, jsonStr);
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_cacheKey);
    if (jsonStr == null) return;
    try {
      final List parsed = json.decode(jsonStr);
      _files.clear();
      _files.addAll(parsed.map((e) => UploadedFile.fromJson(e)).toList());
      notifyListeners();
    } catch (e) {
      // ignore parse errors
    }
  }

  // Optionally clear local store
  Future<void> clearLocal() async {
    _files.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    notifyListeners();
  }
}
