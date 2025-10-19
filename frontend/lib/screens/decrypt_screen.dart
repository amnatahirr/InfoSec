import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../providers/backup_provider.dart';

class DecryptScreen extends StatefulWidget {
  const DecryptScreen({Key? key}) : super(key: key);

  @override
  State<DecryptScreen> createState() => _DecryptScreenState();
}

class _DecryptScreenState extends State<DecryptScreen> {
  String? _selectedEncryptedFile;
  final TextEditingController _passwordController = TextEditingController();
  Map<String, dynamic>? _previewData;
  bool _showPreview = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _isEncryptedFile(String filePath) async {
    try {
      final file = File(filePath);
      final fileSize = await file.length();
      
      // Encrypted files must have at least: salt (64) + iv (12) + authTag (16) = 92 bytes
      if (fileSize < 92) {
        return false;
      }
      
      // Read first 92 bytes to validate encryption format
      final bytes = await file.openRead(0, 92).toList();
      return bytes.isNotEmpty && bytes[0].length >= 92;
    } catch (e) {
      return false;
    }
  }

  Future<void> _selectEncryptedFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final filePath = result.files.first.path;
      
      if (filePath != null && await _isEncryptedFile(filePath)) {
        setState(() {
          _selectedEncryptedFile = filePath;
          _previewData = null;
          _showPreview = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected file is not encrypted. Please select a valid encrypted file.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _previewDecryptedContent() async {
    if (_selectedEncryptedFile == null || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file and enter password')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final backupProvider = context.read<BackupProvider>();

    final preview = await backupProvider.decryptFilePreview(
      _selectedEncryptedFile!,
      _passwordController.text,
      authProvider.token!,
    );

    if (preview != null && preview['success'] != false) {
      setState(() {
        _previewData = preview;
        _showPreview = true;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(preview?['error'] ?? 'Failed to decrypt file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _decryptAndSave() async {
    if (_selectedEncryptedFile == null || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file and enter password')),
      );
      return;
    }

    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;

    final authProvider = context.read<AuthProvider>();
    final backupProvider = context.read<BackupProvider>();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Decrypting file...')),
    );

    final fileName = _selectedEncryptedFile!.split('/').last;
    final outputPath = '$result/$fileName.decrypted';

    final success = await backupProvider.decryptFile(
      _selectedEncryptedFile!,
      _passwordController.text,
      outputPath,
      authProvider.token!,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'File decrypted successfully to $outputPath' : 'Decryption failed'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decrypt Files'),
      ),
      body: Consumer<BackupProvider>(
        builder: (context, backupProvider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue[700]),
                            const SizedBox(width: 12),
                            const Text(
                              'How to Decrypt Files',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildWorkflowStep(1, 'Select encrypted file from your Backup Folder'),
                        _buildWorkflowStep(2, 'Enter the password you used for encryption'),
                        _buildWorkflowStep(3, 'Click "Preview" to see file contents (optional)'),
                        _buildWorkflowStep(4, 'Click "Decrypt & Save" and choose where to save'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // File Selection Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Step 1: Select Encrypted File',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Browse to your Backup Folder and select a .enc file',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        if (_selectedEncryptedFile != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock, color: Colors.blue),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedEncryptedFile!.split('/').last,
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        _selectedEncryptedFile!,
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: const Text('No file selected'),
                          ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _selectEncryptedFile,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Browse Files'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Password Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Step 2: Enter Password',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Use the same password you used when creating the backup',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: 'Enter decryption password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Step 3 & 4: Preview & Decrypt',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: backupProvider.isLoading ? null : _previewDecryptedContent,
                                icon: const Icon(Icons.preview),
                                label: const Text('Preview'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: backupProvider.isLoading ? null : _decryptAndSave,
                                icon: const Icon(Icons.download),
                                label: const Text('Decrypt & Save'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Preview Section
                if (_showPreview && _previewData != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'File Preview',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'File: ${_previewData!['fileName']}',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      'Size: ${(_previewData!['size'] / 1024).toStringAsFixed(2)} KB',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_previewData!['isText'] == true)
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 300),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        _previewData!['content'] ?? 'No content',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.insert_drive_file, color: Colors.grey[400]),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Binary file (${_previewData!['fileExt']})',
                                            style: TextStyle(color: Colors.grey[600]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Loading Indicator
                if (backupProvider.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                // Error Message
                if (backupProvider.error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red[400]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              backupProvider.error!,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkflowStep(int step, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.blue[700],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                description,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
