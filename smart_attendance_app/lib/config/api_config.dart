// API Configuration
class ApiConfig {
  // Use your computer's local IP for testing on physical device
  // Your phone and computer must be on the same WiFi network
  static String baseUrl = 'http://10.220.109.201:8000/api';
  
  // Timeout settings
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
