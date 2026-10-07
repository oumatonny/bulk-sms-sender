import 'sms_result.dart';

enum CampaignState { notStarted, running, paused, stopped, completed }

/// A bulk-send campaign: a message sent to a list of contacts, with
/// per-recipient results and enough state to resume after interruption.
class SmsCampaign {
  SmsCampaign({
    required this.id,
    required this.createdAt,
    required this.message,
    required this.results,
    this.state = CampaignState.notStarted,
    this.delaySeconds = 3,
    this.currentIndex = 0,
    this.startedAt,
    this.finishedAt,
  });

  final String id;
  final DateTime createdAt;
  final String message;
  final List<SmsResult> results;
  CampaignState state;
  int delaySeconds;

  /// Index into [results] of the next contact to process.
  int currentIndex;

  DateTime? startedAt;
  DateTime? finishedAt;

  int get total => results.length;
  int get sent => results.where((r) => r.status == SmsStatus.sent).length;
  int get failed => results.where((r) => r.status == SmsStatus.failed).length;
  int get skipped => results.where((r) => r.status == SmsStatus.skipped).length;
  int get remaining => results
      .where((r) => r.status == SmsStatus.pending || r.status == SmsStatus.sending)
      .length;

  Duration? get duration {
    if (startedAt == null) return null;
    final end = finishedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'message': message,
        'results': results.map((r) => r.toJson()).toList(),
        'state': state.name,
        'delaySeconds': delaySeconds,
        'currentIndex': currentIndex,
        'startedAt': startedAt?.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
      };

  factory SmsCampaign.fromJson(Map<String, dynamic> json) => SmsCampaign(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        message: json['message'] as String,
        results: (json['results'] as List)
            .map((r) => SmsResult.fromJson(r as Map<String, dynamic>))
            .toList(),
        state: CampaignState.values.byName(json['state'] as String),
        delaySeconds: json['delaySeconds'] as int? ?? 3,
        currentIndex: json['currentIndex'] as int? ?? 0,
        startedAt: json['startedAt'] != null
            ? DateTime.tryParse(json['startedAt'] as String)
            : null,
        finishedAt: json['finishedAt'] != null
            ? DateTime.tryParse(json['finishedAt'] as String)
            : null,
      );
}
