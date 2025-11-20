// utils/network_caller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:logger/logger.dart';

class NetworkResponse {
  final bool isSuccess;
  final int statusCode;
  final dynamic responseData;
  final String errorMess;

  NetworkResponse({
    required this.isSuccess,
    required this.statusCode,
    this.responseData,
    this.errorMess = 'Something went wrong',
  });
}

class NetworkCaller {
  final Logger _logger = Logger();
  final GetStorage _storage = GetStorage();

  // Get token from storage
  String? get _token => _storage.read('token');

  // Default headers
  Map<String, String> _getHeaders({bool includeToken = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeToken && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  // POST request helper
  Future<NetworkResponse> postRequest({
    required String url,
    dynamic body,
    bool includeToken = false,
    Map<String, String>? extraHeaders,
  }) async {
    return request(
      method: 'POST',
      url: url,
      headers: {..._getHeaders(includeToken: includeToken), ...?extraHeaders},
      body: body,
    );
  }

  // GET request helper
  Future<NetworkResponse> getRequest({
    required String url,
    bool includeToken = true,
    Map<String, String>? extraHeaders,
  }) async {
    return request(
      method: 'GET',
      url: url,
      headers: {..._getHeaders(includeToken: includeToken), ...?extraHeaders},
    );
  }

  // PUT request helper
  Future<NetworkResponse> putRequest({
    required String url,
    dynamic body,
    bool includeToken = true,
    Map<String, String>? extraHeaders,
  }) async {
    return request(
      method: 'PUT',
      url: url,
      headers: {..._getHeaders(includeToken: includeToken), ...?extraHeaders},
      body: body,
    );
  }

  // DELETE request helper
  Future<NetworkResponse> deleteRequest({
    required String url,
    dynamic body,
    bool includeToken = true,
    Map<String, String>? extraHeaders,
  }) async {
    return request(
      method: 'DELETE',
      url: url,
      headers: {..._getHeaders(includeToken: includeToken), ...?extraHeaders},
      body: body,
    );
  }

  // Main request method
  Future<NetworkResponse> request({
    required String method, // 'GET', 'POST', 'PUT', 'DELETE'
    required String url,
    Map<String, String>? headers,
    dynamic body,
  }) async {
    Uri uri = Uri.parse(url);
    _logRequest(method, url, headers, body);

    try {
      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));
          break;
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 30));
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 30));
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers, body: jsonEncode(body))
              .timeout(const Duration(seconds: 30));
          break;
        default:
          throw UnsupportedError('Unsupported HTTP method: $method');
      }

      _logResponse(url: url, statusCode: response.statusCode, headers: response.headers, body: response.body);

      // Handle different status codes
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        return NetworkResponse(
            isSuccess: true,
            statusCode: response.statusCode,
            responseData: decoded
        );
      } else if (response.statusCode == 401) {
        // Token expired or invalid
        _handleUnauthorized();
        return NetworkResponse(
          isSuccess: false,
          statusCode: response.statusCode,
          errorMess: 'Authentication failed. Please login again.',
        );
      } else {
        // Try to parse error message from response
        String errorMessage = 'Error ${response.statusCode}';
        try {
          final errorJson = jsonDecode(response.body);
          if (errorJson['message'] != null) {
            errorMessage = errorJson['message'];
          } else if (errorJson['error'] != null) {
            errorMessage = errorJson['error'];
          }
        } catch (e) {
          // If cannot parse error message, use default
          errorMessage = 'Error ${response.statusCode}: ${response.reasonPhrase}';
        }

        return NetworkResponse(
          isSuccess: false,
          statusCode: response.statusCode,
          errorMess: errorMessage,
        );
      }
    } on SocketException catch (_) {
      _logError(url, 'No Internet Connection');
      return NetworkResponse(
          isSuccess: false,
          statusCode: -1,
          errorMess: 'No Internet Connection'
      );
    } on FormatException catch (_) {
      _logError(url, 'Invalid JSON format');
      return NetworkResponse(
          isSuccess: false,
          statusCode: -1,
          errorMess: 'Invalid response format'
      );
    } on http.ClientException catch (e) {
      _logError(url, 'Client Exception: $e');
      return NetworkResponse(
          isSuccess: false,
          statusCode: -1,
          errorMess: 'Network error occurred'
      );
    } on TimeoutException catch (_) {
      _logError(url, 'Request timeout');
      return NetworkResponse(
          isSuccess: false,
          statusCode: -1,
          errorMess: 'Request timeout'
      );
    } catch (e) {
      _logError(url, e.toString());
      return NetworkResponse(
          isSuccess: false,
          statusCode: -1,
          errorMess: 'An unexpected error occurred'
      );
    }
  }

  // Handle unauthorized access (token expired)
  void _handleUnauthorized() {
    _storage.remove('token');
    _storage.remove('user');
    // You can add navigation to login screen here if needed
    // Get.offAllNamed('/login');
  }

  // Check if user is authenticated
  bool get isAuthenticated => _token != null;

  // Get stored token
  String? get storedToken => _token;

  // Clear authentication data
  void clearAuthData() {
    _storage.remove('token');
    _storage.remove('user');
  }

  void _logRequest(String method, String url, Map<String, dynamic>? headers, dynamic body) {
    _logger.i('''
🔗 [$method REQUEST]
URL: $url
Headers: ${headers ?? {}}
Body: ${body ?? {}}
Token: ${_token != null ? '***' : 'None'}
''');
  }

  void _logResponse({
    required String url,
    required int statusCode,
    required Map<String, String> headers,
    required String body,
  }) {
    _logger.i('''
✅ [RESPONSE]
URL: $url
Status Code: $statusCode
Headers: $headers
Body: $body
''');
  }

  void _logError(String url, String errorMessage) {
    _logger.e('''
❌ [ERROR]
URL: $url
Message: $errorMessage
''');
  }
}