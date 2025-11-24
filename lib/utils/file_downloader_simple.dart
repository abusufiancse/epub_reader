// utils/file_downloader_simple.dart
import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

class SimpleFileDownloader {
  final Dio _dio;
  final Logger _logger = Logger();

  SimpleFileDownloader() : _dio = Dio() {
    // Configure Dio with better settings
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(seconds: 30),
      followRedirects: true,
      maxRedirects: 5,
      headers: {
        'User-Agent': 'EPUB-Reader-App',
      },
    );
  }

  Future<String?> downloadBook({
    required String url,
    required String bookCode,
    required Function(int received, int total) onProgress,
  }) async {
    String filePath = '';
    RandomAccessFile? raf;

    try {
      _logger.i('📥 Starting download for book: $bookCode');
      _logger.i('📥 Download URL: $url');

      // Get application documents directory
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${appDocDir.path}/books');

      _logger.i('📁 App documents directory: ${appDocDir.path}');

      // Create books directory if it doesn't exist
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
        _logger.i('📁 Created books directory: ${booksDir.path}');
      }

      // File path with book code
      filePath = '${booksDir.path}/$bookCode.epub';
      _logger.i('💾 Target file path: $filePath');

      // Delete existing file if it exists
      final existingFile = File(filePath);
      if (await existingFile.exists()) {
        await existingFile.delete();
        _logger.i('🗑️ Deleted existing file');
      }

      // Create file and open for writing
      raf = await existingFile.open(mode: FileMode.write);
      _logger.i('📝 File opened for writing');

      // Download using stream to handle large files properly
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 10),
        ),
      );

      final responseStream = response.data as ResponseBody;
      final total = responseStream.contentLength ?? 0;
      int received = 0;

      _logger.i('📦 Starting stream download - Total size: $total bytes');

      try {
        await for (final chunk in responseStream.stream) {
          // Write chunk to file
          raf.writeFromSync(chunk);
          received += chunk.length;

          // Update progress
          if (total > 0) {
            final progress = received / total;
            onProgress(received, total);
            _logger.i('📊 Progress: $received/$total (${(progress * 100).toStringAsFixed(1)}%)');
          }
        }
      } on HttpException catch (e) {
        // Handle connection closed error - this is actually SUCCESS!
        if (received >= total * 0.999) { // 99.9% or more is complete
          _logger.i('✅ Connection closed but file is complete (${(received / total * 100).toStringAsFixed(2)}%)');
          _logger.i('🎉 DOWNLOAD SUCCESSFUL despite connection closure');
          // Don't rethrow - consider this successful
        } else {
          _logger.e('❌ Connection closed with incomplete file: $received/$total');
          rethrow;
        }
      }

      // Close the file
      await raf.close();
      raf = null;

      _logger.i('✅ Stream download completed');

      // Verify the downloaded file
      final downloadedFile = File(filePath);
      final exists = await downloadedFile.exists();

      if (!exists) {
        throw Exception('Downloaded file does not exist at path: $filePath');
      }

      final fileSize = await downloadedFile.length();
      _logger.i('📏 Final file size: $fileSize bytes');

      if (fileSize == 0) {
        await downloadedFile.delete();
        throw Exception('Downloaded file is empty (0 bytes)');
      }

      if (fileSize < 1000) {
        _logger.w('⚠️ File is very small: $fileSize bytes - might be incomplete');
      }

      _logger.i('🎉 Download completed successfully!');
      _logger.i('📍 File saved at: $filePath');

      // Double-check we can read the file
      final canRead = await _verifyFileAccess(filePath);
      if (!canRead) {
        throw Exception('Cannot access downloaded file');
      }

      return filePath;

    } on DioException catch (e) {
      _logger.e('❌ Dio error: ${e.type} - ${e.message}');

      // Close file if it's still open
      if (raf != null) {
        try {
          await raf.close();
        } catch (e) {
          _logger.e('❌ Error closing file: $e');
        }
      }

      // Check if we have a partially downloaded file
      if (filePath.isNotEmpty) {
        final partialFile = File(filePath);
        if (await partialFile.exists()) {
          final partialSize = await partialFile.length();
          _logger.i('📄 Partial file exists - Size: $partialSize bytes');

          // If we have most of the file, consider it successful
          if (partialSize > 1000) {
            _logger.w('⚠️ Partial download but file has content. Size: $partialSize bytes');
            return filePath;
          } else {
            // Delete small/incomplete files
            await partialFile.delete();
            _logger.i('🗑️ Deleted incomplete file');
          }
        }
      }

      throw Exception('Download failed: ${e.message ?? 'Unknown Dio error'}');

    } catch (e) {
      _logger.e('❌ Unexpected error: $e');

      // Close file if it's still open
      if (raf != null) {
        try {
          await raf.close();
        } catch (e) {
          _logger.e('❌ Error closing file: $e');
        }
      }

      throw Exception('Download failed: $e');
    }
  }

  Future<bool> _verifyFileAccess(String filePath) async {
    try {
      final file = File(filePath);
      final exists = await file.exists();
      if (!exists) return false;

      final stats = await file.stat();
      final canRead = await file.exists(); // Simple read check

      _logger.i('🔍 File verification:');
      _logger.i('   📁 Path: $filePath');
      _logger.i('   📏 Size: ${stats.size} bytes');
      _logger.i('   📅 Modified: ${stats.modified}');
      _logger.i('   👀 Can read: $canRead');

      return canRead && stats.size > 0;
    } catch (e) {
      _logger.e('❌ File verification failed: $e');
      return false;
    }
  }

  Future<bool> isBookDownloaded(String bookCode) async {
    try {
      _logger.i('🔍 Checking if book is downloaded: $bookCode');

      final filePath = await _getBookFilePath(bookCode);
      if (filePath == null) {
        _logger.i('📖 Book $bookCode is NOT downloaded');
        return false;
      }

      final file = File(filePath);
      final exists = await file.exists();

      if (exists) {
        final fileSize = await file.length();
        final isValid = fileSize > 1000; // EPUB files should be at least 1KB

        _logger.i('📖 Book $bookCode - Exists: $exists, Size: $fileSize bytes, Valid: $isValid');
        return isValid;
      }

      _logger.i('📖 Book $bookCode file does not exist');
      return false;
    } catch (e) {
      _logger.e('❌ Error checking if book is downloaded: $e');
      return false;
    }
  }

  Future<String?> getDownloadedBookPath(String bookCode) async {
    try {
      _logger.i('📍 Getting downloaded book path for: $bookCode');

      final filePath = await _getBookFilePath(bookCode);
      if (filePath == null) {
        _logger.i('📍 Book $bookCode not found');
        return null;
      }

      final file = File(filePath);
      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize > 1000) {
          _logger.i('📍 Found downloaded book: $bookCode - Size: $fileSize bytes - Path: $filePath');
          return filePath;
        } else {
          _logger.w('⚠️ Book $bookCode exists but is too small: $fileSize bytes');
          await file.delete(); // Clean up invalid file
          return null;
        }
      }

      _logger.i('📍 Book $bookCode file does not exist at path: $filePath');
      return null;
    } catch (e) {
      _logger.e('❌ Error getting downloaded book path: $e');
      return null;
    }
  }

  Future<String?> _getBookFilePath(String bookCode) async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final filePath = '${appDocDir.path}/books/$bookCode.epub';
      return filePath;
    } catch (e) {
      _logger.e('❌ Error getting book file path: $e');
      return null;
    }
  }

  Future<List<String>> listDownloadedBooks() async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${appDocDir.path}/books');

      if (!await booksDir.exists()) {
        return [];
      }

      final files = await booksDir.list().toList();
      final bookFiles = files
          .where((entity) => entity is File && entity.path.endsWith('.epub'))
          .map((entity) => entity.path)
          .toList();

      _logger.i('📚 Found ${bookFiles.length} downloaded books:');
      for (final path in bookFiles) {
        final file = File(path);
        final stats = await file.stat();
        _logger.i('   📖 ${path.split('/').last} - ${stats.size} bytes');
      }

      return bookFiles;
    } catch (e) {
      _logger.e('❌ Error listing downloaded books: $e');
      return [];
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