import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/backup_provider.dart';

class BackupHistoryScreen extends StatefulWidget {
  final String configId;

  const BackupHistoryScreen({Key? key, required this.configId}) : super(key: key);

  @override
  State<BackupHistoryScreen> createState() => _BackupHistoryScreenState();
}

class _BackupHistoryScreenState extends State<BackupHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final backupProvider = context.read<BackupProvider>();
      backupProvider.fetchBackupHistory(widget.configId, authProvider.token!);
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  void _showRestoreDialog(BuildContext context, dynamic backup) {
    final passwordController = TextEditingController();
    final restorePathController = TextEditingController();
    bool _isRestoring = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Restore Backup'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backup Details:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Files: ${backup['file_count']}'),
                Text('Size: ${_formatBytes(backup['total_size'] ?? 0)}'),
                Text('Status: ${backup['status'] ?? 'success'}'),
                const SizedBox(height: 16),
                const Text(
                  'Enter your encryption password:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  enabled: !_isRestoring,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Restore destination path:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: restorePathController,
                  enabled: !_isRestoring,
                  decoration: InputDecoration(
                    labelText: 'Restore Path',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: '/path/to/restore',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isRestoring ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isRestoring
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter password')),
                        );
                        return;
                      }

                      if (restorePathController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter restore path')),
                        );
                        return;
                      }

                      setState(() => _isRestoring = true);

                      final authProvider = context.read<AuthProvider>();
                      final backupProvider = context.read<BackupProvider>();

                      final success = await backupProvider.restoreBackup(
                        backup['id'].toString(),
                        passwordController.text,
                        restorePathController.text,
                        authProvider.token!,
                      );

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Restore completed successfully' : 'Restore failed'),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );
                      }
                    },
              child: _isRestoring
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Restore'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup History'),
      ),
      body: Consumer<BackupProvider>(
        builder: (context, backupProvider, _) {
          if (backupProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (backupProvider.backupHistory.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text('No backups yet'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: backupProvider.backupHistory.length,
            itemBuilder: (context, index) {
              final backup = backupProvider.backupHistory[index];
              final date = DateTime.parse(backup['created_at']);
              final formattedDate = DateFormat('MMM dd, yyyy HH:mm').format(date);
              final status = backup['status'] ?? 'success';
              final statusColor = status == 'success' ? Colors.green : Colors.orange;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Backup - $formattedDate',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Files: ${backup['file_count']} | Size: ${_formatBytes(backup['total_size'] ?? 0)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showRestoreDialog(context, backup),
                          child: const Text('Restore'),
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
