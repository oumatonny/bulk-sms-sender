/// Handles validation and normalization of Kenyan phone numbers.
///
/// Accepted input formats:
///   0712345678      -> +254712345678
///   0722345678      -> +254722345678
///   254712345678    -> +254712345678
///   +254712345678   -> +254712345678 (unchanged)
///
/// Kenyan mobile numbers start with 7 or 1 after the country code
/// (Safaricom/Airtel/Telkom use 7XX, some newer ranges use 1XX), and are
/// 9 digits long after the leading zero / country code is stripped.
class PhoneService {
  /// Strips everything except leading '+' and digits.
  static String _clean(String input) {
    final trimmed = input.trim();
    final hasPlus = trimmed.startsWith('+');
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return hasPlus ? '+$digitsOnly' : digitsOnly;
  }

  /// Returns true if [nationalNumber] (9 digits, no country code) is a
  /// plausible Kenyan mobile subscriber number.
  static bool _isValidNationalNumber(String nationalNumber) {
    if (nationalNumber.length != 9) return false;
    // Kenyan mobile ranges start with 7 (all major networks) or 1
    // (newer Safaricom/Telkom ranges e.g. 110-115).
    return RegExp(r'^[71][0-9]{8}$').hasMatch(nationalNumber);
  }

  /// Attempts to normalize [input] to +2547XXXXXXXX / +2541XXXXXXXX form.
  /// Returns null if the number cannot be recognized as a valid Kenyan
  /// mobile number.
  static String? normalizeKenyan(String input) {
    if (input.trim().isEmpty) return null;
    final cleaned = _clean(input);

    String? national;

    if (cleaned.startsWith('+254')) {
      national = cleaned.substring(4);
    } else if (cleaned.startsWith('254')) {
      national = cleaned.substring(3);
    } else if (cleaned.startsWith('0')) {
      national = cleaned.substring(1);
    } else if (cleaned.length == 9) {
      // Bare national number with no leading 0, e.g. "712345678"
      national = cleaned;
    } else {
      return null;
    }

    if (!_isValidNationalNumber(national)) return null;
    return '+254$national';
  }

  /// True if [input] normalizes to a valid Kenyan number.
  static bool isValid(String input) => normalizeKenyan(input) != null;

  /// A short display-friendly version, e.g. "+254 712 345 678".
  static String formatForDisplay(String normalized) {
    if (!normalized.startsWith('+254') || normalized.length != 13) {
      return normalized;
    }
    final cc = normalized.substring(0, 4); // +254
    final a = normalized.substring(4, 7);
    final b = normalized.substring(7, 10);
    final c = normalized.substring(10, 13);
    return '$cc $a $b $c';
  }
}
