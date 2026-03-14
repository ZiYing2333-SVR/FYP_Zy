import 'package:flutter/material.dart';
import 'package:fyp_wx/OCR/receipt_error_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'receipt_confirm_page.dart';

class ReceiptScanPage extends StatefulWidget {
  const ReceiptScanPage({super.key});

  @override
  State<ReceiptScanPage> createState() => _ReceiptScanPageState();
}

class _ReceiptScanPageState extends State<ReceiptScanPage> {
  final picker = ImagePicker();
  bool loading = false;
  String result = '';
  Widget? successWidget;



  //==================upload photo ===============
  Future<XFile?> pickReceiptImage() async {
    return showModalBottomSheet<XFile?>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () async {
                  final status = await Permission.camera.request();
                  if (!status.isGranted) {
                    Navigator.pop(context);
                    return;
                  }
                  final image =
                  await picker.pickImage(source: ImageSource.camera);
                  Navigator.pop(context, image);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  final image =
                  await picker.pickImage(source: ImageSource.gallery);
                  Navigator.pop(context, image);
                },
              ),
            ],
          ),
        );
      },
    );
  }


  // ================= MAIN FLOW =================

  Future<void> scanReceipt() async {
    final image = await pickReceiptImage();
    if (image == null) return;

    setState(() => loading = true);

    try {
      final parsed = await extractWithLayout(image);

      final confirmed = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptConfirmPage(receipt: parsed),
        ),
      );

      if (confirmed == null) return;

      await saveReceipt(
        imageUrl: await uploadImage(image),
        amount: confirmed['amount'],
        date: confirmed['date'],
        items: (confirmed['items'] as List).join(', '),
        categoryId: await getCategoryIdByName(confirmed['category']),

      );

      setState(() {
        successWidget = buildSuccessContainer(
          items: (confirmed['items'] as List).join(', '),
          amount: confirmed['amount'],
          date: confirmed['date'] ?? '-',
          category: confirmed['category'],
        );
      });

// Auto-hide after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            successWidget = null;
          });
        }
      });

    } catch (e) {
      showErrorDialog();
    }

    setState(() => loading = false);
  }

  // =================get category name ====================

  Future<String?> getCategoryIdByName(String name) async {
    final res = await Supabase.instance.client
        .from('Category')
        .select('categoryId')
        .eq('name', name)
        .single();

    return res['categoryId'];
  }


  // ================= OCR (LAYOUT BASED) =================

  Future<ParsedReceipt> extractWithLayout(XFile image) async {
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

        final priceMatch =
        RegExp(r'\d+\.\d{2}').firstMatch(text);
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

    if (prices.isEmpty) {
      throw Exception('Amount not detected');
    }

    final amount =
    prices.reduce((a, b) => a > b ? a : b).toStringAsFixed(2);

    final date = extractDate(visionText.text);

    final categoryData = await predictCategory(visionText.text);

    return ParsedReceipt(
      items: items.toSet().toList(),
      amount: amount,
      date: date,
      categoryId: categoryData?['id'],
      categoryName: categoryData?['name'] ?? 'Uncategorized',
    );
  }

  String? extractDate(String text) {
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

  // ================= CATEGORY =================

  Future<Map<String, String>?> predictCategory(String text) async {
    final res = await Supabase.instance.client
        .from('Category')
        .select('categoryId, name');

    for (final cat in res) {
      if (text.toLowerCase().contains(
        cat['name'].toString().toLowerCase(),
      )) {
        return {
          'id': cat['categoryId'],
          'name': cat['name'],
        };
      }
    }
    return null;
  }

  // ================= STORAGE =================

  Future<String> uploadImage(XFile image) async {
    final bytes = await image.readAsBytes();
    final path =
        'receipts/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await Supabase.instance.client.storage
        .from('images')
        .uploadBinary(path, bytes);

    return Supabase.instance.client.storage
        .from('images')
        .getPublicUrl(path);
  }

  // ================= SAVE =================

  Future<void> saveReceipt({
    required String imageUrl,
    required String amount,
    String? date,
    required String items,
    String? categoryId,
  }) async {
    await Supabase.instance.client.from('Receipt').insert({
      'imagePath': imageUrl,
      'amount': double.parse(amount),
      'transactionDate': date == null || date.isEmpty
          ? null
          : DateFormat('dd/MM/yyyy').parse(date).toIso8601String(),
      'item': items,
      'categoryId': categoryId,
    });
  }

  // ================= UI =================

  void showErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReceiptErrorDialog(
        onRetry: () {
          scanReceipt();
        },

      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Scanner')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: loading ? null : scanReceipt,
              child: const Text('Scan Receipt'),
            ),
            const SizedBox(height: 20),
            if (loading) const CircularProgressIndicator(),
            const SizedBox(height: 20),
            if (successWidget != null) ...[
              const SizedBox(height: 20),
              successWidget!,
            ],

          ],
        ),
      ),
    );
  }

  Widget buildSuccessContainer({
    required String items,
    required String amount,
    required String date,
    required String category,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFFD3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: Colors.green,
            child: Icon(Icons.check, color: Colors.white),
          ),
          const SizedBox(height: 12),

          _infoRow('Item', items),
          _infoRow('Amount', 'RM $amount'),
          _infoRow('Category', category),
          _infoRow('Date', date),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 4,
        horizontal: 4, // 👈 SAME left & right padding
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8), // 👈 small controlled gap
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }


}
