import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/template.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<WhatsAppTemplate>> getTemplates() async {
    final response = await _client
        .from('whatsapp_templates')
        .select()
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => WhatsAppTemplate.fromJson(json))
        .toList();
  }

  Future<void> insertTemplate(WhatsAppTemplate template) async {
    debugPrint('Inserting template: ${template.name}');
    await _client.from('whatsapp_templates').insert(template.toJson());
    debugPrint('Insert successful');
  }

  Future<void> updateTemplate(String id, Map<String, dynamic> updates) async {
    await _client.from('whatsapp_templates').update(updates).eq('id', id);
  }

  Future<void> deleteTemplate(String id) async {
    await _client.from('whatsapp_templates').delete().eq('id', id);
  }

  Future<void> updateTemplateStatus(String id, String status) async {
    await _client.from('whatsapp_templates').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String()
    }).eq('id', id);
  }

  /// New method: update status by the WhatsApp numeric ID
  Future<void> updateTemplateStatusByNumericId(
      String numericId, String status) async {
    await _client.from('whatsapp_templates').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String()
    }).eq('whatsapp_numeric_id', numericId);
  }

  Future<void> upsertTemplate(WhatsAppTemplate template) async {
    debugPrint(
        'upsertTemplate called for ${template.name} (${template.whatsappNumericId})');
    if (template.whatsappNumericId == null) {
      debugPrint('No numeric ID, inserting directly');
      await _client.from('whatsapp_templates').insert(template.toJson());
      return;
    }

    debugPrint(
        'Checking for existing template with numeric ID: ${template.whatsappNumericId}');
    final existing = await _client
        .from('whatsapp_templates')
        .select()
        .eq('whatsapp_numeric_id', template.whatsappNumericId!)
        .maybeSingle();

    if (existing != null) {
      debugPrint('Found existing, updating');

      final updateData = template.toJson();
      if (updateData['header_media_id'] == null &&
          existing['header_media_id'] != null) {
        updateData['header_media_id'] = existing['header_media_id'];
        debugPrint(
            'Preserved existing headerMediaId: ${existing['header_media_id']}');
      }

      await _client
          .from('whatsapp_templates')
          .update(updateData)
          .eq('whatsapp_numeric_id', template.whatsappNumericId!);
    } else {
      debugPrint('No existing, inserting new');
      await _client.from('whatsapp_templates').insert(template.toJson());
    }
  }
}
