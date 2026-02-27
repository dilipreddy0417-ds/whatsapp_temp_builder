import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/template.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_api.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/button_editor.dart';

class TemplateFormScreen extends StatefulWidget {
  final WhatsAppTemplate? template;
  const TemplateFormScreen({super.key, this.template});

  @override
  State<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends State<TemplateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bodyController;
  late TextEditingController _footerController;
  String _category = 'MARKETING';
  String _language = 'en_US';
  String _headerType = 'NONE';
  String? _headerText;
  File? _headerFile;
  List<Map<String, dynamic>> _buttons = [];
  final Map<String, String> _sampleVariables = {};

  final SupabaseService _supabase = SupabaseService();
  final WhatsAppApiService _whatsapp = WhatsAppApiService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template?.name ?? '');
    _bodyController = TextEditingController(text: widget.template?.body ?? '');
    _footerController =
        TextEditingController(text: widget.template?.footer ?? '');
    if (widget.template != null) {
      _category = widget.template!.category;
      _language = widget.template!.language;
      if (widget.template!.buttons != null) {
        _buttons = List.from(widget.template!.buttons!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bodyController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  String? _validateTemplateName(String? value) {
    if (value == null || value.isEmpty) return 'Template name is required';
    final RegExp nameRegex = RegExp(r'^[a-z0-9_]+$');
    if (!nameRegex.hasMatch(value)) {
      return 'Only lowercase letters, numbers, and underscores allowed';
    }
    return null;
  }

  String _parseErrorMessage(String errorString) {
    final RegExp regex = RegExp(r'\{.*\}', dotAll: true);
    final match = regex.firstMatch(errorString);
    if (match != null) {
      try {
        final Map<String, dynamic> errorJson = jsonDecode(match.group(0)!);
        if (errorJson.containsKey('error')) {
          final error = errorJson['error'];
          if (error is Map) {
            if (error.containsKey('error_user_msg')) {
              return error['error_user_msg'];
            } else if (error.containsKey('message')) {
              return error['message'];
            }
          }
        }
      } catch (_) {}
    }
    return errorString;
  }

  void _showErrorDialog(String errorMessage) {
    final friendlyMessage = _parseErrorMessage(errorMessage);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submission Failed'),
        content: SingleChildScrollView(
          child: SelectableText(friendlyMessage),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final variables = extractVariables(_bodyController.text);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? headerHandle;
    String? headerMediaId;

    try {
      // For image header: upload using Resumable Upload to get handle (for template)
      // and also upload to phone media endpoint to get media ID (for sending)
      if (_headerType == 'IMAGE' && _headerFile != null) {
        debugPrint('📤 Uploading image via Resumable Upload to get handle...');
        headerHandle =
            await _whatsapp.uploadImageForTemplateHeader(_headerFile!);
        debugPrint('📸 Header handle obtained: $headerHandle');

        debugPrint('📤 Uploading same image to phone media endpoint...');
        headerMediaId =
            await _whatsapp.uploadMediaForMessage(_headerFile!, 'whatsapp');
        debugPrint('📸 Permanent media ID obtained: $headerMediaId');
      }

      List<Map<String, dynamic>> components = [];

      // Header component for template creation
      if (_headerType == 'TEXT' &&
          _headerText != null &&
          _headerText!.isNotEmpty) {
        components.add({
          'type': 'HEADER',
          'format': 'TEXT',
          'text': _headerText,
        });
      } else if (_headerType == 'IMAGE' && headerHandle != null) {
        // CRITICAL: header_handle must be inside an array
        components.add({
          'type': 'HEADER',
          'format': 'IMAGE',
          'example': {
            'header_handle': [headerHandle] // Array, not a string
          },
        });
        debugPrint(
            '📸 Added header component with handle array: [$headerHandle]');
      }

      // Body component with example values
      Map<String, dynamic> bodyComponent = {
        'type': 'BODY',
        'text': _bodyController.text,
      };
      if (variables.isNotEmpty) {
        if (_sampleVariables.isEmpty) {
          if (mounted) Navigator.pop(context);
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Please provide sample values for all variables')),
          );
          return;
        }
        bodyComponent['example'] = {
          'body_text': [_sampleVariables.values.toList()]
        };
      }
      components.add(bodyComponent);

      // Footer component
      if (_footerController.text.isNotEmpty) {
        components.add({
          'type': 'FOOTER',
          'text': _footerController.text,
        });
      }

      // Buttons component
      if (_buttons.isNotEmpty) {
        components.add({
          'type': 'BUTTONS',
          'buttons': _buttons,
        });
      }

      final templateData = {
        'name': _nameController.text,
        'language': _language,
        'category': _category,
        'components': components,
      };

      debugPrint('📦 Sending template: ${jsonEncode(templateData)}');

      final result = await _whatsapp.createTemplate(templateData);
      final templateId = result['id'];

      // Fetch actual status from WhatsApp
      String actualStatus = 'pending';
      try {
        final statusResult = await _whatsapp.getTemplateStatus(templateId);
        actualStatus = statusResult['status'] ?? 'pending';
        debugPrint('✅ Retrieved actual status: $actualStatus');
      } catch (e) {
        debugPrint('⚠️ Could not fetch status, defaulting to pending: $e');
      }

      final newTemplate = WhatsAppTemplate(
        id: '',
        name: _nameController.text,
        category: _category,
        language: _language,
        body: _bodyController.text,
        footer: _footerController.text,
        variables:
            variables.asMap().map((i, v) => MapEntry(v, _sampleVariables[v])),
        buttons: _buttons,
        status: actualStatus,
        createdAt: DateTime.now(),
        metaBusinessAccountId: Constants.whatsappBusinessAccountId,
        whatsappPhoneNumberId: Constants.metaWAPhoneNumberId,
        whatsappNumericId: templateId,
        headerMediaUrl: null,
        headerText: _headerText,
        sampleContent: null,
        headerMediaId:
            headerMediaId, // Store the permanent media ID for sending
        headerMediaType: _headerType,
      );

      debugPrint('💾 Inserting template with headerMediaId: $headerMediaId');
      await _supabase.insertTemplate(newTemplate);

      if (mounted) {
        Navigator.pop(context); // close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Template submitted for approval')),
        );
        Navigator.pop(context, true);
      }
    } catch (e, stack) {
      debugPrint('❌ Error during submission: $e\n$stack');
      if (mounted) {
        Navigator.pop(context); // close loading dialog
        _showErrorDialog(e.toString());
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _headerFile = File(image.path));
    }
  }

  List<Widget> _buildVariableInputs() {
    final vars = extractVariables(_bodyController.text);
    if (vars.isEmpty) return [];
    return vars.map((v) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TextFormField(
          decoration: InputDecoration(labelText: 'Sample for $v'),
          onChanged: (val) => _sampleVariables[v] = val,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null ? 'New Template' : 'Edit Template'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Template Name',
                helperText: 'Lowercase letters, numbers, underscores only',
              ),
              validator: _validateTemplateName,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: Constants.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _language,
              items: Constants.languages
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => _language = v!),
              decoration: const InputDecoration(labelText: 'Language'),
            ),
            const SizedBox(height: 24),
            const Text('Header', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _headerType,
                    items: Constants.headerTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _headerType = v!),
                  ),
                ),
              ],
            ),
            if (_headerType == 'TEXT') ...[
              const SizedBox(height: 8),
              TextFormField(
                onChanged: (v) => _headerText = v,
                decoration: const InputDecoration(labelText: 'Header Text'),
              ),
            ],
            if (_headerType == 'IMAGE') ...[
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _pickImage,
                child: const Text('Choose Image'),
              ),
              if (_headerFile != null) Text('File: ${_headerFile!.path}'),
            ],
            const SizedBox(height: 24),
            const Text('Body', style: TextStyle(fontWeight: FontWeight.bold)),
            TextFormField(
              controller: _bodyController,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Enter message body. Use {{1}}, {{2}} for variables.',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
              onChanged: (value) {
                setState(() {}); // rebuild to show/hide variable inputs
              },
            ),
            const SizedBox(height: 16),
            const Text('Sample Values for Variables'),
            ..._buildVariableInputs(),
            const SizedBox(height: 24),
            const Text('Footer (optional)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextFormField(
              controller: _footerController,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Footer text'),
            ),
            const SizedBox(height: 24),
            const Text('Buttons',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ButtonEditor(
              buttons: _buttons,
              onChanged: (updated) => setState(() => _buttons = updated),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Submit to WhatsApp'),
            ),
          ],
        ),
      ),
    );
  }
}
