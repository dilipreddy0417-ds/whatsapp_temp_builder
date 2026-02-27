import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_api.dart';
import '../models/template.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'template_form.dart';
import 'send_template.dart';
import 'preview_template.dart'; // new import

class TemplateListScreen extends StatefulWidget {
  const TemplateListScreen({super.key});

  @override
  State<TemplateListScreen> createState() => _TemplateListScreenState();
}

class _TemplateListScreenState extends State<TemplateListScreen> {
  final SupabaseService _supabase = SupabaseService();
  final WhatsAppApiService _whatsapp = WhatsAppApiService();
  late Future<List<WhatsAppTemplate>> _templatesFuture;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    setState(() {
      _templatesFuture = _supabase.getTemplates();
    });
  }

  /// Convert a template from WhatsApp API to our local model.
  /// Returns null if conversion fails.
  WhatsAppTemplate? _fromWhatsAppJson(Map<String, dynamic> json) {
    try {
      final name = json['name'] ?? 'unknown';
      debugPrint('🔄 Converting template: $name');

      String body = '';
      String? footer;
      List<Map<String, dynamic>> buttons = [];
      String? headerType;
      String? headerText;
      String? headerMediaId;

      final components = json['components'] as List? ?? [];
      for (var comp in components) {
        final type = comp['type'];
        if (type == 'BODY') {
          body = comp['text'] ?? '';
        } else if (type == 'FOOTER') {
          footer = comp['text'];
        } else if (type == 'BUTTONS') {
          buttons = List<Map<String, dynamic>>.from(comp['buttons'] ?? []);
        } else if (type == 'HEADER') {
          headerType = comp['format'];
          if (headerType == 'TEXT') {
            headerText = comp['text'];
          } else if (headerType == 'IMAGE' || headerType == 'VIDEO') {
            // Example might contain handle – we don't store it here
          }
        }
      }

      final variables = extractVariables(body);
      Map<String, dynamic>? sampleContent;
      for (var comp in components) {
        if (comp['type'] == 'BODY' && comp.containsKey('example')) {
          final example = comp['example'];
          if (example is Map && example.containsKey('body_text')) {
            final exampleList = example['body_text'] as List?;
            if (exampleList != null && exampleList.isNotEmpty) {
              final values = exampleList[0] as List;
              if (variables.length == values.length) {
                sampleContent = {};
                for (int i = 0; i < variables.length; i++) {
                  sampleContent[variables[i]] = values[i].toString();
                }
              }
            }
          }
          break;
        }
      }

      // Ensure language is a string (sometimes it's nested)
      String language = json['language'] ?? 'en_US';
      if (language is Map) {
        language = (language as Map<String, dynamic>)['code'] ?? 'en_US';
      }

      return WhatsAppTemplate(
        id: '',
        name: name,
        category: json['category'] ?? 'MARKETING',
        language: language,
        body: body,
        footer: footer,
        variables: sampleContent ?? {},
        buttons: buttons.isNotEmpty ? buttons : null,
        status: json['status'] ?? 'unknown',
        createdAt: DateTime.now(),
        metaBusinessAccountId: Constants.whatsappBusinessAccountId,
        whatsappPhoneNumberId: Constants.metaWAPhoneNumberId,
        whatsappNumericId: json['id'].toString(),
        headerMediaUrl: null,
        headerText: headerText,
        sampleContent: sampleContent,
        headerMediaId: headerMediaId,
        headerMediaType: headerType,
      );
    } catch (e, stack) {
      debugPrint('❌ Error converting template "${json['name']}": $e\n$stack');
      return null;
    }
  }

  Future<void> _syncTemplates() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      debugPrint('📡 Fetching templates from WhatsApp...');
      final whatsappTemplates = await _whatsapp.getTemplates();
      debugPrint('📦 Received ${whatsappTemplates.length} templates');

      int successCount = 0;
      for (var wt in whatsappTemplates) {
        final template = _fromWhatsAppJson(wt);
        if (template != null) {
          debugPrint(
              '✅ Upserting template: ${template.name} (${template.whatsappNumericId})');
          await _supabase.upsertTemplate(template);
          successCount++;
        } else {
          debugPrint(
              '⚠️ Skipped template: ${wt['name']} due to conversion error');
        }
      }

      if (mounted) {
        Navigator.pop(context); // close loading
        _refreshList();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Synced $successCount of ${whatsappTemplates.length} templates'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Sync error: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _checkTemplateStatus(WhatsAppTemplate template) async {
    if (template.whatsappNumericId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot check status: No WhatsApp ID')),
      );
      return;
    }

    try {
      final statusResult =
          await _whatsapp.getTemplateStatus(template.whatsappNumericId!);
      final newStatus = statusResult['status'] ?? 'unknown';

      debugPrint('📊 New status: $newStatus');

      // Update in database
      await _supabase.updateTemplateStatus(template.id, newStatus);

      // Refresh UI
      _refreshList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Status updated: $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error checking status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTemplate(WhatsAppTemplate template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      // Optionally delete from WhatsApp first
      // if (template.whatsappNumericId != null) {
      //   await _whatsapp.deleteTemplate(template.whatsappNumericId!);
      // }
      await _supabase.deleteTemplate(template.id);
      _refreshList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal[200],
        title: const Text('WhatsApp Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncTemplates,
            tooltip: 'Sync from WhatsApp',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshList,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const TemplateFormScreen()),
          );
          if (result == true) {
            _refreshList();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Template'),
        backgroundColor: Colors.green[100],
        foregroundColor: Colors.black87,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshList(),
        child: FutureBuilder<List<WhatsAppTemplate>>(
          future: _templatesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final templates = snapshot.data ?? [];
            if (templates.isEmpty) {
              return const Center(
                child: Text('No templates yet. Tap + to create or sync.'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: templates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final t = templates[index];
                final bool isApproved =
                    t.status.toLowerCase().contains('approved');
                final bool isPending =
                    t.status.toLowerCase().contains('pending');

                return Card(
                  child: ListTile(
                    leading: Icon(
                      isApproved
                          ? Icons.check_circle
                          : isPending
                              ? Icons.pending
                              : Icons.error,
                      color: isApproved
                          ? Colors.green
                          : isPending
                              ? Colors.orange
                              : Colors.red,
                    ),
                    title: Text(
                      t.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Language: ${t.language}'),
                        Text('Status: ${t.status}'),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'preview':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PreviewTemplateScreen(template: t),
                              ),
                            );
                            break;
                          case 'send':
                            if (isApproved) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SendTemplateScreen(template: t),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Template not approved yet'),
                                ),
                              );
                            }
                            break;
                          case 'refresh':
                            _checkTemplateStatus(t);
                            break;
                          case 'delete':
                            _deleteTemplate(t);
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) {
                        return [
                          const PopupMenuItem(
                            value: 'preview',
                            child: Row(
                              children: [
                                Icon(Icons.visibility, color: Colors.purple),
                                SizedBox(width: 8),
                                Text('Preview'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'send',
                            child: Row(
                              children: [
                                Icon(Icons.send, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Send'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'refresh',
                            child: Row(
                              children: [
                                Icon(Icons.refresh, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Refresh Status'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ];
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
