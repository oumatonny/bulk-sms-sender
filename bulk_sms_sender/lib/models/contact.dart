/// Validation state of an imported phone number.
enum ContactStatus { valid, invalid, duplicate }

/// A single contact imported from the Excel/CSV file.
class Contact {
  Contact({
    required this.id,
    required this.name,
    required this.rawNumber,
    required this.normalizedNumber,
    required this.status,
    this.selected = true,
  });

  final String id;
  final String name;

  /// The phone number exactly as it appeared in the source file.
  final String rawNumber;

  /// The number normalized to +2547XXXXXXXX (or empty if it could not be
  /// normalized).
  final String normalizedNumber;

  final ContactStatus status;

  /// Whether this contact is included in the next send. Lets the user
  /// remove individual contacts without deleting them from the import.
  bool selected;

  bool get isValid => status == ContactStatus.valid;

  Contact copyWith({
    String? name,
    String? rawNumber,
    String? normalizedNumber,
    ContactStatus? status,
    bool? selected,
  }) {
    return Contact(
      id: id,
      name: name ?? this.name,
      rawNumber: rawNumber ?? this.rawNumber,
      normalizedNumber: normalizedNumber ?? this.normalizedNumber,
      status: status ?? this.status,
      selected: selected ?? this.selected,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rawNumber': rawNumber,
        'normalizedNumber': normalizedNumber,
        'status': status.name,
        'selected': selected,
      };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: json['id'] as String,
        name: json['name'] as String,
        rawNumber: json['rawNumber'] as String,
        normalizedNumber: json['normalizedNumber'] as String,
        status: ContactStatus.values.byName(json['status'] as String),
        selected: json['selected'] as bool? ?? true,
      );
}
