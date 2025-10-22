import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/backup_provider.dart';

class SchedulerConfigScreen extends StatefulWidget {
  final dynamic config;
  final Function() onScheduleUpdated;

  const SchedulerConfigScreen({
    Key? key,
    required this.config,
    required this.onScheduleUpdated,
  }) : super(key: key);

  @override
  State<SchedulerConfigScreen> createState() => _SchedulerConfigScreenState();
}

class _SchedulerConfigScreenState extends State<SchedulerConfigScreen> {
  late String _scheduleType;
  late String _scheduleTime;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _scheduleType = widget.config['schedule_type'] ?? 'manual';
    _scheduleTime = widget.config['schedule_time'] ?? '09:00';
    _isActive = widget.config['is_active'] == 1 || widget.config['is_active'] == true;
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(_scheduleTime.split(':')[0]),
        minute: int.parse(_scheduleTime.split(':')[1]),
      ),
    );

    if (picked != null) {
      setState(() {
        _scheduleTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Scheduler'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backup Schedule',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure automatic backups to run at specified intervals. The scheduler will detect file changes and create incremental backups.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Enable Scheduler',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Switch(
                          value: _isActive,
                          onChanged: (value) {
                            setState(() => _isActive = value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _scheduleType,
                      decoration: InputDecoration(
                        labelText: 'Schedule Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'manual', child: Text('Manual')),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Schedule Time',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _selectTime,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_scheduleTime),
                                  const Icon(Icons.access_time),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info, color: Colors.blue, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _scheduleType == 'hourly'
                                        ? 'Backup will run every hour'
                                        : _scheduleType == 'daily'
                                            ? 'Backup will run daily at $_scheduleTime'
                                            : 'Backup will run weekly on Sunday at $_scheduleTime',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'How It Works',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoTile(
              'Change Detection',
              'The scheduler monitors your selected files and folders for changes using SHA-256 hashing.',
            ),
            _buildInfoTile(
              'Incremental Backups',
              'Only modified files are backed up, saving storage space and time.',
            ),
            _buildInfoTile(
              'Encryption',
              'All backups are encrypted with AES-256-GCM using your password-derived key.',
            ),
            _buildInfoTile(
              'Retention Policy',
              'Old backups are automatically deleted based on your retention days setting.',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        setState(() => _isSaving = true);

                        final authProvider = context.read<AuthProvider>();
                        final backupProvider = context.read<BackupProvider>();

                        try {
                          final response = await backupProvider._apiService.put(
                            '/scheduler/update/${widget.config['id']}',
                            {
                              'scheduleType': _scheduleType,
                              'scheduleTime': _scheduleTime,
                              'isActive': _isActive,
                            },
                            token: authProvider.token,
                          );

                          setState(() => _isSaving = false);

                          if (response['success'] && mounted) {
                            widget.onScheduleUpdated();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Schedule updated successfully')),
                            );
                          }
                        } catch (e) {
                          setState(() => _isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Schedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
