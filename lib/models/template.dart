import 'package:flutter/foundation.dart';

class WhatsAppTemplate {
  final String id;
  final String name;
  final String category;
  final String language;
  final String body;
  final String? footer;
  final Map<String, dynamic>? variables;
  final List<Map<String, dynamic>>? buttons;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? headerMediaUrl;
  final String? headerText;
  final Map<String, dynamic>? sampleContent;
  final String? metaBusinessAccountId;
  final String? whatsappPhoneNumberId;
  final String? whatsappNumericId;
  final String? headerMediaId;
  final String? headerMediaType;

  WhatsAppTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.language,
    required this.body,
    this.footer,
    this.variables,
    this.buttons,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.headerMediaUrl,
    this.headerText,
    this.sampleContent,
    this.metaBusinessAccountId,
    this.whatsappPhoneNumberId,
    this.whatsappNumericId,
    this.headerMediaId,
    this.headerMediaType,
  });

  factory WhatsAppTemplate.fromJson(Map<String, dynamic> json) {
    // Safely parse variables – if it's a Map use it, otherwise ignore
    Map<String, dynamic>? parsedVariables;
    if (json['variables'] != null) {
      if (json['variables'] is Map) {
        parsedVariables = Map<String, dynamic>.from(json['variables']);
      } else {
        debugPrint('Warning: variables is not a Map: ${json['variables']}');
      }
    }

    // Safely parse sampleContent
    Map<String, dynamic>? parsedSampleContent;
    if (json['sample_content'] != null) {
      if (json['sample_content'] is Map) {
        parsedSampleContent = Map<String, dynamic>.from(json['sample_content']);
      } else {
        debugPrint('Warning: sample_content is not a Map: ${json['sample_content']}');
      }
    }

    return WhatsAppTemplate(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      language: json['language'],
      body: json['body'],
      footer: json['footer'],
      variables: parsedVariables,
      buttons: json['buttons'] != null ? List<Map<String, dynamic>>.from(json['buttons']) : null,
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      headerMediaUrl: json['header_media_url'],
      headerText: json['header_text'],
      sampleContent: parsedSampleContent,
      metaBusinessAccountId: json['meta_business_account_id'],
      whatsappPhoneNumberId: json['whatsapp_phone_number_id'],
      whatsappNumericId: json['whatsapp_numeric_id'],
      headerMediaId: json['header_media_id'],
      headerMediaType: json['header_media_type'],
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'name': name,
      'category': category,
      'language': language,
      'body': body,
      'footer': footer,
      'variables': variables,
      'buttons': buttons,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'header_media_url': headerMediaUrl,
      'header_text': headerText,
      'sample_content': sampleContent,
      'meta_business_account_id': metaBusinessAccountId,
      'whatsapp_phone_number_id': whatsappPhoneNumberId,
      'whatsapp_numeric_id': whatsappNumericId,
      'header_media_id': headerMediaId,
      'header_media_type': headerMediaType,
    };
    // Only include id if it's not empty (to let DB generate for new rows)
    if (id.isNotEmpty) {
      json['id'] = id;
    }
    return json;
  }

  WhatsAppTemplate copyWith({String? status, String? whatsappNumericId, DateTime? updatedAt}) {
    return WhatsAppTemplate(
      id: id,
      name: name,
      category: category,
      language: language,
      body: body,
      footer: footer,
      variables: variables,
      buttons: buttons,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      headerMediaUrl: headerMediaUrl,
      headerText: headerText,
      sampleContent: sampleContent,
      metaBusinessAccountId: metaBusinessAccountId,
      whatsappPhoneNumberId: whatsappPhoneNumberId,
      whatsappNumericId: whatsappNumericId ?? this.whatsappNumericId,
      headerMediaId: headerMediaId,
      headerMediaType: headerMediaType,
    );
  }
}