import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/template.dart';
import '../models/wa_template_group.dart'; // Make sure this path is correct

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // ========== USER MANAGEMENT ==========
  String? getCurrentUserId() {
    return _client.auth.currentUser?.id;
  }

  // ========== WHATSAPP TEMPLATES ==========
  Future<List<WhatsAppTemplate>> getTemplates() async {
    final response = await _client
        .from('whatsapp_templates')
        .select()
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => WhatsAppTemplate.fromJson(json))
        .toList();
  }

  Future<List<WhatsAppTemplate>> getApprovedTemplates() async {
    final templates = await getTemplates();
    return templates
        .where((t) => t.status.toLowerCase().contains('approved'))
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

  // ========== WA TEMPLATE GROUPS ==========
  Future<List<WATemplateGroup>> getWATemplateGroups() async {
    final userId = getCurrentUserId();
    var query = _client.from('wa_template_groups').select();

    if (userId != null) {
      query = query.eq('user_id', userId);
    }

    final response = await query.order('id', ascending: false);
    return (response as List)
        .map((json) => WATemplateGroup.fromJson(json))
        .toList();
  }

  Future<WATemplateGroup?> getWATemplateGroup(int id) async {
    final response = await _client
        .from('wa_template_groups')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return WATemplateGroup.fromJson(response);
  }

  Future<void> insertWATemplateGroup(WATemplateGroup group) async {
    final userId = getCurrentUserId();
    final data = {
      'user_id': userId,
      'group_name': group.groupName,
      'group_contacts': group.groupContacts,
    };

    debugPrint('Inserting group: ${group.groupName}');
    await _client.from('wa_template_groups').insert(data);
    debugPrint('Insert successful');
  }

  Future<void> updateWATemplateGroup(int id, WATemplateGroup group) async {
    final data = {
      'group_name': group.groupName,
      'group_contacts': group.groupContacts,
    };

    debugPrint('Updating group: ${group.groupName}');
    await _client.from('wa_template_groups').update(data).eq('id', id);
  }

  Future<void> deleteWATemplateGroup(int id) async {
    debugPrint('Deleting group with id: $id');
    await _client.from('wa_template_groups').delete().eq('id', id);
  }

  // ========== BULK OPERATIONS FOR GROUPS ==========
  Future<Map<String, dynamic>> getGroupStats(int groupId) async {
    final group = await getWATemplateGroup(groupId);
    if (group == null) {
      return {'exists': false};
    }

    return {
      'exists': true,
      'name': group.groupName,
      'contact_count': group.groupContacts.length,
      'group_id': group.id,
    };
  }

  Future<void> addMultipleContacts(
      int groupId, List<Map<String, String>> newContacts) async {
    final group = await getWATemplateGroup(groupId);
    if (group == null) throw Exception('Group not found');

    final updatedGroup = WATemplateGroup(
      id: group.id,
      userId: group.userId,
      groupName: group.groupName,
      groupContacts: [...group.groupContacts, ...newContacts],
    );

    await updateWATemplateGroup(groupId, updatedGroup);
  }

  Future<List<WATemplateGroup>> searchGroups(String searchTerm) async {
    final userId = getCurrentUserId();
    var query = _client
        .from('wa_template_groups')
        .select()
        .ilike('group_name', '%$searchTerm%');

    if (userId != null) {
      query = query.eq('user_id', userId);
    }

    final response = await query.order('id', ascending: false);
    return (response as List)
        .map((json) => WATemplateGroup.fromJson(json))
        .toList();
  }

  Future<List<Map<String, String>>> exportGroupContacts(int groupId) async {
    final group = await getWATemplateGroup(groupId);
    if (group == null) throw Exception('Group not found');
    return group.groupContacts;
  }
}
