import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../controllers/book_controller.dart';
import '../core/constants/app_colors.dart';
import '../models/book_model.dart';
import 'package:mr_epub/mr_epub.dart';

enum DownloadState { notStarted, checking, downloading, done, error }

class BookDetailScreen extends StatefulWidget {
  final BookModel book;
  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final BookController bookController = Get.find<BookController>();
  final RxBool _loadingBookDetails = false.obs;

  // Download variables
  DownloadState _state = DownloadState.notStarted;
  double? _progress;
  String? _localFilePath;
  String? _error;
  String? _statusMessage;
  int _receivedBytes = 0;
  int? _totalBytes;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadCompleteBookDetails();
      _initAndCheckCache();
    });
  }

  BookModel get _currentBook => widget.book;

  Future<void> _loadCompleteBookDetails() async {
    _loadingBookDetails.value = true;
    try {
      await bookController.loadBookDetails(_currentBook.bookId);

      // After loading details, debug print the sourceFile value
      debugPrint('🔍 Book sourceFile: ${_currentBook.sourceFile}');
      debugPrint('🔍 Book bookLink: ${_currentBook.bookLink}');

      // Force a UI update to reflect the new book details
      setState(() {});
    } catch (e) {
      debugPrint('❌ Error loading book details: $e');
    } finally {
      _loadingBookDetails.value = false;
    }
  }

  // ------------------ HomeScreen style download logic ------------------
  Future<Directory> _appDir() async => await getApplicationDocumentsDirectory();
  Future<File> _localFile() async {
    final dir = await _appDir();
    return File('${dir.path}/${_currentBook.bookCode}.epub');
  }

  // Check available storage space
  Future<int> _getFreeSpace() async {
    try {
      if (Platform.isAndroid) {
        final directory = await _appDir();
        final stat = await directory.stat();
        // For Android, we'll use a simplified approach
        // Note: This is an approximation as exact free space requires platform channels
        return 1024 * 1024 * 1024; // Assume 1GB available as fallback
      } else if (Platform.isIOS) {
        final directory = await _appDir();
        final stat = await directory.stat();
        // For iOS, similar approximation
        return 1024 * 1024 * 1024; // Assume 1GB available as fallback
      }
      return 1024 * 1024 * 1024; // Default 1GB
    } catch (e) {
      debugPrint('❌ Error checking free space: $e');
      return 1024 * 1024 * 1024; // Default 1GB on error
    }
  }

  Future<void> _initAndCheckCache() async {
    setState(() {
      _state = DownloadState.checking;
      _statusMessage = 'Checking local cache...';
    });

    final file = await _localFile();
    if (await file.exists()) {
      final len = await file.length();
      if (len > 10 * 1024) {
        setState(() {
          _localFilePath = file.path;
          _state = DownloadState.done;
          _progress = 1.0;
          _statusMessage = 'Using cached EPUB';
        });
        return;
      } else {
        await _secureDelete(file);
      }
    }

    setState(() {
      _state = DownloadState.notStarted;
      _statusMessage = null;
    });
  }

  Future<void> _secureDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  // Fixed to check both sourceFile and bookLink as fallback
  bool get _hasRemoteUrl {
    final hasSourceFile = _currentBook.sourceFile != null && _currentBook.sourceFile!.trim().isNotEmpty;
    final hasBookLink = _currentBook.bookLink != null && _currentBook.bookLink!.trim().isNotEmpty;

    debugPrint('🔍 Checking download URLs:');
    debugPrint('  - sourceFile: ${_currentBook.sourceFile}');
    debugPrint('  - bookLink: ${_currentBook.bookLink}');
    debugPrint('  - hasSourceFile: $hasSourceFile');
    debugPrint('  - hasBookLink: $hasBookLink');

    return hasSourceFile || hasBookLink;
  }

  // Get the appropriate download URL
  String get _downloadUrl {
    if (_currentBook.sourceFile != null && _currentBook.sourceFile!.trim().isNotEmpty) {
      return _currentBook.sourceFile!.trim();
    }
    if (_currentBook.bookLink != null && _currentBook.bookLink!.trim().isNotEmpty) {
      return _currentBook.bookLink!.trim();
    }
    return '';
  }

  Future<void> _downloadFile() async {
    if (!_hasRemoteUrl) {
      final errorMsg = 'No download URL configured for this book.';
      debugPrint('❌ Download Error: $errorMsg');
      debugPrint('❌ sourceFile: ${_currentBook.sourceFile}');
      debugPrint('❌ bookLink: ${_currentBook.bookLink}');
      setState(() {
        _state = DownloadState.error;
        _error = errorMsg;
        _statusMessage = errorMsg;
      });
      return;
    }

    setState(() {
      _state = DownloadState.downloading;
      _progress = 0.0;
      _error = null;
      _statusMessage = 'Starting download...';
      _receivedBytes = 0;
      _totalBytes = null;
    });

    final url = _downloadUrl;
    debugPrint('🔍 Download URL: $url');

    if (!url.toLowerCase().startsWith('https://')) {
      final errorMsg = 'Insecure URL blocked. Use HTTPS only.';
      debugPrint('❌ Download Error: $errorMsg');
      setState(() {
        _state = DownloadState.error;
        _error = errorMsg;
        _statusMessage = errorMsg;
      });
      return;
    }

    final file = await _localFile();
    final client = http.Client();
    IOSink? sink;

    try {
      final req = http.Request('GET', Uri.parse(url));
      setState(() => _statusMessage = 'Connecting...');

      // Add timeout handling
      final streamedResp = await client.send(req).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Download timed out after 30 seconds');
        },
      );

      debugPrint('📡 Response status: ${streamedResp.statusCode}');

      if (streamedResp.statusCode != 200) {
        final errorMsg = 'Server returned ${streamedResp.statusCode}';
        debugPrint('❌ Download Error: $errorMsg');
        setState(() {
          _state = DownloadState.error;
          _error = errorMsg;
          _statusMessage = errorMsg;
        });
        return;
      }

      // Check available space before downloading
      _totalBytes = streamedResp.contentLength;
      if (_totalBytes != null) {
        final freeSpace = await _getFreeSpace();
        debugPrint('💾 Required space: ${(_totalBytes! / (1024 * 1024)).toStringAsFixed(2)} MB');
        debugPrint('💾 Available space: ${(freeSpace / (1024 * 1024)).toStringAsFixed(2)} MB');

        if (freeSpace < _totalBytes!) {
          final errorMsg = 'Not enough storage space. Required: ${(_totalBytes! / (1024 * 1024)).toStringAsFixed(2)} MB';
          debugPrint('❌ Download Error: $errorMsg');
          setState(() {
            _state = DownloadState.error;
            _error = errorMsg;
            _statusMessage = errorMsg;
          });
          return;
        }
      }

      sink = file.openWrite();
      setState(() => _statusMessage = 'Downloading...');

      final completer = Completer<void>();

      streamedResp.stream.listen((chunk) {
        sink!.add(chunk);
        _receivedBytes += chunk.length;
        if (_totalBytes != null) {
          setState(() => _progress = (_receivedBytes / _totalBytes!).clamp(0.0, 1.0));
        } else {
          setState(() => _progress = null);
        }

        setState(() {
          _statusMessage =
          'Downloading — ${(100 * (_progress ?? 0)).toStringAsFixed(1)}%';
        });
      }, onDone: () async {
        await sink!.flush();
        await sink.close();

        setState(() {
          _localFilePath = file.path;
          _state = DownloadState.done;
          _progress = 1.0;
          _statusMessage = 'Download complete';
        });
        completer.complete();
      }, onError: (e) async {
        await sink?.close();
        await _secureDelete(file);
        final errorMsg = 'Download failed: $e';
        debugPrint('❌ Download Stream Error: $errorMsg');
        setState(() {
          _state = DownloadState.error;
          _error = errorMsg;
          _statusMessage = 'Download failed';
        });
        completer.completeError(e);
      });

      await completer.future;
    } on TimeoutException catch (e) {
      await sink?.close();
      await _secureDelete(file);
      final errorMsg = 'Download timed out: ${e.message}';
      debugPrint('❌ Download Timeout: $errorMsg');
      setState(() {
        _state = DownloadState.error;
        _error = errorMsg;
        _statusMessage = errorMsg;
      });
    } on SocketException catch (e) {
      await sink?.close();
      await _secureDelete(file);
      final errorMsg = 'Network error: ${e.message}';
      debugPrint('❌ Network Error: $errorMsg');
      setState(() {
        _state = DownloadState.error;
        _error = errorMsg;
        _statusMessage = errorMsg;
      });
    } catch (e) {
      await sink?.close();
      await _secureDelete(file);
      final errorMsg = 'Download failed: $e';
      debugPrint('❌ Download Exception: $errorMsg');
      setState(() {
        _state = DownloadState.error;
        _error = errorMsg;
        _statusMessage = errorMsg;
      });
    } finally {
      client.close();
    }
  }

  Future<void> _openReader() async {
    if (_localFilePath == null) return;
    final file = File(_localFilePath!);
    if (!await file.exists()) {
      setState(() {
        _state = DownloadState.notStarted;
        _localFilePath = null;
        _statusMessage = 'Local file missing.';
      });
      return;
    }

    final bytes = await file.readAsBytes();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EpubReaderScreen(epubBytes: bytes),
    ));
  }

  Widget _buildBottomDownloadButton() {
    if (_state == DownloadState.checking) {
      return SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_state == DownloadState.downloading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 6),
          Text(_statusMessage ?? 'Downloading...'),
        ],
      );
    }
    if (_state == DownloadState.done && _localFilePath != null) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.menu_book),
        label: const Text('Read Now'),
        onPressed: _openReader,
        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
      );
    }
    if (_state == DownloadState.error) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error ?? 'Unknown error occurred',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Download'),
            onPressed: _downloadFile,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
        ],
      );
    }

    // Not started
    return ElevatedButton.icon(
      icon: const Icon(Icons.download),
      label: const Text('Download EPUB'),
      onPressed: _downloadFile,
      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Obx(() {
        if (_loadingBookDetails.value) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 350,
              pinned: true,
              backgroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: _currentBook.coverImage,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey.shade200),
                      errorWidget: (context, url, error) =>
                      const Icon(Icons.menu_book_rounded),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildBookDetailsSection(),
            _buildDescriptionSection(),
            _buildAdditionalInfoSection(),
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        );
      }),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: _buildBottomDownloadButton(),
      ),
    );
  }

  // ------------------ Methods inside class ------------------
  SliverToBoxAdapter _buildBookDetailsSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
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
            _buildPriceSection(),
            const SizedBox(height: 20),
            _buildInfoRow('Book Code', _currentBook.bookCode),
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
                  _buildInfoRow('Availability',
                      _currentBook.canRead ? 'Available' : 'Purchase Required'),
                  const SizedBox(height: 12),
                  _buildInfoRow('Download Status',
                      _state == DownloadState.done && _localFilePath != null
                          ? 'Downloaded'
                          : 'Not Downloaded'),
                  const SizedBox(height: 12),
                  _buildInfoRow('Source File',
                      _currentBook.sourceFile != null ? 'Available' : 'Not Available'),
                ],
              ),
            ),
          ],
        ),
      ),
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
        Text(
          _currentBook.formattedPrice,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
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
}

// ------------------ EPUB Reader Screen ------------------
class EpubReaderScreen extends StatelessWidget {
  final Uint8List epubBytes;
  const EpubReaderScreen({super.key, required this.epubBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: MrEpub(
          epubBytes: epubBytes,
          initialFontSize: '110%',
          initialFontFamily: 'Default',
          fontFamilies: const ['Default', 'Serif', 'Sans', 'Monospace'],
        ),
      ),
    );
  }
}