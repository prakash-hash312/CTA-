// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dropdownmodel.dart';

import '../models/usermodel.dart';

// --- API ENDPOINTS ---
const String kBaseUrl = 'https://www.ivpsemi.in/CTA_Mob/v1';
const String kLoginUrl = '$kBaseUrl/Login';
const String kViewProfileUrl = '$kBaseUrl/ViewProfile';
const String kModifyProfileUrl = '$kBaseUrl/ModifyProfile';
const String kChangePasswordUrl = '$kBaseUrl/ChangePassword';
const String kMenuUrl = '$kBaseUrl/Menu';
const String kThemeListUrl = '$kBaseUrl/Theme';
const String kGenderListUrl = '$kBaseUrl/Gender';
const String kStateListUrl = '$kBaseUrl/State';
const String kStudentHomeworkUrl = '$kBaseUrl/StudentHomework';
const String kStudentHomeWorkUrl = '$kBaseUrl/StudentHomeWork';
const String kSyllabusHwBaseUrl = 'https://www.ivpsemi.in/CTA_Mob/api/HW';

class ApiService {
  final Dio _dio = Dio();
  String? _authToken;
  String? _cookieHeader;
  int? _currentUserId;
  int? _currentEmpId;
  int? _currentStudId;
  String? _currentUsername;
  String? _currentLoginEmail;

  void setAuthToken(String? token) {
    _authToken = token;
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  void setCookieHeader(String? cookie) {
    _cookieHeader = cookie;
    if (cookie != null && cookie.isNotEmpty) {
      _dio.options.headers['Cookie'] = cookie;
    } else {
      _dio.options.headers.remove('Cookie');
    }
  }

  bool get isLoggedIn => _currentUserId != null;
  String? get currentUsername => _currentUsername;
  String? get currentLoginEmail => _currentLoginEmail;

  void setCurrentUserId(int userId) {
    if (_currentUserId != null && _currentUserId != userId) {
      // 🔑 FIX: Reset stud_id when user changes so stale IDs from previous
      // login don't bleed into the new session.
      _currentStudId = null;
    }
    _currentUserId = userId;
  }

  void setCurrentEmpId(int? empId) => _currentEmpId = empId;

  Future<void> setCurrentStudentId(int? studId) async {
    final next = (studId != null && studId > 0) ? studId : null;
    if (_currentStudId == next) return;
    _currentStudId = next;
    await _saveSession();
    debugPrint('👤 [setCurrentStudentId] stud_id=$_currentStudId');
  }

  int? get currentEmpId => _currentEmpId;
  int? get currentStudentId => _currentStudId;
  int? get currentUserId => _currentUserId;

  List<Map<String, dynamic>> _mapRows(dynamic responseData) {
    dynamic rows = responseData;
    if (responseData is Map<String, dynamic>) {
      rows = responseData['value'] ??
          responseData['tblData'] ??
          responseData['data'] ??
          responseData['rows'] ??
          responseData['items'] ??
          responseData['result'] ??
          responseData['Result'] ??
          responseData['table'] ??
          responseData['Table'] ??
          responseData['tbl'] ??
          responseData['Tbl'];

      // If backend returns a non-standard wrapper, try to locate the first
      // list-like value anywhere in the payload (some deployments nest it).
      rows ??= _deepFindFirstList(responseData);
    }
    if (rows is List) {
      try {
        return rows.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {
        // If list elements are not maps, treat it as no rows.
        return [];
      }
    }
    return [];
  }

  List? _deepFindFirstList(dynamic value, {int depth = 0}) {
    if (depth > 5 || value == null) return null;
    if (value is List) return value;
    if (value is Map) {
      // Prefer a list that looks like a list of rows (list of maps).
      for (final v in value.values) {
        if (v is List && v.isNotEmpty && v.first is Map) return v;
      }
      // Otherwise, recurse to find any list.
      for (final v in value.values) {
        final found = _deepFindFirstList(v, depth: depth + 1);
        if (found != null) return found;
      }
    }
    return null;
  }

  int _readInt(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      final parsed = int.tryParse('${value ?? ''}');
      if (parsed != null && parsed > 0) return parsed;
    }
    for (final entry in row.entries) {
      for (final key in keys) {
        if (entry.key.toLowerCase().contains(key.toLowerCase())) {
          final parsed = int.tryParse('${entry.value}');
          if (parsed != null && parsed > 0) return parsed;
        }
      }
    }
    return 0;
  }

  // 🔑 FIX: Improved profile resolution — tries ALL possible stud_id key
  // variants and also checks every field in the row whose value looks like
  // an integer, so it won't miss the field regardless of naming convention.
  Future<int?> _resolveStudentIdFromProfile() async {
    if (_currentUserId == null || _currentUserId! <= 0) return null;
    if (_currentLoginEmail == null || _currentLoginEmail!.trim().isEmpty) {
      return null;
    }

    // 🔑 FIX: Try multiple query parameter combinations for ViewProfile.
    // Some accounts return 500 when empid is passed because their empid in
    // the DB doesn't match the userId from the login response. We try:
    //   1. empid + email  (original)
    //   2. email only     (no empid — backend may look up by email alone)
    //   3. empid=0 + email (some backends treat 0 as "lookup by email")
    //   4. user_id + email (alternate param name)
    final profileQueryCandidates = <Map<String, dynamic>>[
      {'empid': _currentUserId, 'email': _currentLoginEmail},
      {'email': _currentLoginEmail},
      {'empid': 0, 'email': _currentLoginEmail},
      {'user_id': _currentUserId, 'email': _currentLoginEmail},
    ];

    dynamic profileResponseData;
    for (final query in profileQueryCandidates) {
      try {
        debugPrint('🔍 [resolveStudId] Trying ViewProfile with params: $query');
        final resp = await _dio.get(
          kViewProfileUrl,
          queryParameters: query,
          options: Options(
            headers: {'Content-Type': 'application/json'},
            followRedirects: true,
            // 🔑 Accept any status so we can check it ourselves instead of throwing
            validateStatus: (status) => true,
          ),
        );
        debugPrint('🔍 [resolveStudId] Status: ${resp.statusCode}');
        if (resp.statusCode != null &&
            resp.statusCode! >= 200 &&
            resp.statusCode! < 300) {
          profileResponseData = resp.data;
          debugPrint('✅ [resolveStudId] Got valid response with query: $query');
          break;
        } else {
          debugPrint(
              '⚠️ [resolveStudId] Non-2xx status ${resp.statusCode} for query $query, trying next...');
        }
      } catch (e) {
        debugPrint('⚠️ [resolveStudId] Query $query failed: $e');
      }
    }

    if (profileResponseData == null) {
      debugPrint('❌ [resolveStudId] All ViewProfile query variants failed.');
      return null;
    }

    try {
      final responseData = profileResponseData;
      debugPrint('🔍 [resolveStudId] Raw profile response: $responseData');

      final rows = _mapRows(responseData);

      // Also try direct list response
      List<Map<String, dynamic>> allRows = [];
      if (rows.isNotEmpty) {
        allRows = rows;
      } else if (responseData is List && responseData.isNotEmpty) {
        allRows =
            responseData.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      if (allRows.isNotEmpty) {
        final row = allRows.first;
        debugPrint('🔍 [resolveStudId] Profile row keys: ${row.keys.toList()}');
        debugPrint('🔍 [resolveStudId] Profile row: $row');

        // Try explicit known keys first
        final sid = _readInt(row, [
          'stud_id',
          'Stud_id',
          'StudId',
          'student_id',
          'StudentId',
          'studentid',
          'studid',
          'user_id',
          'UserId',
          'userid',
        ]);

        if (sid > 0) {
          debugPrint('✅ [resolveStudId] Found stud_id=$sid via known key');
          _currentStudId = sid;
          await _saveSession();
          return _currentStudId;
        }

        // 🔑 FIX: Fallback — scan ALL fields for the first positive integer
        // that could be a student/user identifier. This catches any
        // non-standard key names the backend might use.
        for (final entry in row.entries) {
          final key = entry.key.toLowerCase();
          if (key.contains('stud') ||
              key.contains('student') ||
              key.contains('user') ||
              key.contains('id')) {
            final parsed = int.tryParse('${entry.value ?? ''}');
            if (parsed != null && parsed > 0) {
              debugPrint(
                  '✅ [resolveStudId] Found id=$parsed via scanned key "${entry.key}"');
              _currentStudId = parsed;
              await _saveSession();
              return _currentStudId;
            }
          }
        }

        // Try UserProfile model as last resort
        final profile = UserProfile.fromJson(row);
        final profileStudentId = profile.studentId;
        if (profileStudentId > 0) {
          debugPrint(
              '✅ [resolveStudId] Found stud_id=$profileStudentId via UserProfile model');
          _currentStudId = profileStudentId;
          await _saveSession();
          return _currentStudId;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [resolveStudId] Parse exception: $e');
    }

    return null;
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', _currentUserId ?? 0);
    await prefs.setInt('emp_id', _currentEmpId ?? 0);
    await prefs.setInt('stud_id', _currentStudId ?? 0);
    await prefs.setString('username', _currentUsername ?? '');
    await prefs.setString('login_email', _currentLoginEmail ?? '');
  }

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('user_id');
    _currentEmpId = prefs.getInt('emp_id');
    _currentStudId = prefs.getInt('stud_id');
    _currentUsername = prefs.getString('username');
    _currentLoginEmail = prefs.getString('login_email');
    final savedToken = prefs.getString('auth_token');
    final savedCookie = prefs.getString('cookie');
    if (savedToken != null && savedToken.isNotEmpty) setAuthToken(savedToken);
    if (savedCookie != null && savedCookie.isNotEmpty) {
      setCookieHeader(savedCookie);
    }
    debugPrint(
        '🔹 Session loaded: user_id=$_currentUserId, stud_id=$_currentStudId, username=$_currentUsername');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _currentUserId = null;
    _currentEmpId = null;
    _currentStudId = null;
    _currentUsername = null;
    _currentLoginEmail = null;
    debugPrint('🚪 User logged out. Session cleared.');
  }

  /// Resolve and persist the student id used by syllabus endpoints.
  Future<int?> ensureCurrentStudentId() async {
    if (_currentStudId != null && _currentStudId! > 0) {
      debugPrint('✅ [ensureStudId] Already have stud_id=$_currentStudId');
      return _currentStudId;
    }
    if (_currentUserId == null || _currentUserId! <= 0) return null;

    debugPrint(
        '🔍 [ensureStudId] Resolving stud_id for user_id=$_currentUserId...');

    // Step 1: Try ViewProfile
    final fromProfile = await _resolveStudentIdFromProfile();
    if (fromProfile != null && fromProfile > 0) {
      debugPrint('✅ [ensureStudId] Resolved via profile: $fromProfile');
      return fromProfile;
    }

    // Step 2: Try StudentHomeWork with user_id / emp_id as stud_id candidates
    // 🔑 FIX: Do NOT fall back to _currentUserId as stud_id unless the
    // homework API actually returns rows for that id. Many users have a
    // different stud_id than their user/emp id.
    final candidates = <int>{
      if (_currentUserId != null && _currentUserId! > 0) _currentUserId!,
      if (_currentEmpId != null && _currentEmpId! > 0) _currentEmpId!,
    }.toList();

    for (final candidate in candidates) {
      try {
        final rows = await fetchStudentHomeWork(studId: candidate);
        if (rows.isNotEmpty) {
          // Try to read the actual stud_id from the response row
          final sid = _readInt(rows.first, [
            'stud_id',
            'Stud_id',
            'student_id',
            'StudentID',
            'StudId',
            'user_id',
          ]);
          if (sid > 0) {
            debugPrint(
                '✅ [ensureStudId] Resolved stud_id=$sid from homework response');
            _currentStudId = sid;
            await _saveSession();
            return _currentStudId;
          }
          // Rows exist but no explicit stud_id field — use the candidate that worked
          debugPrint(
              '✅ [ensureStudId] Homework returned rows for candidate=$candidate, using as stud_id');
          _currentStudId = candidate;
          await _saveSession();
          return _currentStudId;
        }
      } catch (e) {
        debugPrint(
            '⚠️ [ensureStudId] Homework fetch failed for candidate=$candidate: $e');
      }
    }

    // Step 3: Retry profile one more time (network might have been slow)
    final profileRetry = await _resolveStudentIdFromProfile();
    if (profileRetry != null && profileRetry > 0) {
      return profileRetry;
    }

    // 🔑 FIX: Do NOT silently set stud_id = user_id as last resort.
    // Keep it null so the caller knows resolution truly failed and can
    // surface a meaningful error to the user instead of using a wrong ID.
    debugPrint(
        '❌ [ensureStudId] Could not resolve stud_id for user_id=$_currentUserId');
    return null;
  }

  Future<int?> resolveActiveStudentId() async {
    final resolved = await ensureCurrentStudentId();
    if (resolved != null && resolved > 0) return resolved;
    if (_currentStudId != null && _currentStudId! > 0) return _currentStudId;
    // 🔑 FIX: Only fall back to user_id if we genuinely have nothing else.
    // Log a warning so it's visible during debugging.
    if (_currentUserId != null && _currentUserId! > 0) {
      debugPrint(
          '⚠️ [resolveActiveStudId] Falling back to user_id=$_currentUserId as stud_id — may be incorrect');
      return _currentUserId;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchCurrentStudentHomeWork() async {
    final candidates = <int>{
      if (_currentStudId != null && _currentStudId! > 0) _currentStudId!,
      if (_currentUserId != null && _currentUserId! > 0) _currentUserId!,
      if (_currentEmpId != null && _currentEmpId! > 0) _currentEmpId!,
    }.toList();

    if (candidates.isEmpty) {
      final resolved = await resolveActiveStudentId();
      if (resolved != null && resolved > 0) {
        candidates.add(resolved);
      }
    }

    Object? lastError;
    for (final candidate in candidates) {
      try {
        final rows = await fetchStudentHomeWork(studId: candidate);
        if (rows.isNotEmpty) return rows;
      } catch (e) {
        lastError = e;
      }
    }

    final profileStudId = await _resolveStudentIdFromProfile();
    if (profileStudId != null && profileStudId > 0) {
      try {
        final rows = await fetchStudentHomeWork(studId: profileStudId);
        if (rows.isNotEmpty) return rows;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) {
      debugPrint(
          '❌ Failed to fetch homework after trying all candidates: $lastError');
    }
    return [];
  }

  Future<Response> _getResponse(String url,
      {Map<String, dynamic>? queryParameters}) async {
    try {
      debugPrint('📡 GET Request: $url');
      debugPrint('🧾 Query Params: $queryParameters');

      final response = await _dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      debugPrint('✅ Response Code: ${response.statusCode}');
      debugPrint('✅ Response Data: ${response.data}');
      return response;
    } on DioException catch (e) {
      debugPrint('❌ Dio GET Error on $url: ${e.message}');
      if (e.response != null) debugPrint('Response: ${e.response}');
      throw Exception('Failed to load data: ${e.message}');
    }
  }

  Future<dynamic> _get(String url,
      {Map<String, dynamic>? queryParameters}) async {
    try {
      debugPrint('🌐 GET Request: $url');
      debugPrint('🧾 Query Params: $queryParameters');

      final response = await _dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      debugPrint('✅ Response Code: ${response.statusCode}');
      debugPrint('✅ Response Data: ${response.data}');
      return response.data;
    } on DioException catch (e) {
      debugPrint('❌ Dio GET Error on $url: ${e.message}');
      if (e.response != null) debugPrint('Response: ${e.response}');
      throw Exception('Failed to load data: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> _post(
      String url, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        url,
        data: data,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      return response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data);
    } on DioException catch (e) {
      debugPrint(
          'POST Error on $url: ${e.response?.statusCode} - ${e.message}');
      throw Exception(
          'Failed to process request: ${e.response?.data?['message'] ?? e.message}');
    }
  }

  // ----------------- API CALLS -----------------

  /// 1️⃣ LOGIN (GET)
  Future<UserProfile> login(String username, String password) async {
    // 🔑 FIX: Clear any stale session data before logging in a new user.
    // Without this, stud_id from a previous login persists and is used
    // for the new user — causing wrong homework data or no data at all.
    _currentUserId = null;
    _currentEmpId = null;
    _currentStudId = null;
    _currentUsername = null;
    _currentLoginEmail = null;

   final responseData = await _get(kLoginUrl, queryParameters: {
  'empno': username,
  'password': password,
});

// TEMPORARY DEBUG
if (responseData is List && responseData.isNotEmpty) {
  final firstItem = responseData[0] as Map<String, dynamic>;
  debugPrint('🔑 LOGIN FIELDS START');
  firstItem.forEach((key, value) {
    debugPrint('🔑 FIELD >>> $key = $value');
  });
  debugPrint('🔑 LOGIN FIELDS END');
}
   
   

    if (responseData is List && responseData.isNotEmpty) {
      final user = UserProfile.fromJson(responseData[0]);
      debugPrint(
          '🔑 [login] userId=${user.userId}, studentId=${user.studentId}, email=${user.userEmailId}');

      setCurrentUserId(user.userId);
      _currentEmpId = user.userId;
      // 🔑 FIX: Only set stud_id from the login response if it is actually
      // a valid positive integer. Do not silently fall back to user_id here;
      // ensureCurrentStudentId() will do proper resolution afterwards.
      _currentStudId = (user.studentId > 0) ? user.studentId : null;
      _currentUsername = user.userName ?? username;
      _currentLoginEmail =
          user.userEmailId.isNotEmpty ? user.userEmailId : username;

      debugPrint(
          '🔑 [login] After parse: stud_id=$_currentStudId, emp_id=$_currentEmpId');

      // Always attempt to resolve via profile if stud_id is missing
      if (_currentStudId == null || _currentStudId! <= 0) {
        debugPrint(
            '🔍 [login] stud_id missing from login response, resolving via profile...');
        await _resolveStudentIdFromProfile();
      }

      // Final resolution attempt
      await ensureCurrentStudentId();

      debugPrint(
          '✅ [login] Final stud_id=$_currentStudId for user=$_currentLoginEmail');

      await _saveSession();
      return user;
    }
    throw Exception('Login failed: invalid credentials or empty response.');
  }

  /// 2️⃣ VIEW PROFILE (GET)
  Future<UserProfile> viewProfile() async {
    if (_currentUserId == null) throw Exception('User not logged in.');
    if (_currentLoginEmail == null || _currentLoginEmail!.isEmpty) {
      throw Exception('Login email not available for ViewProfile API.');
    }
    debugPrint('🔹 Fetching profile for empid=$_currentUserId');

    final responseData = await _get(kViewProfileUrl, queryParameters: {
      'empid': _currentUserId,
      'email': _currentLoginEmail,
    });

    debugPrint('✅ Response: $responseData');

    if (responseData is List && responseData.isNotEmpty) {
      return UserProfile.fromJson(responseData[0]);
    }
    throw Exception('Failed to load profile data.');
  }

  /// 3️⃣ MODIFY PROFILE (POST)
  Future<String> modifyProfile(Map<String, dynamic> requestData) async {
    if (_currentUserId == null) throw Exception('User not logged in.');
    requestData['user_id'] = _currentUserId;

    final response = await _post(kModifyProfileUrl, requestData);

    if (response['success'] == true) {
      return response['message'] ?? 'Profile updated successfully!';
    }
    throw Exception('Profile update failed: ${response['message']}');
  }

  /// 4️⃣ CHANGE PASSWORD (POST)
  Future<String> changePassword(
    String newPwd,
    String confirmPwd,
    String oldPwd,
  ) async {
    if (_currentUserId == null) throw Exception('User not logged in.');

    final requestData = {
      "new_pwd": newPwd,
      "confirm_pwd": confirmPwd,
      "old_pwd": oldPwd,
      "is_parent2": "No",
      "user_id": _currentUserId,
    };

    try {
      debugPrint('🔐 Sending change password request...');

      final response = await _post(kChangePasswordUrl, requestData);

      debugPrint('✅ Password API response: $response');

      if (response is Map<String, dynamic>) {
        if (response['success'] == true || response['Success'] == true) {
          return response['message'] ??
              response['Message'] ??
              'Password changed successfully!';
        } else {
          throw Exception(
              response['message'] ?? response['Message'] ?? 'Password change failed.');
        }
      } else {
        throw Exception('Unexpected response format from server.');
      }
    } on Exception catch (e) {
      final err = e.toString();
      if (err.contains('404')) {
        throw Exception(
            'Password change service not found (404). Please check API path.');
      } else if (err.contains('Failed host lookup')) {
        throw Exception('No internet connection.');
      } else if (err.contains('timeout')) {
        throw Exception('Server timeout. Try again later.');
      } else {
        rethrow;
      }
    }
  }

  /// 5️⃣ MENU LIST (GET)
  Future<List<MenuItem>> fetchMenuList({String? email}) async {
    final empId = _currentEmpId ?? _currentUserId;
    if (empId == null) throw Exception('User not logged in.');
    final resolvedEmail = (email != null && email.isNotEmpty)
        ? email
        : (_currentLoginEmail ?? '');
    if (resolvedEmail.isEmpty) {
      throw Exception('Login email not available for Menu API.');
    }
    final responseData = await _get(kMenuUrl, queryParameters: {
      'empid': empId,
      'email': resolvedEmail,
    });
    if (responseData is List) {
      return responseData.map((json) => MenuItem.fromJson(json)).toList();
    }
    return [];
  }

  /// 6️⃣ THEME LIST (GET)
  Future<List<ThemeItem>> fetchThemeList() async {
    final responseData = await _get(kThemeListUrl);
    if (responseData is List) {
      return responseData.map((json) => ThemeItem.fromJson(json)).toList();
    }
    return [];
  }

  /// 7️⃣ GENDER LIST (GET)
  Future<List<GenderItem>> fetchGenderList() async {
    final responseData = await _get(kGenderListUrl);
    if (responseData is List) {
      return responseData.map((json) => GenderItem.fromJson(json)).toList();
    }
    return [];
  }

  /// 8️⃣ STATE LIST (GET)
  Future<List<StateItem>> fetchStateList() async {
    final responseData = await _get(kStateListUrl);
    if (responseData is List) {
      return responseData.map((json) => StateItem.fromJson(json)).toList();
    }
    return [];
  }

  /// 9️⃣ STUDENT HOMEWORK API
  Future<List<Map<String, dynamic>>> fetchStudentHomeWork({int? studId}) async {
    const String url = 'https://www.ivpsemi.in/CTA_Mob/v1/StudentHomeWork';
    final resolvedStudId = studId ?? _currentStudId ?? _currentUserId;
    if (resolvedStudId == null || resolvedStudId <= 0) {
      throw Exception('Student ID not available.');
    }

    debugPrint('📚 [fetchStudentHomeWork] Trying stud_id=$resolvedStudId');

    final queryCandidates = <Map<String, dynamic>>[
      {'stud_id': resolvedStudId},
      {'Stud_id': resolvedStudId},
      {'StudId': resolvedStudId},
      {'student_id': resolvedStudId},
      {'StudentId': resolvedStudId},
      {'user_id': resolvedStudId},
    ];

    Object? lastError;
    for (final query in queryCandidates) {
      try {
        final responseData = await _get(url, queryParameters: query);
        final rows = _mapRows(responseData);
        if (rows.isNotEmpty) {
          debugPrint(
              '✅ [fetchStudentHomeWork] Got ${rows.length} rows with query $query');
          final sid = _readInt(rows.first, [
            'stud_id',
            'Stud_id',
            'StudId',
            'student_id',
            'StudentId',
          ]);
          if (sid > 0) {
            _currentStudId = sid;
          } else if (_currentStudId == null || _currentStudId! <= 0) {
            _currentStudId = resolvedStudId;
          }
          return rows;
        }
      } catch (e) {
        lastError = e;
        debugPrint('⚠️ Homework fetch failed for query $query: $e');
      }
    }

    if (lastError != null) {
      debugPrint(
          '❌ Homework fetch error after all query variants: $lastError');
    }
    return [];
  }

  /// 🔟 SYLLABUS GRADE INFO (GET)
  Future<List<Map<String, dynamic>>> fetchSyllabusGradeInfo({
    required int studId,
  }) async {
    const String url = '$kSyllabusHwBaseUrl/GradeInfo';
    final queryCandidates = <Map<String, dynamic>>[
      {'stud_id': studId},
      {'Stud_id': studId},
      {'student_id': studId},
      {'StudentId': studId},
      {'StudId': studId},
      {'StudID': studId},
      {'studentid': studId},
      {'studid': studId},
      {'user_id': studId},
      {'UserId': studId},
    ];
    for (final query in queryCandidates) {
      final responseData = await _get(url, queryParameters: query);
      final rows = _mapRows(responseData);
      if (rows.isNotEmpty) {
        return rows;
      }
    }
    return [];
  }

  /// 1️⃣1️⃣ SYLLABUS TOPIC INFO (GET)
  Future<List<Map<String, dynamic>>> fetchSyllabusTopicInfo({
    required int mainId,
    required int studId,
  }) async {
    const String url = '$kSyllabusHwBaseUrl/TopicInfo';
    final queryCandidates = <Map<String, dynamic>>[
      // Some deployments use MainTopicID / main_topic_id naming.
      {'MainTopicID': mainId, 'stud_id': studId},
      {'MainTopicID': mainId, 'Stud_id': studId},
      {'MainTopicID': mainId, 'StudId': studId},
      {'MainTopicID': mainId, 'StudID': studId},
      {'main_topic_id': mainId, 'stud_id': studId},
      {'main_topic_id': mainId, 'Stud_id': studId},
      {'main_topic_id': mainId, 'StudId': studId},
      {'main_topic_id': mainId, 'StudID': studId},
      // Backend appears to accept `main_id` and may require `stud_id`.
      {'main_id': mainId, 'stud_id': studId},
      {'main_id': mainId, 'Stud_id': studId},
      {'main_id': mainId, 'StudId': studId},
      {'main_id': mainId, 'StudID': studId},
      {'Main_id': mainId, 'stud_id': studId},
      {'Main_id': mainId, 'Stud_id': studId},
      {'Main_id': mainId, 'StudId': studId},
      {'Main_id': mainId, 'StudID': studId},
      // Fallback: some deployments don't require stud_id.
      {'MainTopicID': mainId},
      {'main_topic_id': mainId},
      {'main_id': mainId},
      {'Main_id': mainId},
    ];
    for (final query in queryCandidates) {
      final responseData = await _get(url, queryParameters: query);
      final rows = _mapRows(responseData);
      if (rows.isNotEmpty) {
        return rows;
      }
    }
    return [];
  }

  /// 1️⃣2️⃣ SYLLABUS SUBTOPIC INFO (GET)
  Future<List<Map<String, dynamic>>> fetchSyllabusSubTopicInfo({
    required int topicId,
  }) async {
    const String url = '$kSyllabusHwBaseUrl/SubTopicInfo';
    final queryCandidates = <Map<String, dynamic>>[
      {'topic_id': topicId},
      {'Topic_id': topicId},
      {'topicId': topicId},
      {'TopicID': topicId},
      {'subtopic_id': topicId},
    ];
    for (final query in queryCandidates) {
      final responseData = await _get(url, queryParameters: query);
      final rows = _mapRows(responseData);
      if (rows.isNotEmpty) {
        return rows;
      }
    }
    return [];
  }

  /// 1️⃣3️⃣ SYLLABUS CONTENT (GET)
  Future<List<Map<String, dynamic>>> fetchSyllabusContent({
    required int subtopicId,
  }) async {
    const String url = '$kSyllabusHwBaseUrl/Content';
    final queryCandidates = <Map<String, dynamic>>[
      {'Subtopic_id': subtopicId},
      {'subtopic_id': subtopicId},
      {'SubSubTopicID': subtopicId},
      {'sub_sub_topic_id': subtopicId},
      {'topic_id': subtopicId},
      {'TopicID': subtopicId},
    ];

    for (final query in queryCandidates) {
      final response = await _getResponse(url, queryParameters: query);
      final rows = _mapRows(response.data);
      if (rows.isNotEmpty) {
        return rows;
      }
    }

    return [];
  }

  /// 🔟 HOMEWORK DETAIL API
  Future<List<Map<String, dynamic>>> fetchHomeworkDetail({
    required int hwContentId,
    required String hwType,
  }) async {
    const String url = 'https://www.ivpsemi.in/CTA_Mob/v1/GetHwContent';
    try {
      final responseData = await _get(url, queryParameters: {
        'hw_content_id': hwContentId,
        'hw_type': hwType,
      });

      debugPrint('📘 Homework Detail API response: $responseData');

      final rows = _mapRows(responseData);
      if (rows.isNotEmpty) {
        return rows;
      } else {
        debugPrint('⚠️ Unexpected detail format: $responseData');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Homework detail fetch error: $e');
      throw Exception('Failed to fetch homework details');
    }
  }

  /// 🧩 UPLOAD HOMEWORK FILES
  Future<Map<String, dynamic>> uploadHomeworkFiles({
    required int studentId,
    required int batch,
    required int weekId,
    required String homeworkType,
    required List<File> files,
  }) async {
    const String url = 'https://www.ivpsemi.in/CTA_Mob/v1/FileUpload';

    try {
      final formData = FormData();

      for (var file in files) {
        formData.files.add(MapEntry(
          'file',
          await MultipartFile.fromFile(
            file.path,
            filename: file.path.split('/').last,
          ),
        ));
      }

      formData.fields.addAll([
        MapEntry('StudentId', studentId.toString()),
        MapEntry('Batch', batch.toString()),
        MapEntry('WeekId', weekId.toString()),
        MapEntry('HomeworkType', homeworkType.trim()),
      ]);

      debugPrint('📤 Uploading files → $url');
      debugPrint('🧾 Fields: ${formData.fields}');
      debugPrint('📦 Files count: ${files.length}');

      final response = await _dio.post(
        url,
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progress = (sent / total * 100).toStringAsFixed(1);
            debugPrint('⏳ Upload progress: $progress%');
          }
        },
      );

      debugPrint('✅ Upload Response: ${response.data}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data;
      } else {
        throw Exception(response.data['message'] ?? 'Upload failed.');
      }
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      throw Exception('Failed to upload files: $e');
    }
  }

  /// 🧾 GET UPLOADED HOMEWORK FILES
  Future<List<Map<String, dynamic>>> fetchUploadedHomeworkFiles({
    required int hwAssignId,
    required String hwType,
    int? studId,
  }) async {
    const String baseUrl =
        'https://www.ivpsemi.in/CTA_Mob/v1/GetHwUploadedFiles';
    try {
      final resolvedStudId = studId ?? _currentStudId;
      final safeHwType =
          hwType.trim().isEmpty ? 'Regular Homework' : hwType.trim();
      final queryCandidates = <Map<String, dynamic>>[
        if (resolvedStudId != null && resolvedStudId > 0)
          {
            'hw_assign_id': hwAssignId,
            'hw_type': safeHwType,
            'stud_id': resolvedStudId,
          },
        if (resolvedStudId != null && resolvedStudId > 0)
          {
            'hw_assign_id': hwAssignId,
            'hw_type': safeHwType,
            'StudId': resolvedStudId,
          },
        if (resolvedStudId != null && resolvedStudId > 0)
          {
            'hw_assign_id': hwAssignId,
            'hw_type': safeHwType,
            'student_id': resolvedStudId,
          },
        {
          'hw_assign_id': hwAssignId,
          'hw_type': safeHwType,
        },
      ];

      debugPrint('📥 [GetUploadedFiles] Fetching uploaded files...');
      debugPrint('🔹 hw_assign_id: $hwAssignId');
      debugPrint('🔹 hw_type: $hwType');

      for (final query in queryCandidates) {
        final response = await _dio.get(
          baseUrl,
          queryParameters: query,
          options: Options(
            headers: {'Content-Type': 'application/json'},
            validateStatus: (status) => true,
          ),
        );

        debugPrint('📥 [GetUploadedFiles] Query: $query');
        debugPrint('📥 [GetUploadedFiles] Status: ${response.statusCode}');
        debugPrint('📥 [GetUploadedFiles] Response: ${response.data}');

        if (response.statusCode == 200) {
          if (response.data is List) {
            debugPrint(
                '✅ [GetUploadedFiles] Files received: ${response.data.length}');
            return List<Map<String, dynamic>>.from(response.data);
          }

          if (response.data is Map<String, dynamic>) {
            final data = Map<String, dynamic>.from(response.data);
            final listSection = data['data'] ??
                data['files'] ??
                data['uploadedFiles'] ??
                data['result'];

            if (listSection is List) {
              final files = listSection
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();
              debugPrint(
                  '✅ [GetUploadedFiles] Files received: ${files.length}');
              return files;
            }

            if (data['success'] == true) {
              return [];
            }

            throw Exception(data['message'] ?? 'Unexpected response format');
          }
        } else if (response.statusCode == 204) {
          debugPrint('ℹ️ [GetUploadedFiles] No files found for this homework.');
          return [];
        }
      }

      throw Exception('Unknown error');
    } catch (e) {
      debugPrint('❌ [GetUploadedFiles] Error: $e');
      throw Exception('Failed to fetch uploaded homework files: $e');
    }
  }

  Future<String> draftHomework({
    required String hwType,
    required int batch,
    required int weekId,
    required int studId,
    required int hwAssignId,
    required int userId,
    required List<String> uploadedFiles,
  }) async {
    const url = 'https://www.ivpsemi.in/CTA_Mob/v1/DraftHomework';
    final data = {
      "HwType": hwType,
      "Batch": batch,
      "WeekId": weekId,
      "StudId": studId,
      "HwAssignId": hwAssignId,
      "UserId": userId,
      "UploadedFiles": uploadedFiles.map((f) => {"FileName": f}).toList(),
    };

    debugPrint('📝 [DraftHomework] Sending draft...');
    debugPrint('📦 Data: $data');

    try {
      final response = await _post(url, data);
      debugPrint('✅ [DraftHomework] Response: $response');

      if (response['success'] == true) {
        debugPrint('✅ [DraftHomework] Draft saved successfully.');
        return response['message'] ?? 'Draft saved successfully!';
      } else {
        debugPrint('❌ [DraftHomework] Failed: ${response['message']}');
        throw Exception(response['message'] ?? 'Failed to draft homework.');
      }
    } catch (e) {
      debugPrint('❌ [DraftHomework] Exception: $e');
      throw Exception('Failed to draft homework: $e');
    }
  }

  Future<Map<String, dynamic>> turnInHomework({
    required String hwType,
    required int batch,
    required int weekId,
    required int studId,
    required int hwAssignId,
    required int userId,
    required List<String> uploadedFiles,
  }) async {
    const String url = 'https://www.ivpsemi.in/CTA_Mob/v1/TurnInHomework';

    final payload = {
      "HwType": hwType,
      "Batch": batch,
      "WeekId": weekId,
      "StudId": studId,
      "HwAssignId": hwAssignId,
      "UserId": userId,
      "UploadedFiles": uploadedFiles.map((f) => {"FileName": f}).toList(),
    };

    debugPrint('📦 [TurnInHomework] Payload → $payload');

    final response = await _dio.post(
      url,
      data: payload,
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    debugPrint('✅ [TurnInHomework] Response: ${response.data}');
    return response.data;
  }

  /// Download raw bytes using the shared Dio instance.
  Future<Response<List<int>>> downloadFileBytes(String url) async {
    try {
      debugPrint('📥 [downloadFileBytes] Downloading: $url');
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (s) => s! < 500,
        ),
      );
      debugPrint('📥 [downloadFileBytes] Status: ${response.statusCode}');
      return response;
    } on DioException catch (e) {
      debugPrint('❌ [downloadFileBytes] Error: ${e.message}');
      rethrow;
    }
  }

  /// 🗑️ DELETE HOMEWORK FILE
  Future<Map<String, dynamic>> deleteHomeworkFile({
    required String homeworkType,
    required int batch,
    required int weekId,
    required int studId,
    required String fileName,
  }) async {
    const String url = 'https://www.ivpsemi.in/CTA_Mob/v1/FileDelete';

    final payload = {
      "HomeworkType": homeworkType.trim().isEmpty
          ? "Regular Homework"
          : homeworkType.trim(),
      "Batch": batch,
      "WeekId": weekId,
      "StudId": studId,
      "FileName": fileName.trim(),
    };

    debugPrint('🗑️ [DeleteFile] DELETE payload: $payload');

    try {
      final response = await _dio.request(
        url,
        data: payload,
        options: Options(
          method: 'DELETE',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (_) => true,
        ),
      );

      debugPrint('🗑️ [DeleteFile] Status: ${response.statusCode}');
      debugPrint('🗑️ [DeleteFile] Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.data is Map<String, dynamic>) {
          return Map<String, dynamic>.from(response.data);
        } else {
          return {
            "success": true,
            "message": response.data?.toString() ?? 'Deleted (no body)'
          };
        }
      }

      return {
        "success": false,
        "statusCode": response.statusCode,
        "message": response.data?.toString() ?? 'Unexpected response'
      };
    } catch (e) {
      debugPrint('❌ [DeleteFile] Exception: $e');
      return {"success": false, "message": "Exception: $e"};
    }
  }
}

// 🌐 Global instance to access everywhere
final apiService = ApiService();
