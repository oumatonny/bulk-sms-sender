import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/sms_campaign.dart';
import '../services/excel_service.dart';
import '../widgets/primary_button.dart';
import 'contacts_screen.dart';
import 'message_screen.dart';
import 'send_screen.dart';
import 'progress_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _importing = false;
  bool _checkedResume = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedResume) {
      _checkedResume = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOfferResume());
    }
  }

  Future<void> _maybeOfferResume() async {
    final state = context.read<AppState>();
    final campaign = state.activeCampaign;
    if (campaign == null) return;
    if (campaign.state == CampaignState.completed) return;
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Previous campaign found'),
        content: Text(
          'Sent: ${campaign.sent}\n'
          'Failed: ${campaign.failed}\n'
          'Remaining: ${campaign.remaining}',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await state.discardActiveCampaign();
            },
            child: const Text('DISCARD'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProgressScreen(campaign: campaign)),
              );
            },
            child: const Text('VIEW CAMPAIGN'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProgressScreen(campaign: campaign, autoResume: true),
                ),
              );
            },
            child: const Text('RESUME'),
          ),
        ],
      ),
    );
  }

  Future<void> _importContacts() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _importing = true);
    try {
      final imported = await ExcelService.importFile(result.files.single.path!);
      if (!mounted) return;
      if (imported.total == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No contacts found. Check the file has a phone number column.')),
        );
        return;
      }
      await context.read<AppState>().setContacts(imported.contacts);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${imported.total} contacts (${imported.valid} valid).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read file: $e')),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/bulk_messenger_logo.png',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 10),
            const Text('Bulk Messenger'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SummaryCard(
            total: state.totalCount,
            valid: state.validCount,
            duplicates: state.duplicateCount,
            invalid: state.invalidCount,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: _importing ? 'Importing...' : 'Import Contacts',
            icon: Icons.upload_file,
            onPressed: _importing ? null : _importContacts,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'View Contacts (${state.totalCount})',
            icon: Icons.people_outline,
            filled: false,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactsScreen()),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Write Message',
            icon: Icons.edit_note,
            filled: false,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessageScreen()),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Send SMS',
            icon: Icons.send,
            onPressed: state.validCount == 0 || state.message.trim().isEmpty
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SendScreen()),
                    ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Campaign History',
            icon: Icons.history,
            filled: false,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.valid,
    required this.duplicates,
    required this.invalid,
  });

  final int total;
  final int valid;
  final int duplicates;
  final int invalid;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _row('Contacts loaded', '$total'),
            _row('Valid numbers', '$valid', color: Colors.green),
            _row('Duplicates', '$duplicates', color: Colors.orange),
            _row('Invalid numbers', '$invalid', color: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
