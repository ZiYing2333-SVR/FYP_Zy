import 'package:supabase_flutter/supabase_flutter.dart';

class CurrencyService {
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  /// Fetch all currencies from Supabase
  Future<List<Map<String, dynamic>>> fetchCurrencies() async {
    try {
      final response = await _supabaseClient
          .from('Currency')
          .select('currencyId, name, code, symbol, iconImage')
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching currencies: $e');
      rethrow;
    }
  }

  /// Get user's default currency
  Future<String?> getUserDefaultCurrency(String userId) async {
    try {
      final response = await _supabaseClient
          .from('UserCurrency')
          .select('currencyId')
          .eq('userId', userId)
          .maybeSingle();

      return response != null ? response['currencyId'] : null;
    } catch (e) {
      print('Error fetching user currency: $e');
      return null;
    }
  }

  /// Update user's default currency
  Future<void> updateUserCurrency(String userId, String currencyId) async {
    try {
      // Check if record exists
      final existing = await _supabaseClient
          .from('UserCurrency')
          .select()
          .eq('userId', userId)
          .maybeSingle();

      if (existing != null) {
        // Update existing record
        await _supabaseClient
            .from('UserCurrency')
            .update({'currencyId': currencyId})
            .eq('userId', userId);
      } else {
        // Insert new record
        await _supabaseClient.from('UserCurrency').insert({
          'userId': userId,
          'currencyId': currencyId,
        });
      }
    } catch (e) {
      print('Error updating user currency: $e');
      rethrow;
    }
  }

  /// Search currencies by name or symbol
  Future<List<Map<String, dynamic>>> searchCurrencies(String query) async {
    try {
      if (query.isEmpty) {
        return fetchCurrencies();
      }

      final response = await _supabaseClient
          .from('Currency')
          .select('currencyId, name, code, symbol, iconImage')
          .or('name.ilike.%$query%,symbol.ilike.%$query%,code.ilike.%$query%')
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error searching currencies: $e');
      rethrow;
    }
  }
}
