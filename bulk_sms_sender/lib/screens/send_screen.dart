import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/phone_service.dart';
import '../services/sms_service.dart';
import '../widgets/primary_button.dart';
import 'progress_screen.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _testNumberController = TextEditingController();
  bool _sendingTest = false;
  bool _checkingPermission = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _testNumberController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final granted = await SmsService.hasSmsPermission();
    if (!mounted) return;
    setState(() {
      _hasPermission = granted;
      _checkingPermission = false;
    });
  }

  Future<void> _requestPermission() async {
    final granted = await SmsService.requestSmsPermission();
    if (!mounted) return;
    setState(() => _hasPermission = granted);
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS permission is required to send messages through your SIM.'),
        ),
      );
    }
  }

  Future<void> _sendTest() async {
    final raw = _testNumberController.text.trim();
    final normalized = PhoneService.normalizeKenyan(raw);
    if (normalized == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid Kenyan phone number.')),
      );
      return;
    }
    if (!_hasPermission) {
      await _requestPermission();
      if (!_hasPermission) return;
    }

    final hasSim = await SmsService.hasSimCard();
    if (!hasSim) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No SIM card was detected. Please insert a SIM card and try again.'),
        ),
      );
      return;
    }

    setState(() => _sendingTest = true);
    final state = context.read<AppState>();
    final outcome = await SmsService.sendSms(
      phoneNumber: normalized,
      message: state.personalizedMessage('Test'),
    );
    if (!mounted) return;
    setState(() => _sendingTest = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome.success
              ? 'Test SMS submitted successfully.'
              : 'Unable to send test SMS. ${outcome.error ?? ''}',
        ),
      ),
    );
  }

  Future<void> _confirmAndSend() async {
    final state = context.read<AppState>();
    final confirmFirst = state.settings['confirmBeforeSend'] as bool? ?? true;

    if (confirmFirst) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm bulk send'),
          content: Text(
            'You are about to send SMS to ${state.selectedValidContacts.length} contacts. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('CONTINUE'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!_hasPermission) {
      await _requestPermission();
      if (!_hasPermission) return;
    }

    final hasSim = await SmsService.hasSimCard();
    if (!hasSim) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No SIM card was detected. Please insert a SIM card and try again.'),
        ),
      );
      return;
    }

    final campaign = state.buildCampaign();
    await state.setActiveCampaign(campaign);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProgressScreen(campaign: campaign, autoResume: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final recipients = state.selectedValidContacts;
    // A representative preview using the first recipient's name, or a
    // generic placeholder if none is available.
    final samplePersonalized = recipients.isNotEmpty
        ? state.personalizedMessage(recipients.first.name)
        : state.message;

    return Scaffold(
      appBar: AppBar(title: const Text('Ready to Send')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('READY TO SEND',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Recipients: ${recipients.length}'),
                  Text('Valid numbers: ${state.validCount}'),
                  Text('Invalid numbers: ${state.invalidCount}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Message', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(samplePersonalized.isEmpty ? '(empty message)' : samplePersonalized),
          ),
          const SizedBox(height: 24),
          if (!_checkingPermission && !_hasPermission)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SMS permission is required to send messages through your SIM.',
                    ),
                    const SizedBox(height: 8),
                    PrimaryButton(label: 'Grant Permission', onPressed: _requestPermission),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('Send Test SMS', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          const Text(
            'Verify your SIM works before sending to everyone.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _testNumberController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Test Number',
              hintText: '+254712345678',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: _sendingTest ? 'Sending...' : 'Send Test',
            icon: Icons.send_outlined,
            filled: false,
            onPressed: _sendingTest ? null : _sendTest,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Cancel',
                  filled: false,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Send SMS',
                  icon: Icons.send,
                  onPressed: recipients.isEmpty ? null : _confirmAndSend,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
