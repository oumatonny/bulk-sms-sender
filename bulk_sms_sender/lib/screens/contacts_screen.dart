import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets/contact_list.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          if (state.invalidCount > 0)
            TextButton(
              onPressed: () async {
                await context.read<AppState>().removeInvalidContacts();
              },
              child: const Text('Remove Invalid', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _stat('Total', state.totalCount, Colors.black87),
                _stat('Valid', state.validCount, Colors.green),
                _stat('Duplicates', state.duplicateCount, Colors.orange),
                _stat('Invalid', state.invalidCount, Colors.red),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ContactListView(
              contacts: state.contacts,
              onDelete: (c) => context.read<AppState>().removeContact(c),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
