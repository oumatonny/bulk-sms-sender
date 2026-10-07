import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/contact.dart';
import '../models/sms_campaign.dart';

/// Everything persisted locally on the device. Nothing here ever leaves
/// the phone - there is no server and no network call in this file.
class StorageService {
  static const _kContacts = 'contacts_v1';
  static const _kActiveCampaign = 'active_campaign_v1';
  static const _kCampaignHistory = 'campaign_history_v1';
  static const _kSettings = 'settings_v1';

  // ---------------- Contacts ----------------

  static Future<void> saveContacts(List<Contact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = contacts.map((c) => c.toJson()).toList();
    await prefs.setString(_kContacts, jsonEncode(jsonList));
  }

  static Future<List<Contact>> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kContacts);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => Contact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> clearContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kContacts);
  }

  // ---------------- Active campaign (for resume-after-interruption) ------

  static Future<void> saveActiveCampaign(SmsCampaign? campaign) async {
    final prefs = await SharedPreferences.getInstance();
    if (campaign == null) {
      await prefs.remove(_kActiveCampaign);
    } else {
      await prefs.setString(_kActiveCampaign, jsonEncode(campaign.toJson()));
    }
  }

  static Future<SmsCampaign?> loadActiveCampaign() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kActiveCampaign);
    if (raw == null) return null;
    return SmsCampaign.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  // ---------------- Campaign history --------------------------------

  static Future<void> archiveCampaign(SmsCampaign campaign) async {
    final history = await loadHistory();
    history.removeWhere((c) => c.id == campaign.id);
    history.insert(0, campaign);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kCampaignHistory,
      jsonEncode(history.map((c) => c.toJson()).toList()),
    );
  }

  static Future<List<SmsCampaign>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCampaignHistory);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => SmsCampaign.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------------- Settings ----------------

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSettings, jsonEncode(settings));
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSettings);
    if (raw == null) {
      return {
        'delaySeconds': 3,
        'personalizationEnabled': true,
        'confirmBeforeSend': true,
        'deliveryReports': true,
        'darkMode': 'system', // 'on' | 'off' | 'system'
      };
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
