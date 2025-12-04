// models/book_model.dart
class BookModel {
  final int bookId;
  final String bookCode;
  final String title;
  final String description;
  final bool isFree;
  final double mrpPrice;
  final double discount;
  final double finalPrice;
  final String coverImage;
  final double rating;
  final int reviews;
  final bool isPurchase;
  final String? bookLink;
  final String year;
  final String month;
  final String? sourceFile; // Add this

  BookModel({
    required this.bookId,
    required this.bookCode,
    required this.title,
    required this.description,
    required this.isFree,
    required this.mrpPrice,
    required this.discount,
    required this.finalPrice,
    required this.coverImage,
    required this.rating,
    required this.reviews,
    required this.isPurchase,
    this.bookLink,
    required this.year,
    required this.month,
    this.sourceFile, // Add this
  });

  factory BookModel.fromJson(Map<String, dynamic> json) {
    // String removeLocalhost(String? url) {
    //   if (url == null) return '';
    //   return url.replaceAll('http://127.0.0.1:8000/', '');
    // }
    return BookModel(
      bookId: json['book_id'] ?? 0,
      bookCode: json['book_code'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      isFree: json['isfree'] ?? false,
      mrpPrice: double.tryParse(json['mrp_price']?.toString() ?? '0') ?? 0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0,
      finalPrice: double.tryParse(json['final_price']?.toString() ?? '0') ?? 0,
      coverImage: json['cover_image'] ?? '',
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      reviews: json['reviews'] ?? 0,
      isPurchase: json['isPurchase'] ?? false,
      bookLink: json['book_link'],
      year: json['year'] ?? '',
      month: json['month'] ?? '',
      sourceFile: json['source_file'], // Add this
      // sourceFile: removeLocalhost(json['source_file']),
    );
  }

  // Helper getters
  bool get hasDiscount => discount > 0;
  bool get canRead => isPurchase || isFree;

  String get formattedPrice {
    if (isFree) return 'Free';
    return '৳$finalPrice';
  }

  String get formattedOriginalPrice {
    if (isFree) return '';
    return '৳$mrpPrice';
  }
}