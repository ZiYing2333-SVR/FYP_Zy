import 'package:flutter/material.dart';
import 'package:fyp_zy/pet/pet_greeting_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _formKey = GlobalKey<FormState>();

class NamePetPage extends StatefulWidget {
  final String userId;
  final String petChoiceId;
  final String category;
  final String imageUrl;


  const NamePetPage({
    super.key,
    required this.userId,
    required this.petChoiceId,
    required this.category,
    required this.imageUrl,
  });


  @override
  State<NamePetPage> createState() => _NamePetPageState();
}

class _NamePetPageState extends State<NamePetPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController nameController =
  TextEditingController();

  bool isLoading = false;

  /// Insert Pet Record
  Future<void> createPet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      /// Generate ID
      String newPetId = await generatePetId();

      /// Insert into Pet table
      await supabase.from('Pet').insert({
        'petId': newPetId,
        'petName': nameController.text.trim(),
        'happinessScore': 80, // default
        'createdAt': DateTime.now().toIso8601String(),
        'petChoiceId': widget.petChoiceId,
        'userId': widget.userId,
      });

      /// Navigate to greeting page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PetGreetingPage(
            petId: newPetId,
            userId: widget.userId,
            petName: nameController.text.trim(),
            imageUrl: widget.imageUrl,
          ),
        ),
      );


    } catch (e) {
      debugPrint("Insert error: $e");
    }

    setState(() => isLoading = false);
  }


  Future<String> generatePetId() async {
    final data = await supabase
        .from('Pet')
        .select('petId')
        .order('petId', ascending: false)
        .limit(1);

    if (data.isEmpty) {
      return "P0001";
    }

    String lastId = data.first['petId']; // e.g. P0007
    int number = int.parse(lastId.substring(1));
    number++;

    return "P${number.toString().padLeft(4, '0')}";
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          /// Background
          Positioned.fill(
            child: Image.asset(
              "assets/images/petBackground.png",
              fit: BoxFit.cover,
            ),
          ),

          SafeArea(
            child: Column(
              children: [

                const SizedBox(height: 20),

                /// Board Title
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      "assets/images/board.png",
                      width: 260,
                    ),
                    const Text(
                      "Name Your Pet",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// Main Container
                Expanded(
                  child: Container(
                    margin:
                    const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(20),

                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: const Color(0xFFA77A5C),
                        width: 5,
                      ),

                      boxShadow: [
                        BoxShadow(
                          color:
                          Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),

                    child: Column(
                      children: [

                        /// 🐾 Pet Preview Box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F1EA),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFD8C3A5),
                              width: 2,
                            ),
                          ),

                          child: Column(
                            children: [

                              /// Bigger Pet Image
                              Image.network(
                                widget.imageUrl,
                                height: 180,   //
                              ),

                              const SizedBox(height: 12),

                              /// Category Text
                              Text(
                                widget.category,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),   //

                        /// Name Label
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [

                              /// Name Label
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Name:",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              /// Name TextFormField
                              TextFormField(
                                controller: nameController,

                                decoration: InputDecoration(
                                  hintText: "Write here...",
                                  filled: true,
                                  fillColor: const Color(0xFFF4F1EA),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),

                                /// 🔎 Validation logic
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return "Please enter your pet name";
                                  }

                                  if (value.length < 2) {
                                    return "Name must be at least 2 characters";
                                  }

                                  if (value.length > 12) {
                                    return "Name cannot exceed 12 characters";
                                  }

                                  final regex = RegExp(r'^[a-zA-Z0-9 ]+$');
                                  if (!regex.hasMatch(value)) {
                                    return "No special characters allowed";
                                  }

                                  return null; // valid
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        /// Continue Button
                        SizedBox(
                          width: 180,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                createPet();
                              }
                            },

                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA77A5C),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),

                            /// Bold + White text
                            child: const Text(
                              "Continue",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),

                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
