import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'tts_settings_screen.dart';
import '../../services/export_import_service.dart';
import '../../repositories/settings_repository.dart';

import '../services/pro_service.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ExportImportService _exportImportService = ExportImportService();
  final SettingsRepository _settingsRepository = SettingsRepository();
  final ProService _proService = ProService();
  bool _isLoading = false;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _proService.addListener(_refresh);
    _loadSettings();
  }

  @override
  void dispose() {
    _proService.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _loadSettings() {
    setState(() {
      _themeMode = _settingsRepository.getThemeMode();
    });
  }

  Future<void> _updateTheme(ThemeMode mode) async {
    await _settingsRepository.setThemeMode(mode);
    setState(() => _themeMode = mode);
    // Force rebuild of app (handled by ValueListenable in main.dart)
  }

  Future<void> _exportTasks() async {

    
    // Show format selection dialog
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Tasks'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.fileJson, color: Colors.orange),
              title: const Text('JSON (Backup)'),
              subtitle: const Text('Best for restoring later'),
              onTap: () {
                Navigator.pop(context);
                _performExport('json');
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.fileSpreadsheet, color: Colors.green),
              title: const Text('CSV (Excel)'),
              subtitle: const Text('Readable in spreadsheet apps'),
              onTap: () {
                Navigator.pop(context);
                _performExport('csv');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _performExport(String format) async {
    setState(() => _isLoading = true);
    try {
      await _exportImportService.shareExport(format: format);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importTasks() async {
    try {
      // 1. Pick file
      final jsonString = await _exportImportService.pickImportFile();
      if (jsonString == null) return; // Cancelled

      if (!mounted) return;

      // 2. Ask import mode (Merge or Replace)
      final bool? shouldMerge = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Tasks'),
          content: const Text(
            'How would you like to import tasks?\n\n'
            'Merge: Adds new tasks, updates existing ones if newer.\n'
            'Replace: DELETES all current tasks and replaces them with the file.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Replace All'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Merge'),
            ),
          ],
        ),
      );

      if (shouldMerge == null) return; // Cancelled

      setState(() => _isLoading = true);

      // 3. Perform import
      final result = await _exportImportService.importFromJson(
        jsonString,
        merge: shouldMerge,
      );

      if (!mounted) return;

      // 4. Show result
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported: ${result.imported}, Skipped: ${result.skipped}, Errors: ${result.errors}'
          ),
          backgroundColor: result.errors > 0 ? Colors.orange : Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              // Subscription Section
              _buildSectionHeader('Subscription'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Card(
                  color: _proService.isPro 
                      ? Colors.amber.shade100 
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  elevation: 0,
                  child: ListTile(
                    leading: Icon(
                      _proService.isPro ? LucideIcons.crown : LucideIcons.user,
                      color: _proService.isPro ? Colors.amber.shade800 : null,
                    ),
                    title: Text(
                      _proService.isPro ? "Pro Plan Active" : "Free Plan",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _proService.isPro ? "Thank you for your support!" : "Upgrade to unlock all features",
                    ),
                    trailing: _proService.isPro
                      ? null
                      : FilledButton.tonal(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
                          },
                          child: const Text("Upgrade"),
                        ),
                  ),
                ),
              ),

              _buildSectionHeader('Appearance'),
              ListTile(
                leading: const Icon(LucideIcons.palette),
                title: const Text('Theme'),
                subtitle: Text(_getThemeLabel(_themeMode)),
                trailing: PopupMenuButton<ThemeMode>(
                  initialValue: _themeMode,
                  onSelected: _updateTheme,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: ThemeMode.system,
                      child: Text('System Default'),
                    ),
                    const PopupMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light Mode'),
                    ),
                    const PopupMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark Mode'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              _buildSectionHeader('Voice & Sound'),
              ListTile(
                leading: const Icon(LucideIcons.volume2),
                title: const Text('Text-to-Speech Settings'),
                subtitle: const Text('Voice, speed, pitch, volume'),
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TtsSettingsScreen()),
                  );
                },
              ),

              const Divider(),
              _buildSectionHeader('Data Management'),
              
              ListTile(
                leading: const Icon(LucideIcons.download),
                title: const Text('Export Tasks'),
                subtitle: const Text('Backup to file or share'),
                onTap: _exportTasks,
              ),
              
              ListTile(
                leading: const Icon(LucideIcons.upload),
                title: const Text('Import Tasks'),
                subtitle: const Text('Restore from backup'),
                onTap: _importTasks,
              ),

              const Divider(),
              _buildSectionHeader('About'),
              ListTile(
                leading: const Icon(LucideIcons.info),
                title: const Text('DeepMind Antigravity'),
                subtitle: const Text('Version 1.0.0'),
              ),
            ],
          ),
    );
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
