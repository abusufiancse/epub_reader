// controllers/book_controller.dart
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../core/constants/app_constants.dart';
import '../models/book_model.dart';
import '../utils/network_caller.dart';

class BookController extends GetxController {
  final RxList<BookModel> books = <BookModel>[].obs;
  final RxList<BookModel> featuredBooks = <BookModel>[].obs;
  final RxMap<String, List<BookModel>> booksByYear = <String, List<BookModel>>{}.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  final NetworkCaller _networkCaller = NetworkCaller();
  final Logger _logger = Logger();

  @override
  void onInit() {
    super.onInit();
    loadBooks();
  }

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