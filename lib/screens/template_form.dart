import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
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
  String? _headerFileName;
  List<Map<String, dynamic>> _buttons = [];
  final Map<String, String> _sampleVariables = {};

  final SupabaseService _supabase = SupabaseService();
  final WhatsAppApiService _whatsapp = WhatsAppApiService();

  // Colors
  final Color primaryColor = Colors.teal;
  final Color accentColor = Colors.orange;
  final Color backgroundColor = Colors.grey[50]!;
  final Color cardColor = Colors.white;
  final Color borderColor = Colors.grey[300]!;

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
        titleTextStyle: const TextStyle(
            color: Colors.red, fontWeight: FontWeight.bold), // Fixed
        content: SingleChildScrollView(
          child: SelectableText(friendlyMessage),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red
                  .withValues(alpha: 0.1), // Fixed: replaced withOpacity
              foregroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMedia() async {
    if (_headerType == 'IMAGE') {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _headerFile = File(image.path);
          _headerFileName = image.name;
        });
      }
    } else if (_headerType == 'VIDEO') {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _headerFile = File(result.files.single.path!);
          _headerFileName = result.files.single.name;
        });
      }
    } else if (_headerType == 'DOCUMENT') {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'xls',
          'xlsx',
          'txt'
        ],
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _headerFile = File(result.files.single.path!);
          _headerFileName = result.files.single.name;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final variables = extractVariables(_bodyController.text);

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey
                    .withValues(alpha: 0.3), // Fixed: replaced withOpacity
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.teal),
              const SizedBox(height: 16),
              Text(
                'Submitting template...',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ),
    );

    String? headerHandle;
    String? headerMediaId;

    try {
      if (_headerType != 'NONE' &&
          _headerType != 'TEXT' &&
          _headerFile != null) {
        debugPrint(
            '📤 Uploading ${_headerType.toLowerCase()} via Resumable Upload to get handle...');

        if (_headerType == 'IMAGE') {
          headerHandle =
              await _whatsapp.uploadImageForTemplateHeader(_headerFile!);
          headerMediaId =
              await _whatsapp.uploadMediaForMessage(_headerFile!, 'whatsapp');
        } else if (_headerType == 'VIDEO') {
          headerHandle =
              await _whatsapp.uploadVideoForTemplateHeader(_headerFile!);
          headerMediaId =
              await _whatsapp.uploadMediaForMessage(_headerFile!, 'whatsapp');
        } else if (_headerType == 'DOCUMENT') {
          headerHandle =
              await _whatsapp.uploadDocumentForTemplateHeader(_headerFile!);
          headerMediaId =
              await _whatsapp.uploadMediaForMessage(_headerFile!, 'whatsapp');
        }

        debugPrint('📸 Header handle obtained: $headerHandle');
        debugPrint('📸 Permanent media ID obtained: $headerMediaId');
      }

      List<Map<String, dynamic>> components = [];

      if (_headerType == 'TEXT' &&
          _headerText != null &&
          _headerText!.isNotEmpty) {
        components.add({
          'type': 'HEADER',
          'format': 'TEXT',
          'text': _headerText,
        });
      } else if (_headerType != 'NONE' &&
          _headerType != 'TEXT' &&
          headerHandle != null) {
        components.add({
          'type': 'HEADER',
          'format': _headerType,
          'example': {
            'header_handle': [headerHandle]
          },
        });
        debugPrint(
            '📸 Added header component with handle array: [$headerHandle]');
      }

      Map<String, dynamic> bodyComponent = {
        'type': 'BODY',
        'text': _bodyController.text,
      };
      if (variables.isNotEmpty) {
        if (_sampleVariables.isEmpty) {
          if (mounted) Navigator.pop(context);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Please provide sample values for all variables'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
          return;
        }
        bodyComponent['example'] = {
          'body_text': [_sampleVariables.values.toList()]
        };
      }
      components.add(bodyComponent);

      if (_footerController.text.isNotEmpty) {
        components.add({
          'type': 'FOOTER',
          'text': _footerController.text,
        });
      }

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
        headerMediaId: headerMediaId,
        headerMediaType: _headerType,
      );

      debugPrint('💾 Inserting template with headerMediaId: $headerMediaId');
      await _supabase.insertTemplate(newTemplate);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Template submitted for approval'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e, stack) {
      debugPrint('❌ Error during submission: $e\n$stack');
      if (mounted) {
        Navigator.pop(context);
        _showErrorDialog(e.toString());
      }
    }
  }

  List<Widget> _buildVariableInputs() {
    final vars = extractVariables(_bodyController.text);
    if (vars.isEmpty) return [];
    return vars.map((v) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: TextFormField(
          decoration: InputDecoration(
            labelText: 'Sample for $v',
            labelStyle: TextStyle(color: Colors.teal[700]),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(12),
            prefixIcon:
                Icon(Icons.text_fields, color: Colors.teal[300], size: 20),
          ),
          onChanged: (val) => _sampleVariables[v] = val,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.template == null ? 'Create New Template' : 'Edit Template',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Container(
        color: backgroundColor,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Template Name Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(
                                  alpha: 0.1), // Fixed: replaced withOpacity
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.label,
                                color: primaryColor, size: 20),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Template Name',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'e.g., welcome_message',
                          helperText:
                              'Lowercase letters, numbers, underscores only',
                          helperStyle:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: Icon(Icons.drive_file_rename_outline,
                              color: primaryColor),
                        ),
                        validator: _validateTemplateName,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Category & Language Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(
                                  alpha: 0.1), // Fixed: replaced withOpacity
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.category,
                                color: primaryColor, size: 20),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Category & Language',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        items: Constants.categories
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Row(
                                    children: [
                                      Icon(
                                        c == 'MARKETING'
                                            ? Icons.campaign
                                            : c == 'UTILITY'
                                                ? Icons.settings
                                                : Icons.security,
                                        size: 18,
                                        color: primaryColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(c),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _category = v!),
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: TextStyle(color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _language,
                        items: Constants.languages
                            .map((l) => DropdownMenuItem(
                                  value: l,
                                  child: Row(
                                    children: [
                                      Icon(Icons.language,
                                          size: 18, color: primaryColor),
                                      const SizedBox(width: 8),
                                      Text(l),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _language = v!),
                        decoration: InputDecoration(
                          labelText: 'Language',
                          labelStyle: TextStyle(color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Header Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(
                                  alpha: 0.1), // Fixed: replaced withOpacity
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.image,
                                color: primaryColor, size: 20),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Header',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _headerType,
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _headerType,
                        items: Constants.headerTypes
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Row(
                                    children: [
                                      Icon(
                                        t == 'NONE'
                                            ? Icons.hide_source
                                            : t == 'TEXT'
                                                ? Icons.text_fields
                                                : t == 'IMAGE'
                                                    ? Icons.image
                                                    : t == 'VIDEO'
                                                        ? Icons.video_library
                                                        : Icons
                                                            .insert_drive_file,
                                        size: 18,
                                        color: primaryColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(t),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _headerType = v!),
                        decoration: InputDecoration(
                          labelText: 'Header Type',
                          labelStyle: TextStyle(color: primaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: primaryColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      if (_headerType == 'TEXT') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          onChanged: (v) => _headerText = v,
                          decoration: InputDecoration(
                            labelText: 'Header Text',
                            labelStyle: TextStyle(color: primaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: primaryColor, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon:
                                Icon(Icons.text_fields, color: primaryColor),
                          ),
                        ),
                      ],
                      if (_headerType == 'IMAGE' ||
                          _headerType == 'VIDEO' ||
                          _headerType == 'DOCUMENT') ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _pickMedia,
                          icon: Icon(
                            _headerType == 'IMAGE'
                                ? Icons.image
                                : _headerType == 'VIDEO'
                                    ? Icons.video_library
                                    : Icons.insert_drive_file,
                          ),
                          label: Text('Choose ${_headerType.toLowerCase()}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        if (_headerFile != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _headerType == 'IMAGE'
                                      ? Icons.image
                                      : _headerType == 'VIDEO'
                                          ? Icons.video_library
                                          : Icons.insert_drive_file,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Selected File',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                      ),
                                      Text(
                                        _headerFileName ??
                                            _headerFile!.path.split('/').last,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _headerFile = null;
                                      _headerFileName = null;
                                    });
                                  },
                                  color: Colors.red,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Body Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(
                                  alpha: 0.1), // Fixed: replaced withOpacity
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.message,
                                color: primaryColor, size: 20),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Body',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: TextFormField(
                          controller: _bodyController,
                          maxLines: 8,
                          decoration: InputDecoration(
                            hintText:
                                'Enter message body. Use {{1}}, {{2}} for variables.',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(12),
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                          onChanged: (value) {
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Variables Card
              if (extractVariables(_bodyController.text).isNotEmpty) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(
                                    alpha: 0.1), // Fixed: replaced withOpacity
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.format_list_numbered,
                                  color: Colors.orange,
                                  size:
                                      20), // Fixed: changed from variables to format_list_numbered
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Sample Values for Variables',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._buildVariableInputs(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Footer Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(
                                  alpha: 0.1), // Fixed: replaced withOpacity
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.text_snippet,
                                color: Colors.purple, size: 20),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Footer (optional)',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: TextFormField(
                          controller: _footerController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Add a footer message',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Buttons Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(
                                  alpha: 0.1), // Fixed: replaced withOpacity
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.smart_button,
                                color: Colors.blue, size: 20),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Buttons',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ButtonEditor(
                        buttons: _buttons,
                        onChanged: (updated) =>
                            setState(() => _buttons = updated),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              Container(
                width: double.infinity,
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: const Text(
                    'Submit to WhatsApp',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
