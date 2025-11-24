// controllers/book_controller.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../core/constants/app_constants.dart';
import '../models/book_model.dart';
import '../utils/file_downloader.dart';
import '../utils/file_downloader_simple.dart';
import '../utils/network_caller.dart';

class BookController extends GetxController {
  final RxList<BookModel> books = <BookModel>[].obs;
  final Rx<BookModel?> selectedBook = Rx<BookModel?>(null); //product details
  final RxList<BookModel> featuredBooks = <BookModel>[].obs;
  final RxMap<String, List<BookModel>> booksByYear = <String, List<BookModel>>{}.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Add download states
  final RxMap<String, bool> downloadingBooks = <String, bool>{}.obs;
  final RxMap<String, double> downloadProgress = <String, double>{}.obs;
  final RxMap<String, bool> downloadedBooks = <String, bool>{}.obs;

  final NetworkCaller _networkCaller = NetworkCaller();
  // final FileDownloader _fileDownloader = FileDownloader();
  final SimpleFileDownloader _fileDownloader = SimpleFileDownloader(); // Use simple
  final Logger _logger = Logger();

  @override
  void onInit() {
    super.onInit();
    loadBooks();
  }
  // Download book method
  // In BookController - update the downloadBook method
  // In book_controller.dart - update the downloadBook method
// In book_controller.dart - update downloadBook method
  // In BookController - update downloadBook method
  Future<void> downloadBook(BookModel book) async {
    try {
      final downloadUrl = book.sourceFile ?? book.bookLink;

      if (downloadUrl == null || downloadUrl.isEmpty) {
        throw Exception('No download source available for this book');
      }

      downloadingBooks[book.bookCode] = true;
      downloadProgress[book.bookCode] = 0.0;

      _logger.i('🚀 Starting download for: ${book.bookCode}');

      final filePath = await _fileDownloader.downloadBook(
        url: downloadUrl,
        bookCode: book.bookCode,
        onProgress: (received, total) {
          downloadProgress[book.bookCode] = received / total;
        },
      );

      _logger.i('📁 Download returned file path: $filePath');

      if (filePath == null) {
        throw Exception('Download failed - no file path returned');
      }

      // Verify the file exists and is accessible
      final file = File(filePath);
      final exists = await file.exists();
      final fileSize = exists ? await file.length() : 0;

      _logger.i('🔍 Post-download verification:');
      _logger.i('   📁 File exists: $exists');
      _logger.i('   📏 File size: $fileSize bytes');

      if (!exists || fileSize == 0) {
        throw Exception('Downloaded file is missing or empty');
      }

      // SUCCESS - Update UI state
      _logger.i('🎉 DOWNLOAD COMPLETED SUCCESSFULLY for: ${book.bookCode}');

      downloadingBooks[book.bookCode] = false;
      downloadedBooks[book.bookCode] = true; // This will trigger UI update

      // Show success message to user
      Get.snackbar(
        'Download Complete',
        'Book "${book.title}" downloaded successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

    } catch (e) {
      _logger.e('💥 Download failed for ${book.bookCode}: $e');
      downloadingBooks[book.bookCode] = false;
      downloadProgress[book.bookCode] = 0.0;

      throw e;
    }
  }

  // Check if book is downloaded
  Future<bool> isBookDownloaded(String bookCode) async {
    if (downloadedBooks[bookCode] == true) {
      return true;
    }

    final isDownloaded = await _fileDownloader.isBookDownloaded(bookCode);
    downloadedBooks[bookCode] = isDownloaded;
    return isDownloaded;
  }

  // Get downloaded book path
  Future<String?> getDownloadedBookPath(String bookCode) async {
    return await _fileDownloader.getDownloadedBookPath(bookCode);
  }

  // Check download state for a book
  bool isDownloading(String bookCode) {
    return downloadingBooks[bookCode] == true;
  }

  double getDownloadProgress(String bookCode) {
    return downloadProgress[bookCode] ?? 0.0;
  }

  bool isDownloaded(String bookCode) {
    return downloadedBooks[bookCode] == true;
  }


  //others
  Future<void> loadBooks() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await _networkCaller.getRequest(
        url: '${AppConstants.baseUrl}${AppConstants.booksEndpoint}',
      );

      if (response.isSuccess && response.responseData['success'] == true) {
        final List<dynamic> booksData = response.responseData['books'];
        books.assignAll(booksData.map((json) => BookModel.fromJson(json)));

        // Organize books by year
        _organizeBooksByYear();

        // Get featured books (first 3 or purchased books)
        _getFeaturedBooks();

        _logger.i('Loaded ${books.length} books successfully');
      } else {
        errorMessage.value = 'Failed to load books';
        _logger.e('Books loading failed: ${response.errorMess}');
      }
    } catch (e) {
      errorMessage.value = 'Error loading books';
      _logger.e('Books loading exception: $e');
    } finally {
      isLoading.value = false;
    }
  }
  Future<void> loadBookDetails(int bookId) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final response = await _networkCaller.getRequest(
        url: '${AppConstants.baseUrl}${AppConstants.booksEndpoint}/$bookId',
      );

      if (response.isSuccess && response.responseData['success'] == true) {
        selectedBook.value = BookModel.fromJson(response.responseData['book']);
        _logger.i('Loaded book details for ID: $bookId');
      } else {
        errorMessage.value = 'Failed to load book details';
        _logger.e('Book details loading failed: ${response.errorMess}');
      }
    } catch (e) {
      errorMessage.value = 'Error loading book details';
      _logger.e('Book details loading exception: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void clearSelectedBook() {
    selectedBook.value = null;
  }


  void _organizeBooksByYear() {
    booksByYear.clear();

    for (final book in books) {
      if (!booksByYear.containsKey(book.year)) {
        booksByYear[book.year] = [];
      }
      booksByYear[book.year]!.add(book);
    }
  }

  void _getFeaturedBooks() {
    // Get purchased books first, then free books, then take first 3
    final purchasedBooks = books.where((book) => book.isPurchase).toList();
    final freeBooks = books.where((book) => book.isFree).toList();
    final otherBooks = books.where((book) => !book.isPurchase && !book.isFree).toList();

    featuredBooks.assignAll([
      ...purchasedBooks.take(3),
      ...freeBooks.take(3 - purchasedBooks.length),
      ...otherBooks.take(3 - purchasedBooks.length - freeBooks.length),
    ].take(3).toList());
  }

  List<BookModel> getBooksByYear(String year) {
    return booksByYear[year] ?? [];
  }

  List<String> get availableYears {
    return booksByYear.keys.toList()..sort((a, b) => b.compareTo(a));
  }
}