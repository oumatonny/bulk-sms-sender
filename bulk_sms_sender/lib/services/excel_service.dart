import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xls;
import 'package:uuid/uuid.dart';

import '../models/contact.dart';
import 'phone_service.dart';

/// Result of parsing an imported file, before dedup/validation stats are
/// summarized on screen.
class ImportResult {
  ImportResult(this.contacts);
  final List<Contact> contacts;

  int get total => contacts.length;
  int get valid => contacts.where((c) => c.status == ContactStatus.valid).length;
  int get duplicates =>
      contacts.where((c) => c.status == ContactStatus.duplicate).length;
  int get invalid =>
      contacts.where((c) => c.status == ContactStatus.invalid).length;
}

/// Reads contacts out of a user-selected .xlsx or .csv file. Never writes
/// back to the original file.
class ExcelService {
  static const _uuid = Uuid();

  static const _phoneHeaderHints = [
    'phone',
    'number',
    'mobile',
    'cell',
    'contact',
    'msisdn',
  ];

  static const _nameHeaderHints = ['name', 'full name', 'names', 'contact name'];

  /// Parses [path] (must end in .xlsx, .xls or .csv) into a list of raw
  /// rows: each row is a list of cell strings.
  static Future<List<List<String>>> _readRows(String path) async {
    final lower = path.toLowerCase();
    if (lower.endsWith('.csv')) {
      final content = await File(path).readAsString();
      final rows = const CsvToListConverter(shouldParseNumbers: false)
          .convert(content, eol: '\n');
      return rows
          .map((row) => row.map((cell) => cell.toString()).toList())
          .toList();
    } else {
      final bytes = await File(path).readAsBytes();
      final workbook = xls.Excel.decodeBytes(bytes);
      if (workbook.tables.isEmpty) return [];
      final sheet = workbook.tables[workbook.tables.keys.first]!;
      final rows = <List<String>>[];
      for (final row in sheet.rows) {
        rows.add(row
            .map((cell) => cell?.value?.toString().trim() ?? '')
            .toList());
      }
      return rows;
    }
  }

  /// Picks the header row (if any) and figures out which column holds
  /// phone numbers and which (if any) holds names.
  static ({int nameCol, int phoneCol, int startRow}) _detectColumns(
      List<List<String>> rows) {
    if (rows.isEmpty) return (nameCol: -1, phoneCol: -1, startRow: 0);

    final header = rows.first.map((h) => h.toLowerCase().trim()).toList();
    int phoneCol = -1;
    int nameCol = -1;

    for (var i = 0; i < header.length; i++) {
      if (_phoneHeaderHints.any((hint) => header[i].contains(hint))) {
        phoneCol = i;
      }
      if (_nameHeaderHints.any((hint) => header[i].contains(hint))) {
        nameCol = i;
      }
    }

    final headerLooksLikeData = phoneCol == -1 &&
        nameCol == -1 &&
        rows.first.any((cell) => PhoneService.isValid(cell));

    if (phoneCol == -1 && nameCol == -1 && !headerLooksLikeData) {
      // No recognizable header names, but the first row isn't data either
      // (e.g. a single unlabeled column). Assume column 0 is the phone
      // column and there is a header row to skip only if row 0 has no
      // valid phone number itself.
      phoneCol = 0;
      return (
        nameCol: -1,
        phoneCol: phoneCol,
        startRow: PhoneService.isValid(rows.first.isNotEmpty ? rows.first[0] : '')
            ? 0
            : 1,
      );
    }

    if (headerLooksLikeData) {
      // First row is actually data, not a header.
      return (nameCol: -1, phoneCol: 0, startRow: 0);
    }

    // We found named headers -> row 0 was a real header, data starts at 1.
    if (phoneCol == -1) {
      // Header row detected (has a name column) but no phone column
      // found by name; fall back to "the column that isn't the name
      // column and contains phone-like values in row 1".
      for (var i = 0; i < header.length; i++) {
        if (i == nameCol) continue;
        if (rows.length > 1 && i < rows[1].length && PhoneService.isValid(rows[1][i])) {
          phoneCol = i;
          break;
        }
      }
      phoneCol = phoneCol == -1 ? (nameCol == 0 ? 1 : 0) : phoneCol;
    }

    return (nameCol: nameCol, phoneCol: phoneCol, startRow: 1);
  }

  /// Imports [path] and returns validated, deduplicated contacts.
  static Future<ImportResult> importFile(String path) async {
    final rows = await _readRows(path);
    final nonEmptyRows =
        rows.where((r) => r.any((cell) => cell.trim().isNotEmpty)).toList();

    if (nonEmptyRows.isEmpty) {
      return ImportResult([]);
    }

    final cols = _detectColumns(nonEmptyRows);
    final phoneCol = cols.phoneCol < 0 ? 0 : cols.phoneCol;
    final nameCol = cols.nameCol;

    final seen = <String>{};
    final contacts = <Contact>[];

    for (var i = cols.startRow; i < nonEmptyRows.length; i++) {
      final row = nonEmptyRows[i];
      if (row.every((cell) => cell.trim().isEmpty)) continue;

      final rawPhone = phoneCol < row.length ? row[phoneCol].trim() : '';
      if (rawPhone.isEmpty) continue;

      final name = (nameCol >= 0 && nameCol < row.length)
          ? row[nameCol].trim()
          : '';

      final normalized = PhoneService.normalizeKenyan(rawPhone);

      ContactStatus status;

      if (normalized == null) {
        status = ContactStatus.invalid;
      } else if (seen.contains(normalized)) {
        status = ContactStatus.duplicate;
      } else {
        status = ContactStatus.valid;
        seen.add(normalized);
      }

      contacts.add(Contact(
        id: _uuid.v4(),
        name: name.isEmpty ? 'Contact ${i}' : name,
        rawNumber: rawPhone,
        normalizedNumber: normalized ?? '',
        status: status,
      ));
    }

    return ImportResult(contacts);
  }
}
