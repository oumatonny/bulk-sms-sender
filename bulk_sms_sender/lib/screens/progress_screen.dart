import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/sms_campaign.dart';
import '../services/campaign_service.dart';
import '../widgets/primary_button.dart';
import '../widgets/progress_card.dart';
import '../widgets/status_badge.dart';
import 'home_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.campaign, this.autoResume = false});

  final SmsCampaign campaign;
  final bool autoResume;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late CampaignService _service;
  late SmsCampaign _campaign;

  @override
  void initState() {
    super.initState();
    _campaign = widget.campaign;
    _service = CampaignService(_campaign);
    _service.updates.listen((updated) {
      if (!mounted) return;
      setState(() => _campaign = updated);
      if (updated.state == CampaignState.completed) {
        context.read<AppState>().refreshHistory();
        context.read<AppState>().discardActiveCampaign();
      }
    });
    if (widget.autoResume && _campaign.state != CampaignState.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _service.run());
    }
  }

  @override
  void dispose() {
    // Note: we intentionally do NOT stop the service here - if the user
    // navigates away the campaign keeps running and its progress is
    // persisted after every message, so it can resume later.
    _service.dispose();
    super.dispose();
  }

  String get _currentRecipient {
    if (_campaign.currentIndex < _campaign.results.length) {
      return _campaign.results[_campaign.currentIndex].phoneNumber;
    }
    return '-';
  }

  String get _currentStatusLabel {
    switch (_campaign.state) {
      case CampaignState.running:
        return 'Sending...';
      case CampaignState.paused:
        return 'Paused';
      case CampaignState.stopped:
        return 'Stopped';
      case CampaignState.completed:
        return 'Completed';
      case CampaignState.notStarted:
        return 'Not started';
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _campaign.total;
    final processed = _campaign.currentIndex.clamp(0, total);
    final progress = total == 0 ? 0.0 : processed / total;
    final isCompleted = _campaign.state == CampaignState.completed;
    final isStopped = _campaign.state == CampaignState.stopped;

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isCompleted ? 'Campaign Complete' : 'Sending SMS'),
          automaticallyImplyLeading: !_service.isRunning,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isCompleted) ...[
                _CompletedSummary(campaign: _campaign),
              ] else ...[
                Text(
                  '$processed / $total',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
                const SizedBox(height: 20),
                ProgressCard(
                  sent: _campaign.sent,
                  failed: _campaign.failed,
                  remaining: _campaign.remaining,
                  total: total,
                ),
                const SizedBox(height: 20),
                Text('Current recipient', style: Theme.of(context).textTheme.labelLarge),
                Text(_currentRecipient, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Status: '),
                    Text(_currentStatusLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                if (isStopped)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Campaign stopped. ${_campaign.remaining} contacts remain.',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const Spacer(),
                Row(
                  children: [
                    if (_campaign.state == CampaignState.running) ...[
                      Expanded(
                        child: PrimaryButton(
                          label: 'Pause',
                          icon: Icons.pause,
                          filled: false,
                          onPressed: () => _service.pause(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Stop',
                          icon: Icons.stop,
                          color: Colors.red,
                          onPressed: () => _service.stop(),
                        ),
                      ),
                    ] else if (_campaign.state == CampaignState.paused ||
                        _campaign.state == CampaignState.notStarted) ...[
                      Expanded(
                        child: PrimaryButton(
                          label: 'Resume',
                          icon: Icons.play_arrow,
                          onPressed: () => _service.resume(),
                        ),
                      ),
                    ] else if (isStopped) ...[
                      Expanded(
                        child: PrimaryButton(
                          label: 'Resume',
                          icon: Icons.play_arrow,
                          onPressed: () => _service.resume(),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (isCompleted) ...[
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        label: 'View Results',
                        filled: false,
                        onPressed: () => _showResultsSheet(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_campaign.failed > 0)
                  PrimaryButton(
                    label: 'Retry Failed',
                    icon: Icons.replay,
                    onPressed: () async {
                      final state = context.read<AppState>();
                      final retryCampaign = CampaignService.buildRetryCampaign(
                        _campaign,
                        DateTime.now().microsecondsSinceEpoch.toString(),
                      );
                      await state.setActiveCampaign(retryCampaign);
                      if (!context.mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProgressScreen(campaign: retryCampaign, autoResume: true),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'New Campaign',
                  filled: false,
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showResultsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) => ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: _campaign.results.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final r = _campaign.results[index];
            return ListTile(
              title: Text(r.phoneNumber),
              subtitle: r.error != null ? Text(r.error!) : null,
              trailing: StatusBadge.sms(status: r.status),
            );
          },
        ),
      ),
    );
  }
}

class _CompletedSummary extends StatelessWidget {
  const _CompletedSummary({required this.campaign});
  final SmsCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final duration = campaign.duration;
    final minutes = duration?.inMinutes ?? 0;
    final seconds = (duration?.inSeconds ?? 0) % 60;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('CAMPAIGN COMPLETE',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 12),
            Text('Total: ${campaign.total}'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 4),
                Text('Sent: ${campaign.sent}'),
                const SizedBox(width: 20),
                Icon(Icons.cancel, color: Colors.red, size: 20),
                const SizedBox(width: 4),
                Text('Failed: ${campaign.failed}'),
              ],
            ),
            const SizedBox(height: 12),
            Text('Duration: $minutes minutes $seconds seconds',
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
