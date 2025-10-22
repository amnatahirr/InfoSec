import 'package:flutter/material.dart';
import 'package:frontend/screens/decrypt_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/backup_provider.dart';
import 'backup_config_screen.dart';
import 'backup_history_screen.dart';
import 'password_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedPassword;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final backupProvider = context.read<BackupProvider>();
      backupProvider.fetchBackupConfigs(authProvider.token!);
    });
  }

  void _performBackup(BuildContext context, dynamic config) {
    if (_selectedPassword == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a password first')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Perform Backup'),
        content: const Text('Start backup for this configuration?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = context.read<AuthProvider>();
              final backupProvider = context.read<BackupProvider>();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup in progress...')),
              );

              final success = await backupProvider.performBackup(
                config['id'].toString(),
                _selectedPassword!,
                authProvider.token!,
              );

              if (mounted) {
                if (!success && backupProvider.error != null) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Backup Error'),
                      content: SingleChildScrollView(
                        child: Text(backupProvider.error ?? 'Unknown error occurred'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Backup completed successfully!\nFiles saved to: ${config['backup_folder']}' : 'Backup failed'),
                      backgroundColor: success ? Colors.green : Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }

                if (success) {
                  await backupProvider.fetchBackupConfigs(authProvider.token!);
                }
              }
            },
            child: const Text('Start Backup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup Configurations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().logout();
            },
          ),
        ],
      ),
      body: Consumer<BackupProvider>(
        builder: (context, backupProvider, _) {
          if (backupProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              if (_selectedPassword == null)
                Container(
                  color: Colors.orange[100],
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: const Text('Set a password to enable backups'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PasswordSetupScreen(
                                configId: '',
                                onPasswordSet: (password) {
                                  setState(() => _selectedPassword = password);
                                },
                              ),
                            ),
                          );
                        },
                        child: const Text('Set Password'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: backupProvider.configs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.backup,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            const Text('No backup configurations yet'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const BackupConfigScreen()),
                                );
                              },
                              child: const Text('Create Configuration'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: backupProvider.configs.length,
                        itemBuilder: (context, index) {
                          final config = backupProvider.configs[index];
                          return Card(
                            child: ListTile(
                              title: Text(config['name'] ?? 'Backup Config'),
                              subtitle: Text('Schedule: ${config['schedule_type'] ?? 'Manual'}'),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: const Text('Backup Now'),
                                    onTap: () => _performBackup(context, config),
                                  ),
                                  PopupMenuItem(
                                    child: const Text('View History'),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BackupHistoryScreen(configId: config['id'].toString()),
                                        ),
                                      );
                                    },
                                  ),
                                  PopupMenuItem(
                                    child: const Text('Edit'),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BackupConfigScreen(config: config),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'decrypt',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DecryptScreen()),
              );
            },
            backgroundColor: Colors.purple,
            child: const Icon(Icons.lock_open),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupConfigScreen()),
              );
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
