// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dropdownmodel.dart';

import '../models/usermodel.dart'; // ✅ use the final UserProfile model name you saved earlier

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

class ApiService {
  final Dio _dio = Dio();
  String? _authToken;
  String? _cookieHeader;
  int? _currentUserId; // stored after login
  String? _currentUsername; // ✅ store username persistently

  /// Set bearer token to include in subsequent requests
  void setAuthToken(String? token) {
    _authToken = token;
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  /// Set Cookie header for session-based auth (if your backend uses cookies)
  void setCookieHeader(String? cookie) {
    _cookieHeader = cookie;
    if (cookie != null && cookie.isNotEmpty) {
      _dio.options.headers['Cookie'] = cookie;
    } else {
      _dio.options.headers.remove('Cookie');
    }
  }

  bool get isLoggedIn => _currentUserId != null;
  String? get currentUsername => _currentUsername; // ✅ getter
  // ----------------- COMMON HELPERS -----------------
  void setCurrentUserId(int userId) => _currentUserId = userId;

  int? get currentUserId => _currentUserId;

  // Future<dynamic> _get(String url, {Map<String, dynamic>? queryParameters}) async {
  //   try {
  //     final response = await _dio.get(
  //       url,
  //       queryParameters: queryParameters,
  //       options: Options(headers: {'Content-Type': 'application/json'}),
  //     );
  //     return response.data;
  //   } on DioException catch (e) {
  //     debugPrint('GET Error on $url: ${e.response?.statusCode} - ${e.message}');
  //     throw Exception('Failed to load data: ${e.response?.data?['message'] ?? e.message}');
  //   }
  // }

  // ✅ Load user session on app start
  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', _currentUserId ?? 0);
    await prefs.setString('username', _currentUsername ?? '');
  }

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getInt('user_id');
    _currentUsername = prefs.getString('username');
    // Load optional persisted auth token or cookie (if your app saved them)
    final savedToken = prefs.getString('auth_token');
    final savedCookie = prefs.getString('cookie');
    if (savedToken != null && savedToken.isNotEmpty) setAuthToken(savedToken);
    if (savedCookie != null && savedCookie.isNotEmpty) setCookieHeader(savedCookie);
    debugPrint('🔹 Session loaded: user_id=$_currentUserId, username=$_currentUsername');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _currentUserId = null;
    _currentUsername = null;
    debugPrint('🚪 User logged out. Session cleared.');
  }

  Future<dynamic> _get(String url,
      {Map<String, dynamic>? queryParameters}) async {
    try {
      debugPrint('🌍 GET Request: $url');
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


  Future<Map<String, dynamic>> _post(String url,
      Map<String, dynamic> data) async {
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
          'Failed to process request: ${e.response?.data?['message'] ??
              e.message}');
    }
  }

  // ----------------- API CALLS -----------------

  /// 1️⃣ LOGIN (GET)
  Future<UserProfile> login(String username, String password) async {
    final responseData = await _get(kLoginUrl, queryParameters: {
      'empno': username,
      'password': password,
    });

    if (responseData is List && responseData.isNotEmpty) {
      final user = UserProfile.fromJson(responseData[0]);
      setCurrentUserId(user.userId);
      _currentUsername = user.userName ?? username; // ✅ Save username

      // ✅ Save login details
      await _saveSession();
      return user;
    }
    throw Exception('Login failed: invalid credentials or empty response.');
  }

  /// 2️⃣ VIEW PROFILE (GET)
  Future<UserProfile> viewProfile() async {
    if (_currentUserId == null) throw Exception('User not logged in.');
    // 💡 Add this line
    debugPrint('🔹 Fetching profile for empid=$_currentUserId');

    final responseData = await _get(kViewProfileUrl, queryParameters: {
      'empid': _currentUserId, // ✅ correct param as per your API
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
  Future<String> changePassword(String newPwd,
      String confirmPwd,
      String oldPwd,) async {
    if (_currentUserId == null) throw Exception('User not logged in.');

    final requestData = {
      "new_pwd": newPwd,
      "confirm_pwd": confirmPwd,
      "old_pwd": oldPwd,
      "is_parent2": "No", // ✅ matches your backend (Postman version)
      "user_id": _currentUserId,
    };

    try {
      debugPrint('🔐 Sending change password request...');

      final response = await _post(kChangePasswordUrl, requestData);

      debugPrint('✅ Password API response: $response');

      // ✅ Safely parse response regardless of format
      if (response is Map<String, dynamic>) {
        if (response['success'] == true ||
            response['Success'] == true) {
          return response['message'] ??
              response['Message'] ??
              'Password changed successfully!';
        } else {
          throw Exception(
              response['message'] ??
                  response['Message'] ??
                  'Password change failed.');
        }
      } else {
        throw Exception('Unexpected response format from server.');
      }
    } on Exception catch (e) {
      // ✅ Handle 404, network, timeout gracefully
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
  Future<List<MenuItem>> fetchMenuList() async {
    if (_currentUserId == null) throw Exception('User not logged in.');
    final responseData = await _get(
        kMenuUrl, queryParameters: {'empid': _currentUserId});
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

  /// 9️⃣ STATIC HOMEWORK API (no user_id or login dependency)
  /// 9️⃣ STATIC HOMEWORK API (No login or user dependency)
  Future<List<Map<String, dynamic>>> fetchStudentHomeWork() async {
    const String url = 'https://www.ivpsemi.in/CTA_Mob/v1/StudentHomeWork';

    try {
      final responseData = await _get(url, queryParameters: {'Stud_id': 19233});

      debugPrint('📘 Homework API response: $responseData');

      if (responseData is List) {
        // Ensure every element is a Map<String, dynamic>
        return responseData.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        debugPrint('⚠️ Unexpected API format: $responseData');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Homework fetch error: $e');
      throw Exception('Failed to fetch homework');
    }
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

      if (responseData is List) {
        return responseData.map((e) => Map<String, dynamic>.from(e)).toList();
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

      // Add all files under key 'file'
      for (var file in files) {
        formData.files.add(MapEntry(
          'file',
          await MultipartFile.fromFile(
            file.path,
            filename: file.path
                .split('/')
                .last,
          ),
        ));
      }

      // Add required form fields
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
  }) async {
    const String baseUrl = 'https://www.ivpsemi.in/CTA_Mob/v1/GetHwUploadedFiles';
    try {
      debugPrint('📥 [GetUploadedFiles] Fetching uploaded files...');
      debugPrint('🔹 hw_assign_id: $hwAssignId');
      debugPrint('🔹 hw_type: $hwType');


      final response = await _dio.get(
        baseUrl,
        queryParameters: {
          'hw_assign_id': hwAssignId,
          'hw_type': hwType.trim().isEmpty ? 'Regular Homework' : hwType.trim(),
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => true,
        ),
      );

      debugPrint('📥 [GetUploadedFiles] Status: ${response.statusCode}');
      debugPrint('📥 [GetUploadedFiles] Response: ${response.data}');

      if (response.statusCode == 200 && response.data is List) {
        debugPrint(
            '✅ [GetUploadedFiles] Files received: ${response.data.length}');
        return List<Map<String, dynamic>>.from(response.data);
      } else if (response.statusCode == 204) {
        debugPrint('ℹ️ [GetUploadedFiles] No files found for this homework.');
        return [];
      } else {
        throw Exception(response.data['message'] ?? 'Unknown error');
      }
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


  // Future<String> turnInHomework({
  //   required String hwType,
  //   required int batch,
  //   required int weekId,
  //   required int studId,
  //   required int hwAssignId,
  //   required int userId,
  //   required List<String> uploadedFiles,
  //
  // }) async {
  //   const url = 'https://www.ivpsemi.in/CTA_Mob/v1/TurnInHomework';
  //
  //
  //   final now = DateTime.now().toIso8601String();
  //
  //   final data = {
  //     "HwType": hwType,
  //     "Batch": batch,
  //     "WeekId": weekId,
  //     "StudId": studId,
  //     "HwAssignId": hwAssignId,
  //     "UserId": userId,
  //     "SubmittedDate": now,
  //     "UploadedFiles": uploadedFiles.map((f) => {"FileName": f}).toList(),
  //   };
  //
  //
  //   debugPrint('📤 [TurnInHomework] Turning in homework...');
  //   debugPrint('📦 Data: $data');
  //
  //   try {
  //     final response = await _post(url, data);
  //     debugPrint('✅ [TurnInHomework] Response: $response');
  //
  //     if (response['success'] == true) {
  //       debugPrint(
  //           '✅ [TurnInHomework] Success message: ${response['message']}');
  //       return response['message'] ?? 'Homework turned in successfully!';
  //     } else {
  //       debugPrint('❌ [TurnInHomework] Failed: ${response['message']}');
  //       throw Exception(response['message'] ?? 'Failed to turn in homework.');
  //     }
  //   } catch (e) {
  //     debugPrint('❌ [TurnInHomework] Exception: $e');
  //     throw Exception('Failed to turn in homework: $e');
  //   }
  // }

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
  /// Returns the Dio Response<List<int>> so caller can inspect status and data.
  Future<Response<List<int>>> downloadFileBytes(String url) async {
    try {
      debugPrint('📥 [downloadFileBytes] Downloading: $url');
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes, followRedirects: true, validateStatus: (s) => s! < 500),
      );
      debugPrint('📥 [downloadFileBytes] Status: ${response.statusCode}');
      return response;
    } on DioException catch (e) {
      debugPrint('❌ [downloadFileBytes] Error: ${e.message}');
      rethrow;
    }
  }

  /// 🗑️ DELETE HOMEWORK FILE
  /// 🗑️ DELETE HOMEWORK FILE (Using POST as per server configuration)
  /// 🗑️ DELETE HOMEWORK FILE (Using existing _post helper)
  /// 🗑️ DELETE HOMEWORK FILE - Debug version
  /// 🗑️ DELETE HOMEWORK FILE - Using FormData
  /// 🗑️ DELETE HOMEWORK FILE (Using proper DELETE method)
  /// 🗑️ DELETE HOMEWORK FILE (Using request method)
  /// 🗑️ DELETE HOMEWORK FILE (Using DELETE with query parameters)
  /// 🗑️ DELETE HOMEWORK FILE (Alternative: Using GET)
  // Future<Map<String, dynamic>> deleteHomeworkFile({
  //   required String homeworkType,
  //   required int batch,
  //   required int weekId,
  //   required int studId,
  //   required String fileName,
  // }) async {
  //   const String baseUrl = 'https://www.ivpsemi.in/CTA_Mob/v1/FileDelete';
  //
  //   try {
  //     final queryParams = {
  //       'HomeworkType': homeworkType.trim(),
  //       'Batch': batch.toString(),
  //       'WeekId': weekId.toString(),
  //       'StudId': studId.toString(),
  //       'FileName': fileName,
  //     };
  //
  //     debugPrint('🗑️ [DeleteFile] Trying with GET method');
  //     debugPrint('🗑️ [DeleteFile] Query Params: $queryParams');
  //
  //     final response = await _dio.get(
  //       baseUrl,
  //       queryParameters: queryParams,
  //       options: Options(
  //         headers: {'Accept': 'application/json'},
  //         validateStatus: (status) => true,
  //       ),
  //     );
  //
  //     debugPrint('📍 Status: ${response.statusCode}');
  //
  //     // Check for HTML error response
  //     if (response.data is String && response.data.toString().contains('<!DOCTYPE')) {
  //       return {
  //         "success": false,
  //         "message": "Invalid endpoint or method"
  //       };
  //     }
  //
  //     debugPrint('📍 Response: ${response.data}');
  //
  //     if (response.statusCode == 200) {
  //       if (response.data is Map) {
  //         return response.data;
  //       }
  //       return {"success": true, "message": "File deleted"};
  //     }
  //
  //     return {
  //       "success": false,
  //       "message": "Failed (Status: ${response.statusCode})"
  //     };
  //
  //   } catch (e) {
  //     debugPrint('❌ Error: $e');
  //     return {
  //       "success": false,
  //       "message": "Error: ${e.toString()}"
  //     };
  //   }
  // }

  Future<Map<String, dynamic>> deleteHomeworkFile({
    required String homeworkType,
    required int batch,
    required int weekId,
    required int studId,
    required String fileName,
  }) async {
    const String url = 'https://www.ivpsemi.in/CTA_Mob/v1/FileDelete';

    final payload = {
      "HomeworkType": homeworkType.trim().isEmpty ? "Regular Homework" : homeworkType.trim(),
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
            // Authorization header is usually set globally; keep it if needed
          },
          validateStatus: (_) => true,
        ),
      );

      debugPrint('🗑️ [DeleteFile] Status: ${response.statusCode}');
      debugPrint('🗑️ [DeleteFile] Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        // If response.data is already a Map with success key, return it; otherwise create one.
        if (response.data is Map<String, dynamic>) {
          return Map<String, dynamic>.from(response.data);
        } else {
          return {
            "success": true,
            "message": response.data?.toString() ?? 'Deleted (no body)'
          };
        }
      }

      // Non-success
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
