import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/sms_result.dart';

class StatusBadge extends StatelessWidget {
  StatusBadge.contact({super.key, required ContactStatus status})
      : _label = status == ContactStatus.valid
            ? 'Valid'
            : status == ContactStatus.duplicate
                ? 'Duplicate'
                : 'Invalid',
        _color = status == ContactStatus.valid
            ? Colors.green
            : status == ContactStatus.duplicate
                ? Colors.orange
                : Colors.red;

  StatusBadge.sms({super.key, required SmsStatus status})
      : _label = switch (status) {
          SmsStatus.pending => 'Pending',
          SmsStatus.sending => 'Sending',
          SmsStatus.sent => 'Sent',
          SmsStatus.failed => 'Failed',
          SmsStatus.skipped => 'Skipped',
        },
        _color = switch (status) {
          SmsStatus.pending => Colors.grey,
          SmsStatus.sending => Colors.blue,
          SmsStatus.sent => Colors.green,
          SmsStatus.failed => Colors.red,
          SmsStatus.skipped => Colors.orange,
        };

  final String _label;
  final Color _color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
