import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../utils/constants.dart';

class WhatsAppApiService {
  final String accessToken = Constants.whatsappAccessToken;
  final String businessAccountId = Constants.whatsappBusinessAccountId;
  final String phoneNumberId = Constants.metaWAPhoneNumberId;
  final String appId = Constants.appId;

  // Upload media to phone (returns media ID)
  Future<String> uploadMediaToPhone(File file, String messagingProduct) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://graph.facebook.com/v23.0/$phoneNumberId/media'),
    );
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.fields['messaging_product'] = messagingProduct;
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType.parse(mimeType),
      ),
    );
    var response = await request.send();
    var responseBody = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      return data['id'];
    } else {
      throw Exception('Media upload failed: $responseBody');
    }
  }

  // Create an upload session for an app (returns session ID)
  Future<String> createUploadSession({
    required String fileName,
    required int fileLength,
    required String fileType,
  }) async {
    final url = Uri.parse('https://graph.facebook.com/v23.0/$appId/uploads');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'file_name': fileName,
        'file_length': fileLength,
        'file_type': fileType,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['id'];
    } else {
      throw Exception('Create upload session failed: ${response.body}');
    }
  }

  // Upload the actual file bytes to the session and get the handle
  Future<String> uploadFileToSession(String sessionId, File file) async {
    final url = Uri.parse('https://graph.facebook.com/v23.0/$sessionId');
    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.headers['file_offset'] = '0';
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType.parse(mimeType),
      ),
    );
    var response = await request.send();
    var responseBody = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      return data['h'];
    } else {
      throw Exception('File upload to session failed: $responseBody');
    }
  }

  // Convenience method: upload an image and get the handle for templates
  Future<String> uploadImageAndGetHandle(File imageFile) async {
    final fileName = imageFile.path.split('/').last;
    final fileLength = await imageFile.length();
    final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
    final sessionId = await createUploadSession(
      fileName: fileName,
      fileLength: fileLength,
      fileType: mimeType,
    );
    final handle = await uploadFileToSession(sessionId, imageFile);
    return handle;
  }

  // Fetch all templates from WhatsApp Business Account
  Future<List<Map<String, dynamic>>> getTemplates() async {
    final url = Uri.parse(
        'https://graph.facebook.com/v23.0/$businessAccountId/message_templates');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['data']);
    } else {
      throw Exception('Failed to fetch templates: ${response.body}');
    }
  }

  // Create a message template
  Future<Map<String, dynamic>> createTemplate(
      Map<String, dynamic> templateData) async {
    final url = Uri.parse(
        'https://graph.facebook.com/v23.0/$businessAccountId/message_templates');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(templateData),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Template creation failed: ${response.body}');
    }
  }

  // Delete template by numeric ID
  Future<void> deleteTemplate(String templateId) async {
    final url = Uri.parse('https://graph.facebook.com/v23.0/$templateId');
    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw Exception('Delete failed: ${response.body}');
    }
  }

  // Fetch a single template status by ID
  Future<Map<String, dynamic>> getTemplateStatus(String templateId) async {
    final url = Uri.parse('https://graph.facebook.com/v23.0/$templateId');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch template status: ${response.body}');
    }
  }

  // Send a template message (low‑level, components must be built manually)
  Future<void> sendTemplateMessage({
    required String to,
    required String templateName,
    required String languageCode,
    required List<Map<String, dynamic>> components,
  }) async {
    final body = {
      'messaging_product': 'whatsapp',
      'to': to,
      'type': 'template',
      'template': {
        'name': templateName,
        'language': {'code': languageCode},
        'components': components,
      },
    };
    final url =
        Uri.parse('https://graph.facebook.com/v23.0/$phoneNumberId/messages');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('Send failed: ${response.body}');
    }
  }

  // NEW: Convenience method to send a template message with header media and body variables
  Future<void> sendTemplateMessageWithMedia({
    required String to,
    required String templateName,
    required String languageCode,
    String? headerMediaType, // e.g., 'IMAGE', 'VIDEO', 'DOCUMENT'
    String? mediaId, // ID from uploadMediaToPhone
    String? mediaLink, // public URL (if you don't have an ID)
    List<String> bodyVariables = const [],
  }) async {
    List<Map<String, dynamic>> components = [];

    // Header component (if media is provided)
    if (headerMediaType != null && (mediaId != null || mediaLink != null)) {
      Map<String, dynamic> mediaObj = {};
      if (mediaId != null && mediaId.isNotEmpty) {
        mediaObj = {"id": mediaId};
      } else if (mediaLink != null && mediaLink.isNotEmpty) {
        mediaObj = {"link": mediaLink};
      }

      components.add({
        "type": "header", // Must be lowercase
        "parameters": [
          {
            "type": headerMediaType.toLowerCase(),
            headerMediaType.toLowerCase(): mediaObj,
          }
        ],
      });
    }

    // Body component with variables
    if (bodyVariables.isNotEmpty) {
      List<Map<String, dynamic>> bodyParams =
          bodyVariables.map((val) => {"type": "text", "text": val}).toList();
      components.add({
        "type": "body",
        "parameters": bodyParams,
      });
    }

    // Call the existing low-level send method with the constructed components
    await sendTemplateMessage(
      to: to,
      templateName: templateName,
      languageCode: languageCode,
      components: components,
    );
  }
}
