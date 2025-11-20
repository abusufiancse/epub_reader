class AppConstants {
  static const String appName = 'EPUB Reader';

  // For Android emulator use: http://10.0.2.2:8000/api/
  // For iOS simulator use: http://127.0.0.1:8000/api/
  // For real device use your local IP: http://192.168.x.x:8000/api/
  static const String baseUrl = 'http://10.0.2.2:8000/api/';
  // Shared Preferences Keys
  static const String themeKey = 'theme';
  static const String fontSizeKey = 'font_size';
  static const String fontFamilyKey = 'font_family';
  static const String lineHeightKey = 'line_height';

  // API Endpoints
  static const String loginEndpoint = 'login';
  static const String registerEndpoint = 'register';
  static const String booksEndpoint = 'books';
  static const String bookmarksEndpoint = 'bookmarks';
  static const String highlightsEndpoint = 'highlights';
}