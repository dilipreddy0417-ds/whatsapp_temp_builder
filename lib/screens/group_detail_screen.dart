import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_api.dart';
import '../models/wa_template_group.dart';
import '../models/template.dart';
import 'group_form_screen.dart'; // Add this import

class GroupDetailScreen extends StatefulWidget {
  final WATemplateGroup group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late WATemplateGroup _group;
  final SupabaseService _supabase = SupabaseService(); // Fixed
  final WhatsAppApiService _whatsapp = WhatsAppApiService();

  List<WhatsAppTemplate> _approvedTemplates = [];
  bool _isLoadingTemplates = false;
  bool _isSending = false;
  int _successCount = 0;
  int _failCount = 0;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _loadApprovedTemplates();
  }

  Future<void> _loadApprovedTemplates() async {
    setState(() => _isLoadingTemplates = true);
    try {
      _approvedTemplates = await _supabase.getApprovedTemplates();
    } catch (e) {
      debugPrint('Error loading templates: $e');
    } finally {
      setState(() => _isLoadingTemplates = false);
    }
  }

  void _showTemplatePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const Text(
              'Select Template to Send',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This template will be sent to all ${_group.groupContacts.length} contacts',
              style: const TextStyle(color: Colors.grey),
            ),
            const Divider(height: 24),
            if (_isLoadingTemplates)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_approvedTemplates.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber,
                          size: 48, color: Colors.orange),
                      const SizedBox(height: 16),
                      const Text('No approved templates available'),
                      const SizedBox(height: 8),
                      Text(
                        'Create and approve a template first',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _approvedTemplates.length,
                  itemBuilder: (context, index) {
                    final t = _approvedTemplates[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal[100],
                          child: Icon(
                            t.headerMediaType == 'IMAGE'
                                ? Icons.image
                                : Icons.text_fields,
                            color: Colors.teal,
                          ),
                        ),
                        title: Text(t.name),
                        subtitle: Text('${t.category} · ${t.language}'),
                        trailing: const Icon(Icons.send),
                        onTap: () {
                          Navigator.pop(ctx);
                          _confirmSend(t);
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSend(WhatsAppTemplate template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send to Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Template: ${template.name}'),
            Text('Contacts: ${_group.groupContacts.length}'),
            const SizedBox(height: 16),
            const Text(
                'This will send the template to all contacts. Continue?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _sendToGroup(template);
    }
  }

  Future<void> _sendToGroup(WhatsAppTemplate template) async {
    setState(() {
      _isSending = true;
      _successCount = 0;
      _failCount = 0;
    });

    for (final contact in _group.groupContacts) {
      try {
        final bodyVars = [contact['name']!];
        String? mediaId = template.headerMediaId;

        if (template.headerMediaType == 'IMAGE' && mediaId == null) {
          debugPrint(
              '⚠️ Template ${template.name} has no media ID – skipping ${contact['name']}');
          _failCount++;
          continue;
        }

        final List<Map<String, dynamic>> components = [];

        if (template.headerMediaType != null &&
            template.headerMediaType != 'NONE' &&
            mediaId != null) {
          components.add({
            'type': 'header',
            'parameters': [
              {
                'type': template.headerMediaType!.toLowerCase(),
                template.headerMediaType!.toLowerCase(): {'id': mediaId}
              }
            ]
          });
        }

        if (bodyVars.isNotEmpty) {
          components.add({
            'type': 'body',
            'parameters':
                bodyVars.map((val) => {'type': 'text', 'text': val}).toList()
          });
        }

        await _whatsapp.sendTemplateMessage(
          to: contact['number']!,
          templateName: template.name,
          languageCode: template.language,
          components: components,
        );

        _successCount++;
        debugPrint('✅ Sent to ${contact['name']} (${contact['number']})');
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('❌ Failed for ${contact['number']}: $e');
        _failCount++;
      }
    }

    setState(() => _isSending = false);

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_failCount == 0 ? '✅ Success' : '⚠️ Completed'),
          content: Text(
            'Successfully sent: $_successCount\nFailed: $_failCount',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_group.groupName),
        backgroundColor: Colors.teal,
        actions: [
          if (!_isSending)
            IconButton(
              icon: const Icon(Icons.send),
              onPressed:
                  _approvedTemplates.isEmpty ? null : _showTemplatePicker,
              tooltip: 'Send Template to Group',
            ),
        ],
      ),
      body: _isSending
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Sending to ${_group.groupContacts.length} contacts...',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Success: $_successCount | Failed: $_failCount',
                    style: TextStyle(
                      fontSize: 14,
                      color: _failCount > 0 ? Colors.orange : Colors.green,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        'Total Contacts',
                        _group.groupContacts.length.toString(),
                        Icons.people,
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.teal.shade200,
                      ),
                      _buildStatCard(
                        'Approved Templates',
                        _approvedTemplates.length.toString(),
                        Icons.message,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Contacts',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupFormScreen(group: _group),
                            ),
                          ).then((updated) {
                            if (updated == true) {
                              _supabase
                                  .getWATemplateGroup(_group.id)
                                  .then((group) {
                                if (group != null && mounted) {
                                  setState(() => _group = group);
                                }
                              });
                            }
                          });
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _group.groupContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _group.groupContacts[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal[100],
                            child: Text(
                              contact['name']![0].toUpperCase(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(contact['name']!),
                          subtitle: Text(contact['number']!),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.teal, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
