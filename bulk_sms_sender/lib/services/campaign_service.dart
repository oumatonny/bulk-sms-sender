import 'dart:async';

import '../models/sms_campaign.dart';
import '../models/sms_result.dart';
import 'sms_service.dart';
import 'storage_service.dart';

/// Drives a [SmsCampaign] one recipient at a time, with a delay between
/// sends, and persists progress after every single message so the
/// campaign survives the app closing, the screen locking, or a signal
/// drop. Never fires messages concurrently.
class CampaignService {
  CampaignService(this.campaign, {this.subscriptionId = -1});

  final SmsCampaign campaign;
  final int subscriptionId;

  final _controller = StreamController<SmsCampaign>.broadcast();
  Stream<SmsCampaign> get updates => _controller.stream;

  bool _pauseRequested = false;
  bool _stopRequested = false;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  void pause() => _pauseRequested = true;

  void resume() {
    _pauseRequested = false;
    if (!_isRunning) {
      run();
    }
  }

  void stop() => _stopRequested = true;

  void _emit() => _controller.add(campaign);

  /// Starts (or resumes) processing the queue from campaign.currentIndex.
  Future<void> run() async {
    if (_isRunning) return;
    _isRunning = true;
    _pauseRequested = false;
    _stopRequested = false;
    campaign.state = CampaignState.running;
    campaign.startedAt ??= DateTime.now();
    _emit();

    while (campaign.currentIndex < campaign.results.length) {
      if (_stopRequested) {
        campaign.state = CampaignState.stopped;
        await _persist();
        _emit();
        break;
      }
      if (_pauseRequested) {
        campaign.state = CampaignState.paused;
        await _persist();
        _emit();
        break;
      }

      final result = campaign.results[campaign.currentIndex];

      if (result.status == SmsStatus.sent) {
        // Already sent in a previous run - never resend.
        campaign.currentIndex++;
        continue;
      }

      result.status = SmsStatus.sending;
      _emit();

      final outcome = await SmsService.sendSms(
        phoneNumber: result.phoneNumber,
        message: result.message,
        subscriptionId: subscriptionId,
      );

      if (outcome.success) {
        result.status = SmsStatus.sent;
        result.error = null;
      } else {
        result.status = SmsStatus.failed;
        result.error = outcome.error ?? 'Unknown error';
      }
      result.timestamp = DateTime.now();

      campaign.currentIndex++;
      await _persist();
      _emit();

      final isLast = campaign.currentIndex >= campaign.results.length;
      if (!isLast) {
        await Future.delayed(Duration(seconds: campaign.delaySeconds));
      }
    }

    if (campaign.currentIndex >= campaign.results.length &&
        !_stopRequested &&
        !_pauseRequested) {
      campaign.state = CampaignState.completed;
      campaign.finishedAt = DateTime.now();
      await StorageService.saveActiveCampaign(null);
      await StorageService.archiveCampaign(campaign);
      _emit();
    }

    _isRunning = false;
  }

  /// Builds a brand new campaign containing only the previously failed
  /// recipients from [source], to be run independently.
  static SmsCampaign buildRetryCampaign(SmsCampaign source, String newId) {
    final failedResults = source.results
        .where((r) => r.status == SmsStatus.failed)
        .map((r) => SmsResult(
              contactId: r.contactId,
              name: r.name,
              phoneNumber: r.phoneNumber,
              message: r.message,
            ))
        .toList();
    return SmsCampaign(
      id: newId,
      createdAt: DateTime.now(),
      message: source.message,
      results: failedResults,
      delaySeconds: source.delaySeconds,
    );
  }

  Future<void> _persist() => StorageService.saveActiveCampaign(campaign);

  void dispose() {
    _controller.close();
  }
}
