// screens/book_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controllers/book_controller.dart';
import '../core/constants/app_colors.dart';
import '../models/book_model.dart';

class BookDetailScreen extends StatefulWidget {
  final BookModel book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final BookController bookController = Get.find<BookController>();
  final RxBool _checkingDownloadStatus = false.obs;
  final RxBool _isDownloaded = false.obs;
  final Rx<BookModel?> _completeBook = Rx<BookModel?>(null);
  final RxBool _loadingBookDetails = false.obs;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadCompleteBookDetails();
    });
  }

  Future<void> _loadCompleteBookDetails() async {
    _loadingBookDetails.value = true;
    try {
      print('📚 Loading complete book details for ID: ${widget.book.bookId}');

      // Use a small delay to ensure build is complete
      await Future.delayed(const Duration(milliseconds: 100));

      await bookController.loadBookDetails(widget.book.bookId);

      // Wait for controller to update without triggering rebuild during build
      await Future.delayed(const Duration(milliseconds: 100));

      _completeBook.value = bookController.selectedBook.value;

      if (_completeBook.value != null) {
        print('✅ Complete book details loaded');
        print('📁 Source file: ${_completeBook.value!.sourceFile}');
      } else {
        print('❌ Failed to load complete book details');
        _completeBook.value = widget.book;
      }

      // Check download status after loading book details
      await _checkDownloadStatus();
    } catch (e) {
      print('❌ Error loading book details: $e');
      _completeBook.value = widget.book;
      await _checkDownloadStatus();
    } finally {
      _loadingBookDetails.value = false;
    }
  }

  Future<void> _checkDownloadStatus() async {
    _checkingDownloadStatus.value = true;
    try {
      final currentBook = _completeBook.value ?? widget.book;
      final isDownloaded = await bookController.isBookDownloaded(currentBook.bookCode);

      // Use a small delay to avoid build conflicts
      await Future.delayed(const Duration(milliseconds: 50));
      _isDownloaded.value = isDownloaded;

      print('📖 Download status for ${currentBook.bookCode}: $isDownloaded');
    } catch (e) {
      print('❌ Error checking download status: $e');
    } finally {
      _checkingDownloadStatus.value = false;
    }
  }
  BookModel get _currentBook {
    return _completeBook.value ?? widget.book;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Obx(() {
        if (_loadingBookDetails.value) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading book details...'),
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            _buildAppBarSection(context),
            _buildBookDetailsSection(),
            _buildDescriptionSection(),
            _buildAdditionalInfoSection(),
          ],
        );
      }),
      bottomNavigationBar: _buildBottomActionButton(),
    );
  }

  SliverAppBar _buildAppBarSection(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 350,
      stretch: true,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        ),
        onPressed: () => Get.back(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Book Cover Image
            CachedNetworkImage(
              imageUrl: _currentBook.coverImage,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey.shade200,
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.grey,
                  size: 60,
                ),
              ),
            ),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // Book Badges
            Positioned(
              top: 100,
              left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentBook.isPurchase)
                    _buildBadge('Purchased', Colors.green),
                  if (_currentBook.isFree)
                    _buildBadge('Free', AppColors.accent),
                  if (_currentBook.hasDiscount)
                    _buildBadge('${_currentBook.discount.toInt()}% OFF', Colors.red),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildBookDetailsSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              _currentBook.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 16),

            // Rating and Reviews
            Row(
              children: [
                // Star Rating
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _currentBook.rating.toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Reviews Count
                Text(
                  '${_currentBook.reviews} Reviews',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Price Section
            _buildPriceSection(),

            const SizedBox(height: 20),

            // Book Code
            _buildInfoRow('Book Code', _currentBook.bookCode),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    if (_currentBook.isFree) {
      return const Text(
        'Free',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.accent,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Price
        Text(
          _currentBook.formattedPrice,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),

        const SizedBox(height: 4),

        // Original Price with Discount
        Row(
          children: [
            Text(
              _currentBook.formattedOriginalPrice,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
                decoration: TextDecoration.lineThrough,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            if (_currentBook.hasDiscount)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Save ৳${(_currentBook.mrpPrice - _currentBook.finalPrice).toInt()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  SliverToBoxAdapter _buildDescriptionSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _currentBook.description,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildAdditionalInfoSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Book Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow('Publication Year', _currentBook.year),
                  const SizedBox(height: 12),
                  _buildInfoRow('Publication Month', _currentBook.month),
                  const SizedBox(height: 12),
                  _buildInfoRow('Availability', _currentBook.canRead ? 'Available' : 'Purchase Required'),
                  const SizedBox(height: 12),
                  _buildInfoRow('Download Status', _isDownloaded.value ? 'Downloaded' : 'Not Downloaded'),
                  const SizedBox(height: 12),
                  if (_currentBook.sourceFile != null)
                    _buildInfoRow('Source File', 'Available'),
                  if (_currentBook.sourceFile == null)
                    _buildInfoRow('Source File', 'Not Available'),
                ],
              ),
            ),
            const SizedBox(height: 100), // Extra space for bottom button
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Obx(() {
        // Show loading while checking download status or loading book details
        if (_checkingDownloadStatus.value || _loadingBookDetails.value) {
          return const SizedBox(
            height: 50,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Show download progress if downloading
        if (bookController.isDownloading(_currentBook.bookCode)) {
          return _buildDownloadProgress();
        }

        // Show appropriate button based on download status and purchase status
        return SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              if (_currentBook.canRead) {
                if (_isDownloaded.value) {
                  _readBook();
                } else {
                  _startDownloading();
                }
              } else {
                _purchaseBook();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getButtonColor(),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getButtonIcon()),
                const SizedBox(width: 8),
                Text(
                  _getButtonText(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDownloadProgress() {
    final progress = bookController.getDownloadProgress(_currentBook.bookCode);

    return Column(
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade300,
          color: AppColors.primary,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 8),

        // Progress text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Downloading: ${(progress * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${_currentBook.bookCode}.epub',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getButtonColor() {
    if (!_currentBook.canRead) {
      return AppColors.accent; // Purchase button
    }
    if (_isDownloaded.value) {
      return Colors.green; // Read Now button
    }
    return AppColors.primary; // Download button
  }

  IconData _getButtonIcon() {
    if (!_currentBook.canRead) {
      return Icons.shopping_cart_rounded;
    }
    if (_isDownloaded.value) {
      return Icons.menu_book_rounded;
    }
    return Icons.download_rounded;
  }

  String _getButtonText() {
    if (!_currentBook.canRead) {
      return 'Purchase for ${_currentBook.formattedPrice}';
    }
    if (_isDownloaded.value) {
      return 'Read Now';
    }
    return 'Download';
  }

  Future<void> _startDownloading() async {
    try {
      final currentBook = _currentBook;

      print('🚀 Starting download for: ${currentBook.bookCode}');

      final downloadUrl = currentBook.sourceFile ?? currentBook.bookLink;

      if (downloadUrl == null || downloadUrl.isEmpty) {
        throw Exception('No download source available for this book');
      }

      await bookController.downloadBook(currentBook);

      // Small delay to ensure UI stability
      await Future.delayed(const Duration(milliseconds: 100));

      // Force refresh the download status
      await _checkDownloadStatus();

      print('✅ Download process completed for: ${currentBook.bookCode}');

      Get.snackbar(
        'Success',
        'Book downloaded successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      print('❌ Download error: $e');

      // Even if there's an error, check if file was actually downloaded
      await _checkDownloadStatus();

      // Check if file exists despite the error
      final isActuallyDownloaded = await bookController.isBookDownloaded(_currentBook.bookCode);
      if (isActuallyDownloaded) {
        print('⚠️ Error occurred but file was downloaded successfully');
        _isDownloaded.value = true;
        Get.snackbar(
          'Download Complete',
          'Book downloaded successfully!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      } else {
        Get.snackbar(
          'Download Failed',
          'Failed to download book',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _readBook() async {
    try {
      final filePath = await bookController.getDownloadedBookPath(_currentBook.bookCode);
      print('📖 Opening book from path: $filePath');

      if (filePath == null) {
        throw Exception('Book file not found. Please download again.');
      }

      // TODO: Implement EPUB reader opening with flutter_epub_viewer
      Get.snackbar(
        'Ready to Read',
        'Book is downloaded and ready to open!\nFile: ${_currentBook.bookCode}.epub',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

    } catch (e) {
      print('❌ Error reading book: $e');
      Get.snackbar(
        'Error',
        'Cannot open book: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _purchaseBook() {
    print('🛒 Purchase requested for: ${_currentBook.bookCode}');
    Get.snackbar(
      'Purchase',
      'Purchase feature coming soon!',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.accent,
      colorText: Colors.white,
    );
  }
}