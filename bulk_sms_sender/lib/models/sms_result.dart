enum SmsStatus { pending, sending, sent, failed, skipped }

/// The outcome of sending one message to one contact within a campaign.
class SmsResult {
  SmsResult({
    required this.contactId,
    required this.name,
    required this.phoneNumber,
    required this.message,
    this.status = SmsStatus.pending,
    this.timestamp,
    this.error,
  });

  final String contactId;
  final String name;
  final String phoneNumber;
  final String message;
  SmsStatus status;
  DateTime? timestamp;
  String? error;

  SmsResult copyWith({
    SmsStatus? status,
    DateTime? timestamp,
    String? error,
  }) {
    return SmsResult(
      contactId: contactId,
      name: name,
      phoneNumber: phoneNumber,
      message: message,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() => {
        'contactId': contactId,
        'name': name,
        'phoneNumber': phoneNumber,
        'message': message,
        'status': status.name,
        'timestamp': timestamp?.toIso8601String(),
        'error': error,
      };

  factory SmsResult.fromJson(Map<String, dynamic> json) => SmsResult(
        contactId: json['contactId'] as String,
        name: json['name'] as String,
        phoneNumber: json['phoneNumber'] as String,
        message: json['message'] as String,
        status: SmsStatus.values.byName(json['status'] as String),
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String)
            : null,
        error: json['error'] as String?,
      );
}
