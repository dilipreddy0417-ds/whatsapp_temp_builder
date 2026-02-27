import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/wa_template_group.dart';

class GroupFormScreen extends StatefulWidget {
  final WATemplateGroup? group;
  const GroupFormScreen({super.key, this.group});

  @override
  State<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends State<GroupFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final List<Map<String, String>> _contacts = [];

  final SupabaseService _supabase = SupabaseService();

  @override
  void initState() {
    super.initState();
    if (widget.group != null) {
      _groupNameController.text = widget.group!.groupName;
      _contacts.addAll(widget.group!.groupContacts);
    } else {
      _addContact();
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  void _addContact() {
    setState(() {
      _contacts.add({'name': '', 'number': ''});
    });
  }

  void _removeContact(int index) {
    setState(() {
      _contacts.removeAt(index);
    });
  }

  String? _validateNumber(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!value.startsWith('+')) {
      return 'Number should start with + and country code';
    }
    if (value.length < 10) {
      return 'Enter a valid number';
    }
    return null;
  }

  Future<void> _saveGroup() async {
    if (!_formKey.currentState!.validate()) return;

    final validContacts = _contacts
        .where((c) => c['name']!.isNotEmpty && c['number']!.isNotEmpty)
        .map((c) => {'name': c['name']!, 'number': c['number']!})
        .toList();

    if (validContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add at least one contact with name and number')),
      );
      return;
    }

    final group = WATemplateGroup(
      id: widget.group?.id ?? 0,
      userId: _supabase.getCurrentUserId(),
      groupName: _groupNameController.text,
      groupContacts: validContacts,
    );

    try {
      if (widget.group == null) {
        await _supabase.insertWATemplateGroup(group);
      } else {
        await _supabase.updateWATemplateGroup(widget.group!.id, group);
      }
      if (mounted) Navigator.pop(context, true);
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
        title: Text(widget.group == null ? 'Create New Group' : 'Edit Group'),
        backgroundColor: Colors.teal,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _groupNameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g., Marketing Team, VIP Customers',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
              ),
              validator: (v) => v!.isEmpty ? 'Group name is required' : null,
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Contacts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _addContact,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Contact'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            ..._contacts.asMap().entries.map((entry) {
              final index = entry.key;
              final contact = entry.value;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: contact['name'],
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                hintText: 'John Doe',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (val) => contact['name'] = val,
                              validator: (val) {
                                if (contact['number']!.isNotEmpty &&
                                    val!.isEmpty) {
                                  return 'Name required if number is entered';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: _contacts.length > 1
                                ? () => _removeContact(index)
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: contact['number'],
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp Number',
                          hintText: '+919876543210',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) => contact['number'] = val,
                        validator: (val) {
                          if (contact['name']!.isNotEmpty && val!.isEmpty) {
                            return 'Number required if name is entered';
                          }
                          return _validateNumber(val);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }), // Removed .toList()

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _saveGroup,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child:
                  Text(widget.group == null ? 'Create Group' : 'Update Group'),
            ),
          ],
        ),
      ),
    );
  }
}
