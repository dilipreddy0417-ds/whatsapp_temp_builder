import 'package:flutter/material.dart';

class ButtonEditor extends StatefulWidget {
  final List<Map<String, dynamic>> buttons;
  final Function(List<Map<String, dynamic>>) onChanged;

  const ButtonEditor(
      {super.key, required this.buttons, required this.onChanged});

  @override
  State<ButtonEditor> createState() => _ButtonEditorState();
}

class _ButtonEditorState extends State<ButtonEditor> {
  late List<Map<String, dynamic>> _buttons;

  // Map friendly names to API values
  static const Map<String, String> buttonTypeMap = {
    'Call Phone Number': 'PHONE_NUMBER',
    'Visit Website': 'URL',
    'Quick Reply': 'QUICK_REPLY',
  };

  @override
  void initState() {
    super.initState();
    _buttons = List.from(widget.buttons);
  }

  void _addButton() {
    setState(() {
      _buttons.add({'type': 'PHONE_NUMBER', 'text': '', 'phone_number': ''});
    });
    widget.onChanged(_buttons);
  }

  void _removeButton(int index) {
    setState(() => _buttons.removeAt(index));
    widget.onChanged(_buttons);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_buttons.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No buttons added. Tap "+ Add Button" to create one.'),
          ),
        ..._buttons.asMap().entries.map((entry) {
          int idx = entry.key;
          Map<String, dynamic> btn = entry.value;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Button type dropdown with friendly names
                  DropdownButtonFormField<String>(
                    initialValue: btn['type'],
                    items: buttonTypeMap.entries.map((e) {
                      return DropdownMenuItem(
                        value: e.value,
                        child: Text(e.key),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        btn['type'] = val;
                        // Clear fields that are not relevant for the new type
                        if (val == 'PHONE_NUMBER') {
                          btn.remove('url');
                          btn['phone_number'] = btn['phone_number'] ?? '';
                        } else if (val == 'URL') {
                          btn.remove('phone_number');
                          btn['url'] = btn['url'] ?? '';
                        } else if (val == 'QUICK_REPLY') {
                          btn.remove('phone_number');
                          btn.remove('url');
                        }
                      });
                      widget.onChanged(_buttons);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Button Type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Button text (common to all types)
                  TextFormField(
                    initialValue: btn['text'] ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Button Text',
                      hintText: 'e.g., "Call Now", "Learn More" (max 25 chars)',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 25,
                    onChanged: (val) {
                      btn['text'] = val;
                      widget.onChanged(_buttons);
                    },
                  ),
                  const SizedBox(height: 8),

                  // Type-specific fields
                  if (btn['type'] == 'PHONE_NUMBER') ...[
                    TextFormField(
                      initialValue: btn['phone_number'] ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'International format: +919876543210',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 20,
                      onChanged: (val) {
                        btn['phone_number'] = val;
                        widget.onChanged(_buttons);
                      },
                    ),
                  ],

                  if (btn['type'] == 'URL') ...[
                    TextFormField(
                      initialValue: btn['url'] ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Website URL',
                        hintText: 'https://example.com',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 2000,
                      onChanged: (val) {
                        btn['url'] = val;
                        widget.onChanged(_buttons);
                      },
                    ),
                  ],

                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeButton(idx),
                      tooltip: 'Remove button',
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addButton,
          icon: const Icon(Icons.add),
          label: const Text('Add Button'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Note: Marketing opt-out button is not yet supported. '
          'Maximum 2 buttons per template (excluding opt-out).',
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
