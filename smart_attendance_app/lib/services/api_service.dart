import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  
  late Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));
    
    // Add interceptor for JWT token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'jwt_token');
        dev.log('API Request: ${options.method} ${options.path}');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
          dev.log('Token attached: ${token.substring(0, 20)}...');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        dev.log('API Response: ${response.statusCode} ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (error, handler) async {
        dev.log('API Error: ${error.response?.statusCode} ${error.requestOptions.path} - ${error.message}');
        dev.log('Error response: ${error.response?.data}');
        
        // Clear token on 401 error to force re-login
        if (error.response?.statusCode == 401) {
          dev.log('401 Unauthorized - clearing token');
          await _storage.delete(key: 'jwt_token');
          await _storage.delete(key: 'user_role');
          await _storage.delete(key: 'user_id');
        }
        return handler.next(error);
      },
    ));
    _loadBaseUrl();
  }

  Future<void> _loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('api_base_url');
    if (savedUrl != null) {
      ApiConfig.baseUrl = savedUrl;
      _dio.options.baseUrl = savedUrl;
      dev.log('Loaded saved Base URL: $savedUrl');
    }
  }

  Future<void> updateBaseUrl(String newUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', newUrl);
    ApiConfig.baseUrl = newUrl;
    _dio.options.baseUrl = newUrl;
    dev.log('Updated Base URL to: $newUrl');
  }
  
  Dio get dio => _dio;
  
  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return response.data;
  }
  
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }
  
  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }
  
  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_role');
    await _storage.delete(key: 'user_id');
  }
  
  Future<void> saveUserInfo(String role, String id) async {
    await _storage.write(key: 'user_role', value: role);
    await _storage.write(key: 'user_id', value: id);
  }
  
  Future<Map<String, String?>> getUserInfo() async {
    return {
      'role': await _storage.read(key: 'user_role'),
      'id': await _storage.read(key: 'user_id'),
    };
  }
  
  // Teacher APIs
  Future<List<dynamic>> getTeacherClasses() async {


    // Get teacher's ref_id from /auth/me endpoint
    final meResponse = await _dio.get('/auth/me');
    final refId = meResponse.data['ref_id'];
    final response = await _dio.get('/teacher/$refId/classes');
    return response.data;
  }
  
  Future<List<dynamic>> getClassStudents(String classId) async {
    final response = await _dio.get('/admin/class-subjects/$classId/students');
    return response.data;
  }
  
  Future<Map<String, dynamic>> markAttendance({
    required String classId,
    required String subjectCode,
    required String date,
    required int periodNo,
    required dynamic imageFile,
  }) async {
    // Get teacher_id from current user
    final meResponse = await _dio.get('/auth/me');
    final teacherId = meResponse.data['ref_id'];
    
    final formData = FormData.fromMap({
      'class_id': classId,
      'subject_code': subjectCode,
      'teacher_id': teacherId,
      'date': date,
      'period': periodNo,
      'image': await MultipartFile.fromFile(imageFile.path, filename: 'attendance.jpg'),
    });
    final response = await _dio.post('/attendance/auto', data: formData);
    return response.data;
  }
  
  Future<void> saveManualAttendance({
    required String classId,
    required String subjectCode,
    required String date,
    required int periodNo,
    required List<Map<String, dynamic>> attendanceList,
  }) async {
    // Get teacher_id from current user
    final meResponse = await _dio.get('/auth/me');
    final teacherId = meResponse.data['ref_id'];
    
    // Convert attendance list to records format expected by backend
    final records = attendanceList.map((item) => {
      'reg_no': item['reg_no'],
      'status': item['status'],
    }).toList();
    
    await _dio.post('/attendance/manual', data: {
      'class_id': classId,
      'subject_code': subjectCode,
      'teacher_id': teacherId,
      'date': date,
      'period': periodNo,
      'records': records,
    });
  }
  
  Future<List<dynamic>> getAttendanceHistory({
    required String subjectCode,
    String? startDate,
    String? endDate,
  }) async {
    final response = await _dio.get('/teacher/attendance-history', queryParameters: {
      'subject_code': subjectCode,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    });
    return response.data;
  }
  
  // Student APIs
  Future<Map<String, dynamic>> getTodayAttendance() async {
    final response = await _dio.get('/student/today');
    return response.data;
  }
  
  // Get student's 7-day attendance grid
  Future<Map<String, dynamic>> getWeeklyStudentAttendance() async {
    final response = await _dio.get('/student/weekly');
    return response.data;
  }
  
  Future<Map<String, dynamic>> getAttendanceSheet({
    String? startDate,
    String? endDate,
  }) async {
    final response = await _dio.get('/student/attendance-sheet', queryParameters: {
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    });
    return response.data;
  }
  
  // Weekly attendance for teacher (all sessions, no period filter)
  Future<Map<String, dynamic>> getWeeklyAttendance({
    required String classId,
    required String subjectCode,
  }) async {
    final meResponse = await _dio.get('/auth/me');
    final teacherId = meResponse.data['ref_id'];
    
    final response = await _dio.get('/teacher/$teacherId/weekly-attendance', queryParameters: {
      'class_id': classId,
      'subject_code': subjectCode,
    });
    return response.data;
  }
  
  Future<void> updateAttendanceRecords({
    required int sessionId,
    required List<Map<String, dynamic>> updates,
  }) async {
    final meResponse = await _dio.get('/auth/me');
    final teacherId = meResponse.data['ref_id'];
    
    await _dio.put('/teacher/$teacherId/session/$sessionId/edit', data: updates);
  }
  
  String getProofImageUrl(int sessionId) {
    // Get teacher ID synchronously is tricky, so return base URL
    return '${ApiConfig.baseUrl}/teacher/1/proof/$sessionId';
  }
  
  Future<String?> getProofImageUrlWithAuth(int sessionId) async {
    final meResponse = await _dio.get('/auth/me');
    final teacherId = meResponse.data['ref_id'];
    return '${ApiConfig.baseUrl}/teacher/$teacherId/proof/$sessionId';
  }

  // OD/ML Request APIs

  Future<void> submitLeaveRequest({
    required String type,
    required String fromDate,
    required String toDate,
    required String periods,
    required dynamic proofFile,
  }) async {
    final formData = FormData.fromMap({
      'request_type': type,
      'from_date': fromDate,
      'to_date': toDate,
      'periods': periods,
      'proof': await MultipartFile.fromFile(proofFile.path, filename: 'proof.${proofFile.path.split('.').last}'),
    });
    
    await _dio.post('/student/request-leave', data: formData);
  }

  Future<List<dynamic>> getTeacherInbox() async {
    final meResponse = await _dio.get('/auth/me');
    final teacherId = meResponse.data['ref_id'];
    final response = await _dio.get('/teacher/$teacherId/inbox');
    return response.data;
  }

  Future<void> approveRequest(int approvalId) async {
    final meResponse = await _dio.get('/auth/me');
    final teacherId = meResponse.data['ref_id'];
    await _dio.post('/teacher/$teacherId/inbox/$approvalId/approve');
  }

  Future<void> rejectRequest(int approvalId) async {
    final meResponse = await _dio.get('/auth/me');
    final teacherId = meResponse.data['ref_id'];
    await _dio.post('/teacher/$teacherId/inbox/$approvalId/reject');
  }
  
  Future<void> approveRequestGroup(List<int> approvalIds) async {
    final meResponse = await _dio.get('/auth/me');
    final teacherId = meResponse.data['ref_id'];
    await _dio.post(
      '/teacher/$teacherId/inbox/bulk-approve',
      data: {'approval_ids': approvalIds},
    );
  }

  Future<void> rejectRequestGroup(List<int> approvalIds) async {
    final meResponse = await _dio.get('/auth/me');
    final teacherId = meResponse.data['ref_id'];
    await _dio.post(
      '/teacher/$teacherId/inbox/bulk-reject',
      data: {'approval_ids': approvalIds},
    );
  }
  
  // Timetable
  Future<List<dynamic>> getStudentTimetable() async {
    final response = await _dio.get('/student/timetable');
    return response.data;
  }
  
  Future<List<dynamic>> getTeacherTimetable() async {
    final response = await _dio.get('/teacher/timetable');
    return response.data;
  }
  
  Future<List<dynamic>> getTodayTimetableForTeacher() async {
    final response = await _dio.get('/teacher/timetable/today');
    return response.data;
  }

  String getRequestProofUrl(int requestId) {
    return '${ApiConfig.baseUrl}/teacher/inbox/proof/$requestId';
  }

  // E-Books
  Future<void> uploadEBook({
    required String subjectCode,
    required String title,
    required dynamic file,
  }) async {
    final formData = FormData.fromMap({
      'subject_code': subjectCode,
      'title': title,
      'file': await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
    });
    
    await _dio.post('/ebook/upload', data: formData);
  }

  Future<List<dynamic>> getTeacherUploads() async {
    final response = await _dio.get('/ebook/teacher');
    return response.data;
  }
  
  Future<List<dynamic>> getSubjectEBooks(String subjectCode) async {
    final response = await _dio.get('/ebook/subject/$subjectCode');
    return response.data;
  }
  
  String getEBookDownloadUrl(int materialId) {
    return '${ApiConfig.baseUrl}/ebook/download/$materialId';
  }
  // Task Assigner
  Future<void> createTask({
    required String classId,
    required String subjectCode,
    required String type,
    required String title,
    String? description,
    DateTime? deadline,
    int maxMarks = 10,
    dynamic file,
  }) async {
    final formData = FormData.fromMap({
      'class_id': classId,
      'subject_code': subjectCode,
      'type': type,
      'title': title,
      'description': description ?? '',
      'deadline': deadline?.toIso8601String(), // Send as ISO string
      'max_marks': maxMarks,
      if (file != null)
        'file': await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
    });
    
    await _dio.post('/tasks/create', data: formData);
  }

  Future<List<dynamic>> getTeacherTasks() async {
    final response = await _dio.get('/tasks/teacher/list');
    return response.data;
  }
  
  Future<List<dynamic>> getStudentTasks({String? subjectCode}) async {
    final response = await _dio.get('/tasks/student/list', queryParameters: {
      if (subjectCode != null) 'subject_code': subjectCode,
    });
    return response.data;
  }
  
  Future<void> submitTask({
    required int taskId,
    required dynamic file,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
    });
    
    await _dio.post('/tasks/submit/$taskId', data: formData);
  }
  
  Future<List<dynamic>> getTaskSubmissions(int taskId) async {
    final response = await _dio.get('/tasks/$taskId/submissions');
    return response.data;
  }
  
  Future<void> evaluateSubmission({
    required int submissionId,
    required double marks,
    required String remarks,
  }) async {
    await _dio.post('/tasks/evaluate/$submissionId', data: {
      'marks_obtained': marks,
      'remarks': remarks,
    });
  }
  
  Future<Map<String, dynamic>> getTaskDetails(int taskId) async {
    final response = await _dio.get('/tasks/$taskId');
    return response.data;
  }
  
  Future<Map<String, dynamic>?> getMySubmission(int taskId) async {
    try {
      final response = await _dio.get('/tasks/student/submission/$taskId');
      if (response.data == null) return null;
      return response.data;
    } catch (_) {
      return null;
    }
  }
  
  String getTaskFileUrl(int taskId) {
    return '${ApiConfig.baseUrl}/tasks/download/task/$taskId';
  }
  
  String getSubmissionFileUrl(int submissionId) {
    return '${ApiConfig.baseUrl}/tasks/download/submission/$submissionId';
  }
  
  // --- Marks Module ---
  
  Future<Map<String, dynamic>> getMarksEntrySheet(String classId, String subjectCode) async {
    final response = await _dio.get('/marks/entry_sheet', queryParameters: {
      'class_id': classId,
      'subject_code': subjectCode,
    });
    return response.data;
  }
  
  Future<void> saveMarks(String classId, String subjectCode, List<Map<String, dynamic>> updates) async {
    await _dio.post('/marks/entry', data: {
      'class_id': classId,
      'subject_code': subjectCode,
      'updates': updates,
    });
  }
  
  Future<Map<String, dynamic>> getMarksStatistics(String classId, String subjectCode, [String? examType]) async {
    final response = await _dio.get(
        '/marks/statistics/$classId/$subjectCode',
        queryParameters: examType != null ? {'exam_type': examType} : null
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getMyMarks(String subjectCode) async {
    final response = await _dio.get('/marks/student/my_marks/$subjectCode');
    return response.data;
  }
  
  Future<List<dynamic>> getStudentSubjects() async {
    try {
      final response = await _dio.get('/student/subjects');
      return response.data;
    } catch (e) {
      print("Error fetching student subjects: $e");
      return []; 
    }
  }
  
  Future<Map<String, dynamic>> getFinalMarksheet() async {
    final response = await _dio.get('/marks/student/final_marksheet');
    return response.data;
  }

  // --- Profiles ---
  Future<Map<String, dynamic>> fetchStudentProfile(int studentId) async {
    final response = await _dio.get('/profiles/$studentId');
    return response.data;
  }
  
  Future<List<dynamic>> fetchStudentsByClass(String classId) async {
    final response = await _dio.get('/teacher/students/$classId');
    return response.data;
  }

  Future<Map<String, dynamic>> fetchMyProfile() async {
    final response = await _dio.get('/profiles/my/profile');
    return response.data;
  }
}

