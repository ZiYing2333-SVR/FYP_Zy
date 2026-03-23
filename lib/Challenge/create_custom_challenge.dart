import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateCustomChallengePage extends StatefulWidget {
  final String userId;

  const CreateCustomChallengePage({
    super.key,
    required this.userId,
  });

  @override
  State<CreateCustomChallengePage> createState() =>
      _CreateCustomChallengePageState();
}

class _CreateCustomChallengePageState extends State<CreateCustomChallengePage> {
  final _formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final rulesController = TextEditingController();
  final targetController = TextEditingController();

  String type = "spending_limit";
  int duration = 7;
  int coins = 5;

  Future<void> createChallenge() async {
    if (!_formKey.currentState!.validate()) return;

    final supabase = Supabase.instance.client;

    try {
      final newId = await generateCustomChallengeId();

      await supabase.from('CustomChallenge').insert({
        "customChallengeId": newId,
        "title": titleController.text.trim(),
        "description": rulesController.text.trim(),
        "type": type,
        "duration": duration,
        "rewardedCoins": coins,
        "targetAmount": targetController.text.trim().isEmpty
            ? null
            : double.parse(targetController.text.trim()),
        "userId": widget.userId,
        "createdAt": DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Challenge Created")),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error creating custom challenge: $e");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to create challenge: $e")),
      );
    }
  }

  Future<String> generateCustomChallengeId() async {
    final supabase = Supabase.instance.client;

    final data = await supabase
        .from('CustomChallenge')
        .select('customChallengeId')
        .order('customChallengeId', ascending: false)
        .limit(1);

    if (data.isEmpty) {
      return "CC0001";
    }

    final lastId = data.first['customChallengeId'];
    final number = int.parse(lastId.substring(2)) + 1;

    return "CC${number.toString().padLeft(4, '0')}";
  }

  @override
  void dispose() {
    titleController.dispose();
    rulesController.dispose();
    targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFFD3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFEFFD3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/createChallenge.png',
                    width: 60,
                    height: 60,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Custom Challenge',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              buildSideField(
                "Title",
                TextFormField(
                  controller: titleController,
                  validator: required,
                  decoration: inputStyle(),
                ),
              ),


              buildSideField(
                "Descriptions",
                TextFormField(
                  controller: rulesController,
                  validator: required,
                  decoration: inputStyle(),
                ),
              ),

              buildSideField(
                "Type",
                DropdownButtonFormField<String>(
                  value: type,
                  isExpanded: true,
                  decoration: inputStyle(),
                  items: const [
                    DropdownMenuItem(
                      value: "spending_limit",
                      child: Text("Spending Limit"),
                    ),
                    DropdownMenuItem(
                      value: "saving_goal",
                      child: Text("Saving Goal"),
                    ),
                  ],
                  onChanged: (v) => setState(() => type = v!),
                ),
              ),

                buildSideField(
                  "Target Amount",
                  TextFormField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: inputStyle(),
                  ),
                ),

              buildSideField(
                "Durations",
                numberSpinner(
                  value: duration,
                  min: 1,
                  max: 14,
                  onChanged: (v) => setState(() => duration = v),
                ),
              ),

              buildSideField(
                "Coin Rewarded",
                numberSpinner(
                  value: coins,
                  min: 1,
                  max: 20,
                  onChanged: (v) => setState(() => coins = v),
                ),
              ),

              SizedBox(
                width: 200,
                height: 55,
                child: ElevatedButton(
                  onPressed: createChallenge,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9ED39E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Create",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSideField(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: field),
        ],
      ),
    );
  }

  Widget numberSpinner({
    required int value,
    required int min,
    required int max,
    required Function(int) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          Expanded(
            child: Center(
              child: Text(
                "$value",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }

  InputDecoration inputStyle() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
    );
  }

  String? required(String? v) => v == null || v.trim().isEmpty ? "Required" : null;
}