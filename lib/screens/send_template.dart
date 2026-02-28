import 'package:flutter/material.dart';
import '../models/template.dart';
import '../services/whatsapp_api.dart';
import '../utils/helpers.dart';

class SendTemplateScreen extends StatefulWidget {
  final WhatsAppTemplate template;
  const SendTemplateScreen({super.key, required this.template});

  @override
  State<SendTemplateScreen> createState() => _SendTemplateScreenState();
}

class _SendTemplateScreenState extends State<SendTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final Map<String, TextEditingController> _varControllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  final WhatsAppApiService _whatsapp = WhatsAppApiService();

  @override
  void initState() {
    super.initState();
    debugPrint(
        '🔍 Template headerMediaType: ${widget.template.headerMediaType}');
    debugPrint('🔍 Template headerMediaId: ${widget.template.headerMediaId}');
    debugPrint('🔍 Full template: ${widget.template.toJson()}');

    final vars = extractVariables(widget.template.body);
    for (var v in vars) {
      _varControllers[v] = TextEditingController();
      _focusNodes[v] = FocusNode();
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (var c in _varControllers.values) {
      c.dispose();
    }
    for (var f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  /// Apply formatting to the currently focused text field
  void _applyFormatting(String varKey, String format) {
    final controller = _varControllers[varKey];
    if (controller == null) return;

    final text = controller.text;
    final selection = controller.selection;

    if (selection.isCollapsed) {
      final newText = _getFormattedPlaceholder(format);
      final newSelection =
          TextSelection.collapsed(offset: selection.start + newText.length);
      controller.text = text.substring(0, selection.start) +
          newText +
          text.substring(selection.start);
      controller.selection = newSelection;
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      final wrappedText = _wrapWithFormat(selectedText, format);

      final newText = text.substring(0, selection.start) +
          wrappedText +
          text.substring(selection.end);
      final newSelection =
          TextSelection.collapsed(offset: selection.start + wrappedText.length);

      controller.text = newText;
      controller.selection = newSelection;
    }

    setState(() {});
  }

  String _getFormattedPlaceholder(String format) {
    switch (format) {
      case 'bold':
        return '*text*';
      case 'italic':
        return '_text_';
      case 'strikethrough':
        return '~text~';
      case 'monospace':
        return '`text`';
      default:
        return '';
    }
  }

  String _wrapWithFormat(String text, String format) {
    switch (format) {
      case 'bold':
        return '*$text*';
      case 'italic':
        return '_${text}_';
      case 'strikethrough':
        return '~$text~';
      case 'monospace':
        return '`$text`';
      default:
        return text;
    }
  }

  void _showFormattingHelp() {
    showDialog(
      context: context,
      builder: (ctx) => const AlertDialog(
        title: Text('Text Formatting Guide'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Use these markers to format your text:'),
              SizedBox(height: 12),
              _HelpRow(marker: '*text*', description: 'Bold text'),
              SizedBox(height: 4),
              _HelpRow(marker: '_text_', description: 'Italic text'),
              SizedBox(height: 4),
              _HelpRow(marker: '~text~', description: 'Strikethrough'),
              SizedBox(height: 4),
              _HelpRow(marker: '`text`', description: 'Monospace/code'),
              SizedBox(height: 12),
              Text('Examples:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('*Dileep* → **Dileep**',
                  style: TextStyle(fontFamily: 'monospace')),
              Text('_Dileep_ → *Dileep*',
                  style: TextStyle(fontFamily: 'monospace')),
              SizedBox(height: 8),
              Text('You can also combine:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('_*Dileep*_ → ***Dileep***',
                  style: TextStyle(fontFamily: 'monospace')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: null,
            child: Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final bodyVars = _varControllers.values.map((c) => c.text).toList();

      // Sanitize and log the phone number
      final rawPhone = _phoneController.text;
      final cleanPhone =
          rawPhone.replaceAll('+', '').replaceAll(' ', '').replaceAll('-', '');
      debugPrint('📞 Sending to (raw): $rawPhone');
      debugPrint('📞 Sending to (clean): $cleanPhone');

      String? mediaId = widget.template.headerMediaId;

      if (widget.template.headerMediaType == 'IMAGE' && mediaId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'No media ID available. Please recreate the template.'),
            backgroundColor: Colors.orange, // Orange for warning
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      // Build components according to WhatsApp API requirements
      final List<Map<String, dynamic>> components = [];

      // Add header component if template has media header
      if (widget.template.headerMediaType != null &&
          widget.template.headerMediaType != 'NONE' &&
          mediaId != null) {
        components.add({
          'type': 'header',
          'parameters': [
            {
              'type': widget.template.headerMediaType!.toLowerCase(),
              widget.template.headerMediaType!.toLowerCase(): {'id': mediaId}
            }
          ]
        });
        debugPrint('✅ Added header component with media ID: $mediaId');
      }

      // Add body component if there are variables
      if (bodyVars.isNotEmpty) {
        components.add({
          'type': 'body',
          'parameters':
              bodyVars.map((val) => {'type': 'text', 'text': val}).toList()
        });
        debugPrint('✅ Added body component with vars: $bodyVars');
      }

      debugPrint('📦 Final components: $components');

      await _whatsapp.sendTemplateMessage(
        to: cleanPhone,
        templateName: widget.template.name,
        languageCode: widget.template.language,
        components: components,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Message sent successfully'),
            backgroundColor: Colors.green, // Green for success
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ Send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed: $e'),
            backgroundColor: Colors.red, // Red for error
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Send: ${widget.template.name}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showFormattingHelp,
            tooltip: 'Formatting Help',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Phone Number Field
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Recipient Phone Number',
                  hintText: '+919876543210',
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.all(16),
                  prefixIcon: Icon(Icons.phone, color: Colors.teal),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
            ),

            const SizedBox(height: 20),

            // Variables Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: const Text(
                'Fill variable values:',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal),
              ),
            ),

            const SizedBox(height: 8),

            // Formatting Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Select text and use formatting buttons, or type markers manually.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF0D3D63)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Variable input fields with formatting toolbar
            ..._varControllers.entries.map((entry) {
              final varKey = entry.key;
              final controller = entry.value;
              final isFocused = _focusNodes[varKey]?.hasFocus ?? false;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.teal[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              varKey,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: controller,
                        focusNode: _focusNodes[varKey],
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Enter value for $varKey',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          suffixIcon: isFocused
                              ? PopupMenuButton<String>(
                                  icon: const Icon(Icons.format_size,
                                      color: Colors.teal),
                                  tooltip: 'Formatting options',
                                  onSelected: (format) =>
                                      _applyFormatting(varKey, format),
                                  itemBuilder: (ctx) => const [
                                    PopupMenuItem(
                                      value: 'bold',
                                      child: Row(
                                        children: [
                                          Icon(Icons.format_bold,
                                              color: Colors.black),
                                          SizedBox(width: 8),
                                          Text('Bold'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'italic',
                                      child: Row(
                                        children: [
                                          Icon(Icons.format_italic,
                                              color: Colors.black),
                                          SizedBox(width: 8),
                                          Text('Italic'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'strikethrough',
                                      child: Row(
                                        children: [
                                          Icon(Icons.format_strikethrough,
                                              color: Colors.black),
                                          SizedBox(width: 8),
                                          Text('Strikethrough'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'monospace',
                                      child: Row(
                                        children: [
                                          Icon(Icons.code, color: Colors.black),
                                          SizedBox(width: 8),
                                          Text('Monospace'),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),

                      // Quick format buttons (visible when field is focused)
                      if (isFocused) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildFormatButton(varKey, 'bold',
                                  Icons.format_bold, Colors.black),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildFormatButton(varKey, 'italic',
                                  Icons.format_italic, Colors.black),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildFormatButton(varKey, 'strikethrough',
                                  Icons.format_strikethrough, Colors.black),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildFormatButton(varKey, 'monospace',
                                  Icons.code, Colors.black),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // Preview Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.preview, color: Colors.teal[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'The formatting markers (*, _, ~, `) will be converted by WhatsApp.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF004D40)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Send Button
            ElevatedButton(
              onPressed: _send,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 3,
              ),
              child: const Text(
                'Send Message',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatButton(
      String varKey, String format, IconData icon, Color color) {
    return OutlinedButton(
      onPressed: () => _applyFormatting(varKey, format),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10),
        side: BorderSide(color: Colors.teal.shade200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Icon(icon, size: 18, color: Colors.teal),
    );
  }
}

class _HelpRow extends StatelessWidget {
  final String marker;
  final String description;
  const _HelpRow({required this.marker, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child:
                Text(marker, style: const TextStyle(fontFamily: 'monospace')),
          ),
          const SizedBox(width: 8),
          Text(description),
        ],
      ),
    );
  }
}
