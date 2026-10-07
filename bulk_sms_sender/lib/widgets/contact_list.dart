import 'package:flutter/material.dart';
import '../models/contact.dart';
import 'status_badge.dart';

class ContactListView extends StatelessWidget {
  const ContactListView({
    super.key,
    required this.contacts,
    required this.onDelete,
  });

  final List<Contact> contacts;
  final void Function(Contact contact) onDelete;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No contacts imported yet.\nTap "Import Contacts" on the home screen.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: contacts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = contacts[index];
        final isValid = c.status == ContactStatus.valid;
        return Dismissible(
          key: ValueKey(c.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => onDelete(c),
          child: ListTile(
            leading: Icon(
              isValid ? Icons.check_circle : Icons.cancel,
              color: isValid ? Colors.green : Colors.red,
            ),
            title: Text(c.name),
            subtitle: Text(
              c.status == ContactStatus.invalid
                  ? 'Invalid number: ${c.rawNumber}'
                  : c.normalizedNumber,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusBadge.contact(status: c.status),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onDelete(c),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
