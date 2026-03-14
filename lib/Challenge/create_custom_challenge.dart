import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateCustomChallengePage
    extends StatefulWidget {
  const CreateCustomChallengePage({super.key});

  @override
  State<CreateCustomChallengePage> createState() =>
      _CreateCustomChallengePageState();
}

class _CreateCustomChallengePageState
    extends State<CreateCustomChallengePage> {
  final _formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final descriptionController =
  TextEditingController();
  final rulesController = TextEditingController();
  final targetController = TextEditingController();

  String type = "streak";
  int duration = 7;
  int coins = 5;

  /// ================= CREATE =================
  Future<void> createChallenge() async {
    if (!_formKey.currentState!.validate())
      return;

    final supabase = Supabase.instance.client;

    final user =
        supabase.auth.currentUser;

    final userId =
        user?.id; // nullable safe


    /// 🔢 Generate ID
    final newId =
    await generateCustomChallengeId();

    await supabase.from('CustomChallenge').insert({
      "customChallengeId": newId,
      "title": titleController.text,
      "description":
      descriptionController.text,
      "rules": rulesController.text,
      "type": type,
      "duration": duration,
      "rewardedCoins": coins,
      "targetAmount":
      targetController.text.isEmpty
          ? null
          : double.parse(
          targetController.text),
      "userId": userId,
      "createdAt":
      DateTime.now().toIso8601String(),
    });

    /// Success message
    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
          content:
          Text("Challenge Created")),
    );

    Navigator.pop(context);
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

    final number =
        int.parse(lastId.substring(2)) + 1;

    return "CC${number.toString().padLeft(4, '0')}";
  }


  /// ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFFEFFD3),

      appBar: AppBar(
        backgroundColor:
        const Color(0xFFFEFFD3),
        elevation: 0,
        leading: IconButton(
          icon:
          const Icon(Icons.arrow_back),
          onPressed: () =>
              Navigator.pop(context),
        ),
      ),

      body: SingleChildScrollView(
        padding:
        const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              /// ===== HEADER =====
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

              /// ===== FIELDS =====
              buildSideField(
                  "Title",
                  TextFormField(
                    controller:
                    titleController,
                    validator: required,
                    decoration:
                    inputStyle(),
                  )),

              buildSideField(
                  "Description",
                  TextFormField(
                    controller:
                    descriptionController,
                    validator: required,
                    decoration:
                    inputStyle(),
                  )),

              buildSideField(
                  "Rules",
                  TextFormField(
                    controller:
                    rulesController,
                    validator: required,
                    decoration:
                    inputStyle(),
                  )),

              /// ===== TYPE =====
              buildSideField(
                "Type",
                DropdownButtonFormField<String>(
                  value: type,
                  isExpanded: true, // ✅ prevents overflow
                  decoration: inputStyle(),
                  items: const [
                    DropdownMenuItem(
                      value: "streak",
                      child: Text(
                        "Streak",
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: "spending_limit",
                      child: Text(
                        "Spending Limit",
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: "saving_goal",
                      child: Text(
                        "Saving Goal",
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => type = v!),
                ),
              ),

              /// ===== TARGET AMOUNT ====
              if (type != "streak")
                buildSideField(
                  "Target Amount",
                  TextFormField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: inputStyle(),
                  ),
                ),


              /// ===== DURATION SPINNER =====
              buildSideField(
                "Durations",
                numberSpinner(
                  value: duration,
                  min: 1,
                  max: 14,
                  onChanged: (v) =>
                      setState(
                              () => duration = v),
                ),
              ),

              /// ===== COINS SPINNER =====
              buildSideField(
                "Coin Rewarded",
                numberSpinner(
                  value: coins,
                  min: 1,
                  max: 20,
                  onChanged: (v) =>
                      setState(
                              () => coins = v),
                ),
              ),



              /// ===== CREATE BUTTON =====
              SizedBox(
                width: 200,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    print("Create clicked");
                    createChallenge();
                  },

                  style: ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    const Color(
                        0xFF9ED39E),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius
                          .circular(
                          30),
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

  /// ================= COMPONENTS =================

  /// Left label + right field
  Widget buildSideField(
      String label, Widget field) {
    return Padding(
      padding:
      const EdgeInsets.only(
          bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style:
              const TextStyle(
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: field),
        ],
      ),
    );
  }

  /// Number Spinner
  Widget numberSpinner({
    required int value,
    required int min,
    required int max,
    required Function(int)
    onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(alpha: 0.6),
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
                Icons.remove),
            onPressed: value > min
                ? () =>
                onChanged(value - 1)
                : null,
          ),
          Expanded(
            child: Center(
              child: Text(
                "$value",
                style:
                const TextStyle(
                  fontSize: 16,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon:
            const Icon(Icons.add),
            onPressed: value < max
                ? () =>
                onChanged(value + 1)
                : null,
          ),
        ],
      ),
    );
  }

  /// Input style
  InputDecoration inputStyle() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white
          .withValues(alpha: 0.6),
      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
    );
  }

  String? required(String? v) =>
      v!.isEmpty ? "Required" : null;
}
