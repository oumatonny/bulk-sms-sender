import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/sms_campaign.dart';
import '../widgets/status_badge.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final history = state.history;

    return Scaffold(
      appBar: AppBar(title: const Text('Campaign History')),
      body: history.isEmpty
          ? const Center(
              child: Text('No campaigns yet.', style: TextStyle(color: Colors.grey)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final campaign = history[index];
                return _CampaignCard(campaign: campaign);
              },
            ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign});
  final SmsCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM yyyy, HH:mm').format(campaign.createdAt);
    return Card(
      child: ExpansionTile(
        title: Text('Campaign - $dateStr'),
        subtitle: Text(
          'Total: ${campaign.total}   Sent: ${campaign.sent}   '
          'Failed: ${campaign.failed}   Skipped: ${campaign.skipped}',
        ),
        children: campaign.results
            .map((r) => ListTile(
                  dense: true,
                  title: Text(r.phoneNumber),
                  subtitle: Text(r.name),
                  trailing: StatusBadge.sms(status: r.status),
                ))
            .toList(),
      ),
    );
  }
}
