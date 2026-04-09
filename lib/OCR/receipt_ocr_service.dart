import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'models.dart';

class ReceiptOCRService {
  static Future<ParsedReceipt> extract(XFile image) async {
    final recognizer =
    TextRecognizer(script: TextRecognitionScript.latin);

    final inputImage = InputImage.fromFilePath(image.path);
    final visionText = await recognizer.processImage(inputImage);
    await recognizer.close();

    final items = <String>[];
    final prices = <double>[];

    for (final block in visionText.blocks) {
      for (final line in block.lines) {
        final text = line.text;

        final priceMatch = RegExp(r'\d+\.\d{2}').firstMatch(text);
        if (priceMatch == null) continue;

        final price = double.parse(priceMatch.group(0)!);
        prices.add(price);

        if (!RegExp(r'[A-Za-z]').hasMatch(text)) continue;

        var item = text.replaceAll(RegExp(r'\d+(\.\d{2})?'), '');
        item = item.replaceAll(RegExp(r'[^A-Za-z ]'), '');
        item = item.replaceAll(RegExp(r'\s+'), ' ').trim();

        if (item.length >= 3) {
          items.add(item);
        }
      }
    }

    /// ❌ THROW ERROR → trigger dialog
    if (prices.isEmpty) {
      throw Exception('No amount detected');
    }

    final amount =
    prices.reduce((a, b) => a > b ? a : b).toStringAsFixed(2);

    final date = _extractDate(visionText.text);
    Map<String, String>? categoryData =
    await _predictCategory(visionText.text);


    return ParsedReceipt(
      items: items.toSet().toList(),
      amount: amount,
      date: date,
      categoryId: categoryData?['id'],
      categoryName: categoryData?['name'] ?? 'Uncategorized',
      rawText: visionText.text,
    );
  }

  static String? _extractDate(String text) {
    final regexes = [
      RegExp(r'\d{2}/\d{2}/\d{4}'),
      RegExp(r'\d{2}-\d{2}-\d{4}'),
      RegExp(r'\d{4}-\d{2}-\d{2}'),
    ];

    for (final r in regexes) {
      final match = r.firstMatch(text);
      if (match != null) return match.group(0);
    }
    return null;
  }

  static Future<Map<String, String>?> _predictCategory(String text) async {
    final res = await Supabase.instance.client
        .from('Category')
        .select('categoryId, name, keywords');

    /// 🔥 CALL GEMINI
    final aiCategory = await callGemini(text);
    final aiLower = aiCategory.toLowerCase().trim();


    for (final cat in res) {
      final dbName = cat['name'].toString().toLowerCase();

      /// ✅ 1️⃣ DIRECT MATCH
      if (dbName == aiLower) {
        return {
          'id': cat['categoryId'],
          'name': cat['name'],
        };
      }

      /// ✅ 2️⃣ KEYWORD MATCH (IMPROVED 🔥)
      List<String> keywords = [];

      if (cat['keywords'] is List) {
        keywords = List<String>.from(cat['keywords']);
      } else if (cat['keywords'] is String) {
        keywords = cat['keywords']
            .toString()
            .split(',')
            .map((e) => e.trim().toLowerCase())
            .toList();
      }

      for (final keyword in keywords) {
        final k = keyword.toLowerCase();

        /// 🔥 CHANGE HERE
        if (aiLower.contains(k) || k.contains(aiLower)) {
          return {
            'id': cat['categoryId'],
            'name': cat['name'],
          };
        }
      }
    }

    return null;
  }

  static Future<String> callGemini(String text) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null) {
      throw Exception("❌ Gemini API key missing");
    }

    final url =
        'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$apiKey';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text":
                "Classify this receipt into ONE of these categories ONLY:\n"
                    "hotel, car insurance, car payment, car rental, cosmetic, credit card payment, entertainment, fuel, flights, food deliver, furniture, groceries, haircut, health insurance, hobby, home maintenance, house insurance, internet, loan payment, medication, movie, parking, personal care, pet food, public transport, restaurant, snack, subscription, toll, utilities, vehicle maintenance, alimony, bonus, commission, dividend, gift, part time, refund, rental income, salary, scholarship, subsidy.\n\n"
                    "Return ONLY the category name.\n\n$text"
              }
            ]
          }
        ]
      }),
    );

    if (response.statusCode != 200) {
      print("Gemini Error: ${response.body}");
      throw Exception("Gemini API failed");
    }

    final data = jsonDecode(response.body);

    final result =
    data['candidates'][0]['content']['parts'][0]['text']
        .toString()
        .trim()
        .toLowerCase();

    print("Gemini Category: $result");

    return result;
  }

  // static Future<Map<String, String>?> _predictCategoryAI(String text) async {
  //   final apiKey = dotenv.env['GEMINI_API_KEY'];
  //
  //   if (apiKey == null) {
  //     print("❌ Gemini API key missing");
  //     return null;
  //   }
  //
  //   final url =
  //       'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key=$apiKey';
  //
  //   final response = await http.post(
  //     Uri.parse(url),
  //     headers: {
  //       'Content-Type': 'application/json',
  //     },
  //     body: jsonEncode({
  //       "contents": [
  //         {
  //           "parts": [
  //             {
  //               "text":
  //               "Classify this receipt into ONE category only: Food, Transport, Groceries, Shopping, Bills, Entertainment, Others. Return ONLY the category name.\n\n$text"
  //             }
  //           ]
  //         }
  //       ]
  //     }),
  //   );
  //
  //   if (response.statusCode != 200) {
  //     print("Gemini Error: ${response.body}");
  //     return null;
  //   }
  //
  //   final data = jsonDecode(response.body);
  //
  //   final categoryName = data['candidates'][0]['content']['parts'][0]['text']
  //       .toString()
  //       .trim();
  //
  //   print("Gemini Category: $categoryName");
  //
  //   /// 🔥 Match with your DB
  //   final res = await Supabase.instance.client
  //       .from('Category')
  //       .select('categoryId, name');
  //
  //   for (final cat in res) {
  //     if (cat['name'].toString().toLowerCase() ==
  //         categoryName.toLowerCase()) {
  //       return {
  //         'id': cat['categoryId'],
  //         'name': cat['name'],
  //       };
  //     }
  //   }
  //
  //   return null;
  // }
}