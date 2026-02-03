import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'free_saving_page.dart';
import 'circle_saving_page.dart';

class CreateSavingPage extends StatefulWidget {
  final String userId;

  const CreateSavingPage({super.key, required this.userId});

  @override
  State<CreateSavingPage> createState() => _CreateSavingPageState();
}

class _CreateSavingPageState extends State<CreateSavingPage> {
  String _selectedSavingType = 'Free Saving';
  final List<String> _savingTypes = ['Free Saving', 'Circle Saving'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFB),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close, color: Colors.black),
        ),
        title: const Text(
          'Saving Types',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            ..._savingTypes.map(
              (type) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSavingType = type;
                    });
                    // Navigate to the specific saving type creation page
                    _navigateToSavingTypeCreation(type);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: _selectedSavingType == type
                          ? Border.all(color: Colors.green, width: 2)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          type,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.green.shade700,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToSavingTypeCreation(String savingType) async {
    Widget nextPage;

    if (savingType == 'Free Saving') {
      nextPage = FreeSavingPage(userId: widget.userId);
    } else {
      nextPage = CircleSavingPage(userId: widget.userId);
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => nextPage),
    );

    // If a goal was created successfully, pop back to savings_page with result
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }
}
