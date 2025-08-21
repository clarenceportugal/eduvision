class ServerConfig {
  // Server configuration for different environments

  // For development on computer (emulator or web)
  static const String localhostUrl = 'http://localhost:3000/api';

  // For phone access - UPDATE THIS TO YOUR COMPUTER'S IP ADDRESS
  // Run 'find_ip.bat' to find your computer's IP address
  static const String phoneUrl =
      'http://192.168.68.105:3000/api'; // Updated to your current IP

  // Current active URL - change this based on where you're running the app
  static const String currentBaseUrl =
      phoneUrl; // Change to localhostUrl for computer development

  // Helper method to get the current base URL
  static String get baseUrl => currentBaseUrl;

  // Helper method to check if we're in development mode
  static bool get isDevelopment => baseUrl.contains('localhost');

  // Helper method to get server status URL
  static String get statusUrl => '$baseUrl/test';

  // Helper method to get server URL without /api
  static String get serverUrl => currentBaseUrl.replaceAll('/api', '');
}
