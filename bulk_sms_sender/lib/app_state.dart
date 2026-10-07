import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'models/contact.dart';
import 'models/sms_campaign.dart';
import 'models/sms_result.dart';
import 'services/storage_service.dart';

const _uuid = Uuid();

/// Central, in-memory application state. Screens read/mutate this through
/// [Provider] and it is the single place that talks to [StorageService]
/// for contacts/settings/campaign persistence.
class AppState extends ChangeNotifier {
  List<Contact> contacts = [];
  String message = '';
  bool personalizationEnabled = true;

  Map<String, dynamic> settings = {
    'delaySeconds': 3,
    'personalizationEnabled': true,
    'confirmBeforeSend': true,
    'deliveryReports': true,
    'darkMode': 'system',
  };

  SmsCampaign? activeCampaign;
  List<SmsCampaign> history = [];

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    contacts = await StorageService.loadContacts();
    settings = await StorageService.loadSettings();
    personalizationEnabled = settings['personalizationEnabled'] as bool? ?? true;
    activeCampaign = await StorageService.loadActiveCampaign();
    history = await StorageService.loadHistory();
    _loaded = true;
    notifyListeners();
  }

  // ---------------- Contacts ----------------

  int get totalCount => contacts.length;
  int get validCount =>
      contacts.where((c) => c.status == ContactStatus.valid).length;
  int get duplicateCount =>
      contacts.where((c) => c.status == ContactStatus.duplicate).length;
  int get invalidCount =>
      contacts.where((c) => c.status == ContactStatus.invalid).length;

  List<Contact> get selectedValidContacts =>
      contacts.where((c) => c.isValid && c.selected).toList();

  Future<void> setContacts(List<Contact> imported) async {
    contacts = imported;
    await StorageService.saveContacts(contacts);
    notifyListeners();
  }

  Future<void> removeContact(Contact contact) async {
    contacts.removeWhere((c) => c.id == contact.id);
    await StorageService.saveContacts(contacts);
    notifyListeners();
  }

  Future<void> removeInvalidContacts() async {
    contacts.removeWhere((c) => c.status == ContactStatus.invalid);
    await StorageService.saveContacts(contacts);
    notifyListeners();
  }

  // ---------------- Message ----------------

  void setMessage(String value) {
    message = value;
    notifyListeners();
  }

  String personalizedMessage(String name) {
    if (!personalizationEnabled) {
      return message.replaceAll('{name}', '');
    }
    return message.replaceAll('{name}', name.isEmpty ? '' : name);
  }

  // ---------------- Settings ----------------

  Future<void> updateSettings(Map<String, dynamic> newSettings) async {
    settings = {...settings, ...newSettings};
    personalizationEnabled = settings['personalizationEnabled'] as bool? ?? true;
    await StorageService.saveSettings(settings);
    notifyListeners();
  }

  // ---------------- Campaigns ----------------

  SmsCampaign buildCampaign() {
    final targets = selectedValidContacts;
    final results = targets
        .map((c) => SmsResult(
              contactId: c.id,
              name: c.name,
              phoneNumber: c.normalizedNumber,
              message: personalizedMessage(c.name),
            ))
        .toList();
    return SmsCampaign(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      message: message,
      results: results,
      delaySeconds: settings['delaySeconds'] as int? ?? 3,
    );
  }

  Future<void> setActiveCampaign(SmsCampaign? campaign) async {
    activeCampaign = campaign;
    await StorageService.saveActiveCampaign(campaign);
    notifyListeners();
  }

  Future<void> discardActiveCampaign() async {
    activeCampaign = null;
    await StorageService.saveActiveCampaign(null);
    notifyListeners();
  }

  Future<void> refreshHistory() async {
    history = await StorageService.loadHistory();
    notifyListeners();
  }

  void notify() => notifyListeners();
}
