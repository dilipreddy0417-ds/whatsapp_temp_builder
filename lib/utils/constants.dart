import 'package:flutter_dotenv/flutter_dotenv.dart';

class Constants {
  static String get whatsappAccessToken =>
      dotenv.env['WHATSAPP_ACCESS_TOKEN'] ?? '';
  static String get metaWAPhoneNumberId =>
      dotenv.env['META_WA_PHONE_NUMBER_ID'] ?? '';
  static String get whatsappBusinessAccountId =>
      dotenv.env['WHATSAPP_BUSINESS_ACCOUNT_ID'] ?? '';
  static String get appId => dotenv.env['APP_ID'] ?? '';
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static const List<String> categories = [
    'MARKETING',
    'UTILITY', // was 'TRANSACTIONAL'
    'AUTHENTICATION', // was 'OTP'
  ];

  static const List<String> languages = [
    'en_US', 'af', 'ar', 'bn', 'bg', 'ca', 'zh_CN', 'zh_HK', 'zh_TW', 'hr',
    'cs', 'da', 'nl',
    // add more as needed
  ];

  static const List<String> headerTypes = [
    'NONE',
    'TEXT',
    'IMAGE',
    'VIDEO',
    'DOCUMENT'
  ];
}
