import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:mail_merge/features/vip_inbox/models/contact.dart';

class ContactService {
  static const String _contactsKey = 'user_contacts';
  static final _uuid = Uuid();

  // Get all contacts
  static Future<List<Contact>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getStringList(_contactsKey) ?? [];

    return contactsJson
        .map((json) => Contact.fromJson(jsonDecode(json)))
        .toList();
  }

  // Get VIP contacts only
  static Future<List<Contact>> getVipContacts() async {
    final contacts = await getContacts();
    return contacts.where((contact) => contact.isVip).toList();
  }

  // Add a new contact
  static Future<Contact> addContact(
    String name,
    String email, {
    bool isVip = true, // Changed the default to true
  }) async {
    final contacts = await getContacts();

    // Check if contact already exists
    final existingIndex = contacts.indexWhere(
      (c) => c.email.toLowerCase() == email.toLowerCase(),
    );

    if (existingIndex >= 0) {
      // Update existing contact's VIP status
      final updatedContact = contacts[existingIndex].copyWith(isVip: isVip);
      contacts[existingIndex] = updatedContact;
      await _saveContacts(contacts);
      return updatedContact;
    }

    // Create new contact
    final newContact = Contact(
      id: _uuid.v4(),
      name: name,
      email: email,
      isVip: isVip,
    );

    contacts.add(newContact);
    await _saveContacts(contacts);

    return newContact;
  }

  // Update an existing contact
  static Future<Contact> updateContact(Contact contact) async {
    final contacts = await getContacts();

    final index = contacts.indexWhere((c) => c.id == contact.id);
    if (index < 0) {
      throw Exception('Contact not found');
    }

    contacts[index] = contact;
    await _saveContacts(contacts);

    return contact;
  }

  // Toggle VIP status
  static Future<Contact> toggleVipStatus(String contactId) async {
    final contacts = await getContacts();

    final index = contacts.indexWhere((c) => c.id == contactId);
    if (index < 0) {
      throw Exception('Contact not found');
    }

    final updatedContact = contacts[index].copyWith(
      isVip: !contacts[index].isVip,
    );
    contacts[index] = updatedContact;

    await _saveContacts(contacts);
    return updatedContact;
  }

  // Remove a contact
  static Future<bool> removeContact(String email) async {
    final contacts = await getContacts();

    final index = contacts.indexWhere(
      (c) => c.email.toLowerCase() == email.toLowerCase(),
    );

    if (index >= 0) {
      // Either remove completely or just unmark as VIP
      final contact = contacts[index];
      if (contact.isVip) {
        // Update to not be VIP instead of removing
        contacts[index] = contact.copyWith(isVip: false);
        await _saveContacts(contacts);
        return true;
      }
    }

    return false;
  }

  // Check if an email belongs to a VIP contact
  static Future<bool> isVipEmail(String email) async {
    final vipContacts = await getVipContacts();
    return vipContacts.any((c) => c.email.toLowerCase() == email.toLowerCase());
  }

  // Save contacts to SharedPreferences
  static Future<void> _saveContacts(List<Contact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson =
        contacts.map((contact) => jsonEncode(contact.toJson())).toList();

    await prefs.setStringList(_contactsKey, contactsJson);
  }

  // Delete a contact completely
  static Future<bool> deleteContact(String contactId) async {
    try {
      final contacts = await getContacts();

      final index = contacts.indexWhere((c) => c.id == contactId);
      if (index < 0) {
        return false; // Contact not found
      }

      // Actually remove the contact from the list
      contacts.removeAt(index);
      await _saveContacts(contacts);

      return true;
    } catch (e) {
      print('Error deleting contact: $e');
      return false;
    }
  }
}
