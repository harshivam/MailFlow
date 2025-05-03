import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mail_merge/features/filters/models/custom_filter.dart';

class FilterRepository {
  static const String _storageKey = 'custom_email_filters';
  static const _storage = FlutterSecureStorage();
  
  // Get all saved filters
  Future<List<CustomFilter>> getAllFilters() async {
    try {
      final filtersJson = await _storage.read(key: _storageKey);
      if (filtersJson == null) return [];
      
      final List<dynamic> filtersList = jsonDecode(filtersJson);
      return filtersList.map((filter) => CustomFilter.fromJson(filter)).toList();
    } catch (e) {
      print('Error loading custom filters: $e');
      return [];
    }
  }
  
  // Save a new filter
  Future<void> saveFilter(CustomFilter filter) async {
    final filters = await getAllFilters();
    
    // Remove existing filter with same ID if exists
    filters.removeWhere((f) => f.id == filter.id);
    
    // Add the new filter
    filters.add(filter);
    
    await _saveFilters(filters);
  }
  
  // Delete a filter
  Future<void> deleteFilter(String filterId) async {
    final filters = await getAllFilters();
    filters.removeWhere((filter) => filter.id == filterId);
    await _saveFilters(filters);
  }
  
  // Save all filters
  Future<void> _saveFilters(List<CustomFilter> filters) async {
    try {
      final filtersJson = jsonEncode(
        filters.map((filter) => filter.toJson()).toList()
      );
      await _storage.write(key: _storageKey, value: filtersJson);
    } catch (e) {
      print('Error saving custom filters: $e');
    }
  }
}