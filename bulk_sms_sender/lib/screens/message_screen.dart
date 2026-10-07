import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets/primary_button.dart';

/// Standard GSM-7 single-SMS limit is 160 chars (153 per part when
/// concatenated). If the message contains characters outside the GSM-7
/// alphabet, UCS-2 is used instead (70 / 67 per part). We keep this
/// simple and conservative by checking for non-ASCII characters.
class SmsPartsCalculator {
  static const _gsm7Single = 160;
  static const _gsm7Concat = 153;
  static const _ucs2Single = 70;
  static const _ucs2Concat = 67;

  static bool _isGsm7(String text) {
    // A simplified check: GSM-7 covers standard ASCII plus a handful of
    // extras; anything outside basic Latin/punctuation triggers UCS-2.
    return RegExp(r'^[\x00-\x7F£¥èéùìòÇØøÅåÆæßÉ!"#$%&' r"'" r'()*+,\-./:;<=>?_]*$')
        .hasMatch(text);
  }

  static ({int length, int parts, bool unicode}) calculate(String text) {
    final unicode = !_isGsm7(text);
    final length = text.length;
    if (length == 0) return (length: 0, parts: 0, unicode: unicode);

    final singleLimit = unicode ? _ucs2Single : _gsm7Single;
    if (length <= singleLimit) {
      return (length: length, parts: 1, unicode: unicode);
    }
    final concatLimit = unicode ? _ucs2Concat : _gsm7Concat;
    final parts = (length / concatLimit).ceil();
    return (length: length, parts: parts, unicode: unicode);
  }
}

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<AppState>().message);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calc = SmsPartsCalculator.calculate(_controller.text);
    final singleLimit = calc.unicode ? 70 : 160;

    return Scaffold(
      appBar: AppBar(title: const Text('Write SMS')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You can use {name} to personalize your SMS.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Type your message here...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Characters: ${calc.length} / $singleLimit',
                  style: TextStyle(
                    color: calc.parts > 1 ? Colors.orange : Colors.grey,
                    fontWeight: calc.parts > 1 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  'SMS parts: ${calc.parts == 0 ? 1 : calc.parts}',
                  style: TextStyle(
                    color: calc.parts > 1 ? Colors.orange : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (calc.parts > 1)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'This message exceeds a single SMS and will be sent as multiple parts.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Save Message',
              icon: Icons.check,
              onPressed: () {
                context.read<AppState>().setMessage(_controller.text);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
