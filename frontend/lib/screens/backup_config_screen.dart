import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../providers/backup_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';


class BackupConfigScreen extends StatefulWidget {
  final dynamic config;

  const BackupConfigScreen({Key? key, this.config}) : super(key: key);

  @override
  State<BackupConfigScreen> createState() => _BackupConfigScreenState();
}

class _BackupConfigScreenState extends State<BackupConfigScreen> {
  late TextEditingController _nameController;
  late TextEditingController _backupFolderController;
  late TextEditingController _scheduleTimeController;
  late TextEditingController _retentionDaysController;

  List<String> _selectedPaths = [];
  String _scheduleType = 'manual';
  int _retentionDays = 7;
  bool _isLoadingPaths = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.config?['name'] ?? '');
    _backupFolderController = TextEditingController(text: widget.config?['backup_folder'] ?? '');
    _scheduleTimeController = TextEditingController(text: widget.config?['schedule_time'] ?? '09:00');
    _retentionDaysController = TextEditingController(text: widget.config?['retention_days']?.toString() ?? '7');
    _scheduleType = widget.config?['schedule_type'] ?? 'manual';
    _retentionDays = widget.config?['retention_days'] ?? 7;

    if (widget.config != null && widget.config['source_paths'] != null) {
      try {
        _selectedPaths = List<String>.from(
          (widget.config['source_paths'] is String
              ? jsonDecode(widget.config['source_paths'])
              : widget.config['source_paths']) as List,
        );
      } catch (e) {
        _selectedPaths = [];
      }
    }
  }

Future<String?> _uploadFileToServer(String filePath) async {
  final uri = Uri.parse("http://127.0.0.1:5000/upload"); // your Node backend URL
  final request = http.MultipartRequest("POST", uri);
  request.files.add(await http.MultipartFile.fromPath("file", filePath));

  final response = await request.send();
  if (response.statusCode == 200) {
    final responseBody = await response.stream.bytesToString();
    final decoded = jsonDecode(responseBody);
    return decoded["path"]; // backend returns saved path
  } else {
    print("Upload failed: ${response.statusCode}");
    return null;
  }
}

  Future<void> _selectSourcePaths() async {
  try {
    setState(() => _isLoadingPaths = true);

    final pickerType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Type'),
        content: const Text('What would you like to add?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'folder'), child: const Text('Folder')),
          TextButton(onPressed: () => Navigator.pop(context, 'file'), child: const Text('File')),
          TextButton(onPressed: () => Navigator.pop(context, 'multiple'), child: const Text('Multiple Files')),
        ],
      ),
    );

    if (pickerType == null) return;

    // 🔹 Single Folder Selection (zip before upload)
    if (pickerType == 'folder') {
      final folderPath = await FilePicker.platform.getDirectoryPath();
      if (folderPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zipping folder...')),
        );

        // Zip the folder
        final zipFile = File("${folderPath}_backup.zip");
        final result = await Process.run('zip', ['-r', zipFile.path, folderPath]);
        if (result.exitCode == 0 && await zipFile.exists()) {
          final serverPath = await _uploadFileToServer(zipFile.path);
          if (serverPath != null && !_selectedPaths.contains(serverPath)) {
            setState(() => _selectedPaths.add(serverPath));
          }
        }
      }
    }

    // 🔹 Single File Selection
    else if (pickerType == 'file') {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null) {
          final serverPath = await _uploadFileToServer(filePath);
          if (serverPath != null && !_selectedPaths.contains(serverPath)) {
            setState(() => _selectedPaths.add(serverPath));
          }
        }
      }
    }

    // 🔹 Multiple File Selection
    else if (pickerType == 'multiple') {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          if (file.path != null) {
            final serverPath = await _uploadFileToServer(file.path!);
            if (serverPath != null && !_selectedPaths.contains(serverPath)) {
              setState(() => _selectedPaths.add(serverPath));
            }
          }
        }
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting path: $e')),
      );
    }
  } finally {
    setState(() => _isLoadingPaths = false);
  }
}


  void _removePath(int index) {
    setState(() {
      _selectedPaths.removeAt(index);
    });
  }

  String _getDisplayName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isNotEmpty ? parts.last : path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.config == null ? 'Create Backup Config' : 'Edit Backup Config'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.green[700]),
                        const SizedBox(width: 12),
                        const Text(
                          'How Backup Works',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildWorkflowStep(1, 'Give your backup a name'),
                    _buildWorkflowStep(2, 'Select files/folders to encrypt'),
                    _buildWorkflowStep(3, 'Choose a Backup Folder (where encrypted files are saved)'),
                    _buildWorkflowStep(4, 'Set schedule and save'),
                    _buildWorkflowStep(5, 'Encrypted files automatically saved to your Backup Folder'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Step 1: Configuration Name',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Give this backup a descriptive name (e.g., "My Documents Backup")',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Configuration Name',
                        hintText: 'e.g., My Documents Backup',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Step 2: Select Files to Encrypt',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose which files or folders you want to backup and encrypt',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoadingPaths ? null : _selectSourcePaths,
                      icon: _isLoadingPaths 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.folder_open),
                      label: Text(_isLoadingPaths ? 'Loading...' : 'Add Path'),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedPaths.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade50,
                        ),
                        child: const Text(
                          'No paths selected. Click "Add Path" to select files or folders.',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _selectedPaths.length,
                          separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                          itemBuilder: (context, index) {
                            final path = _selectedPaths[index];
                            final displayName = _getDisplayName(path);
                            return ListTile(
                              leading: Icon(
                                path.endsWith('.') || !path.contains('.') ? Icons.folder : Icons.insert_drive_file,
                                color: Colors.blue,
                              ),
                              title: Text(displayName, overflow: TextOverflow.ellipsis),
                              subtitle: Text(path, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => _removePath(index),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Step 3: Choose Backup Folder',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This is where your encrypted backup files will be saved (e.g., D:\\Backups or /home/user/backups)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _backupFolderController,
                      decoration: InputDecoration(
                        labelText: 'Backup Folder Path',
                        hintText: 'e.g., D:\\Backups or /home/user/backups',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.folder),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.amber[700], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tip: Create a dedicated folder like "MyBackups" to keep encrypted files organized',
                              style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Step 4: Set Schedule',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose when backups should run automatically',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _scheduleType,
                      decoration: InputDecoration(
                        labelText: 'Schedule Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'manual', child: Text('Manual (Run when I click)')),
                        DropdownMenuItem(value: 'hourly', child: Text('Hourly')),
                        DropdownMenuItem(value: 'daily', child: Text('Daily')),
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      ],
                      onChanged: (value) {
                        setState(() => _scheduleType = value ?? 'manual');
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_scheduleType != 'manual')
                      TextField(
                        controller: _scheduleTimeController,
                        decoration: InputDecoration(
                          labelText: 'Schedule Time (HH:MM)',
                          hintText: '09:00',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _retentionDaysController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Retention Days',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'How many days to keep backups',
              ),
              onChanged: (value) {
                _retentionDays = int.tryParse(value) ?? 7;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (_nameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a configuration name')),
                    );
                    return;
                  }

                  if (_selectedPaths.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select at least one source path')),
                    );
                    return;
                  }

                  if (_backupFolderController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a backup folder path')),
                    );
                    return;
                  }

                  final authProvider = context.read<AuthProvider>();
                  final backupProvider = context.read<BackupProvider>();

                  final success = await backupProvider.createBackupConfig(
                    name: _nameController.text,
                    sourcePaths: _selectedPaths,
                    backupFolder: _backupFolderController.text,
                    scheduleType: _scheduleType,
                    scheduleTime: _scheduleTimeController.text,
                    retentionDays: _retentionDays,
                    token: authProvider.token!,
                  );

                  if (success && mounted) {
                    Navigator.pop(context);
                    await backupProvider.fetchBackupConfigs(authProvider.token!);
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(backupProvider.error ?? 'Failed to save configuration')),
                    );
                  }
                },
                child: const Text('Save Configuration'),
              ),
            ),
          ],
        ),
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
              color: Colors.green[700],
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

  @override
  void dispose() {
    _nameController.dispose();
    _backupFolderController.dispose();
    _scheduleTimeController.dispose();
    _retentionDaysController.dispose();
    super.dispose();
  }
}
