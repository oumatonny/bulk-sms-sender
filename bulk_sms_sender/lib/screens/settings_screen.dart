import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/sms_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<Map<String, dynamic>> _sims = [];

  @override
  void initState() {
    super.initState();
    _loadSims();
  }

  Future<void> _loadSims() async {
    final sims = await SmsService.getSimSubscriptions();
    if (mounted) setState(() => _sims = sims);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Country'),
            subtitle: Text('Kenya (+254)'),
            leading: Icon(Icons.flag_outlined),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('SMS delay'),
            subtitle: Text('${settings['delaySeconds']} seconds between messages'),
            trailing: DropdownButton<int>(
              value: settings['delaySeconds'] as int? ?? 3,
              items: const [2, 3, 5, 10]
                  .map((s) => DropdownMenuItem(value: s, child: Text('${s}s')))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  context.read<AppState>().updateSettings({'delaySeconds': v});
                }
              },
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.person_outline),
            title: const Text('Personalization'),
            subtitle: const Text('Replace {name} with the recipient\'s name'),
            value: settings['personalizationEnabled'] as bool? ?? true,
            onChanged: (v) =>
                context.read<AppState>().updateSettings({'personalizationEnabled': v}),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.verified_outlined),
            title: const Text('Confirm before bulk send'),
            value: settings['confirmBeforeSend'] as bool? ?? true,
            onChanged: (v) =>
                context.read<AppState>().updateSettings({'confirmBeforeSend': v}),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.mark_email_read_outlined),
            title: const Text('Delivery reports'),
            subtitle: const Text('Show "Sent to SMS service" unless delivery is confirmed'),
            value: settings['deliveryReports'] as bool? ?? true,
            onChanged: (v) =>
                context.read<AppState>().updateSettings({'deliveryReports': v}),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark mode'),
            trailing: DropdownButton<String>(
              value: settings['darkMode'] as String? ?? 'system',
              items: const [
                DropdownMenuItem(value: 'system', child: Text('Follow system')),
                DropdownMenuItem(value: 'on', child: Text('On')),
                DropdownMenuItem(value: 'off', child: Text('Off')),
              ],
              onChanged: (v) {
                if (v != null) {
                  context.read<AppState>().updateSettings({'darkMode': v});
                }
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.sim_card_outlined),
            title: const Text('SIM'),
            subtitle: Text(
              _sims.isEmpty
                  ? 'Default SIM'
                  : _sims.map((s) => s['displayName'] ?? s['carrierName'] ?? 'SIM').join(', '),
            ),
          ),
        ],
      ),
    );
  }
}
