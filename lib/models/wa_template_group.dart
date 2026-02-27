import 'dart:convert'; // Add this for jsonDecode
import 'package:flutter/foundation.dart'; // Add this for debugPrint

class WATemplateGroup {
  final int id;
  final String? userId;
  final String groupName;
  final List<Map<String, String>> groupContacts;

  WATemplateGroup({
    required this.id,
    this.userId,
    required this.groupName,
    required this.groupContacts,
  });

  factory WATemplateGroup.fromJson(Map<String, dynamic> json) {
    List<Map<String, String>> contacts = [];
    if (json['group_contacts'] != null) {
      // Handle both List and String (if stored as JSON string)
      if (json['group_contacts'] is String) {
        try {
          final decoded = jsonDecode(json['group_contacts'] as String);
          if (decoded is List) {
            contacts = List<Map<String, String>>.from(
                decoded.map((contact) => Map<String, String>.from(contact)));
          }
        } catch (e) {
          debugPrint(
              'Error decoding group_contacts: $e'); // Changed from print to debugPrint
        }
      } else if (json['group_contacts'] is List) {
        contacts = List<Map<String, String>>.from(
            (json['group_contacts'] as List)
                .map((contact) => Map<String, String>.from(contact)));
      }
    }

    return WATemplateGroup(
      id: json['id'],
      userId: json['user_id'],
      groupName: json['group_name'] ?? '',
      groupContacts: contacts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'group_name': groupName,
      'group_contacts': groupContacts,
    };
  }

  // Helper method to add a contact
  WATemplateGroup addContact(String name, String number) {
    final newContacts = List<Map<String, String>>.from(groupContacts);
    newContacts.add({'name': name, 'number': number});
    return WATemplateGroup(
      id: id,
      userId: userId,
      groupName: groupName,
      groupContacts: newContacts,
    );
  }

  // Helper method to remove a contact
  WATemplateGroup removeContact(int index) {
    final newContacts = List<Map<String, String>>.from(groupContacts);
    newContacts.removeAt(index);
    return WATemplateGroup(
      id: id,
      userId: userId,
      groupName: groupName,
      groupContacts: newContacts,
    );
  }

  // Helper method to update a contact
  WATemplateGroup updateContact(int index, String name, String number) {
    final newContacts = List<Map<String, String>>.from(groupContacts);
    newContacts[index] = {'name': name, 'number': number};
    return WATemplateGroup(
      id: id,
      userId: userId,
      groupName: groupName,
      groupContacts: newContacts,
    );
  }
}
