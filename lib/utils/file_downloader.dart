// utils/file_downloader.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

class FileDownloader {
  final Dio _dio = Dio();
  final Logger _logger = Logger();

  Future<String?> downloadBook({
    required String url,
    required String bookCode,
    required Function(int received, int total) onProgress,
  }) async {
    try {
      _logger.i('📥 Starting download for book: $bookCode');
      _logger.i('📥 Download URL: $url');

      // Check and request storage permission with better handling
      final PermissionStatus status = await _requestStoragePermission();

      if (!status.isGranted) {
        _logger.e('❌ Storage permission denied: $status');
        throw Exception('Storage permission denied. Please allow storage access to download books.');
      }

      _logger.i('✅ Storage permission granted');

      // Get downloads directory
      final Directory? downloadsDir = await getExternalStorageDirectory();
      if (downloadsDir == null) {
        throw Exception('Could not access downloads directory');
      }
      _logger.i('📁 Downloads directory: ${downloadsDir.path}');

      // Create books directory
      final booksDir = Directory('${downloadsDir.path}/books');
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
        _logger.i('📁 Created books directory');
      }

      // File path with book code
      final filePath = '${booksDir.path}/$bookCode.epub';
      _logger.i('💾 File will be saved as: $filePath');

      // Download file with better error handling
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          _logger.i('📊 Download progress: $received/$total (${total != -1 ? (received / total * 100).toStringAsFixed(1) : 'unknown'}%)');
          if (total != -1) {
            onProgress(received, total);
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      // Verify file was downloaded
      final file = File(filePath);
      final exists = await file.exists();
      final fileSize = exists ? await file.length() : 0;

      if (!exists || fileSize == 0) {
        throw Exception('Downloaded file is empty or does not exist');
      }

      _logger.i('✅ Download completed successfully');
      _logger.i('📄 File exists: $exists');
      _logger.i('📏 File size: $fileSize bytes');
      _logger.i('📍 File path: $filePath');

      return filePath;
    } catch (e) {
      _logger.e('❌ Download failed: $e');

      // More specific error messages
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          throw Exception('Download timeout. Please check your internet connection.');
        } else if (e.type == DioExceptionType.connectionError) {
          throw Exception('Network error. Please check your internet connection.');
        } else if (e.response != null) {
          throw Exception('Server error: ${e.response!.statusCode}');
        }
      }

      throw Exception('Download failed: ${e.toString()}');
    }
  }

  Future<PermissionStatus> _requestStoragePermission() async {
    try {
      // Request storage permission
      PermissionStatus status = await Permission.storage.status;

      if (!status.isGranted) {
        status = await Permission.storage.request();
      }

      // For Android 10+ (API 29+), we might need manage external storage
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }

      return status;
    } catch (e) {
      _logger.e('❌ Permission request error: $e');
      return PermissionStatus.denied;
    }
  }

  Future<bool> isBookDownloaded(String bookCode) async {
    try {
      final Directory? downloadsDir = await getExternalStorageDirectory();
      if (downloadsDir == null) return false;

      final filePath = '${downloadsDir.path}/books/$bookCode.epub';
      final file = File(filePath);
      final exists = await file.exists();

      if (exists) {
        final fileSize = await file.length();
        _logger.i('📖 Book $bookCode is downloaded - Size: $fileSize bytes - Path: $filePath');
      } else {
        _logger.i('📖 Book $bookCode is NOT downloaded');
      }

      return exists;
    } catch (e) {
      _logger.e('❌ Error checking if book is downloaded: $e');
      return false;
    }
  }

  Future<String?> getDownloadedBookPath(String bookCode) async {
    try {
      final Directory? downloadsDir = await getExternalStorageDirectory();
      if (downloadsDir == null) return null;

      final filePath = '${downloadsDir.path}/books/$bookCode.epub';
      final file = File(filePath);

      final exists = await file.exists();
      if (exists) {
        final fileSize = await file.length();
        _logger.i('📍 Found downloaded book: $bookCode - Size: $fileSize bytes - Path: $filePath');
        return filePath;
      }

      _logger.i('📍 Book $bookCode not found at: $filePath');
      return null;
    } catch (e) {
      _logger.e('❌ Error getting downloaded book path: $e');
      return null;
    }
  }

  Future<bool> deleteDownloadedBook(String bookCode) async {
    try {
      final filePath = await getDownloadedBookPath(bookCode);
      if (filePath != null) {
        final file = File(filePath);
        await file.delete();
        _logger.i('🗑️ Deleted book: $bookCode from $filePath');
        return true;
      }
      return false;
    } catch (e) {
      _logger.e('❌ Error deleting book: $e');
      return false;
    }
  }
}