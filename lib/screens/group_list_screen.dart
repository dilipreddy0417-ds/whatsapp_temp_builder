import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/wa_template_group.dart';
import 'group_form_screen.dart';
import 'group_detail_screen.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  final SupabaseService _supabase = SupabaseService();
  late Future<List<WATemplateGroup>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  void _refreshList() {
    setState(() {
      _groupsFuture = _supabase.getWATemplateGroups();
    });
  }

  Future<void> _deleteGroup(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text('Are you sure you want to delete this group?'),
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
      await _supabase.deleteWATemplateGroup(id);
      _refreshList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group deleted successfully')),
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
        title: const Text('Contact Groups'),
        backgroundColor: Colors.teal[200],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const GroupFormScreen()),
          );
          if (result == true) _refreshList();
        },
        icon: const Icon(Icons.group_add),
        label: const Text('New Group'),
        backgroundColor: Colors.green[100],
        foregroundColor: Colors.black87,
      ),
      body: FutureBuilder<List<WATemplateGroup>>(
        future: _groupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final groups = snapshot.data ?? [];
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No groups yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to create your first group',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal[100],
                    child: Text(
                      group.groupContacts.length.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    group.groupName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${group.groupContacts.length} contacts'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GroupFormScreen(group: group),
                          ),
                        ).then((_) => _refreshList());
                      } else if (value == 'delete') {
                        _deleteGroup(group.id);
                      } else if (value == 'view') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GroupDetailScreen(group: group),
                          ),
                        );
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('View'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Edit'),
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
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
