import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


import 'name_pet_page.dart';
class SelectPetPage extends StatefulWidget {
  final String userId;
  const SelectPetPage({super.key,required this.userId});

  @override
  State<SelectPetPage> createState() => _SelectPetPageState();
}

class _SelectPetPageState extends State<SelectPetPage> {
  final supabase = Supabase.instance.client;

  List pets = [];

  @override
  void initState() {
    super.initState();
    fetchPets();
  }

  /// Fetch PetChoice data
  Future<void> fetchPets() async {
    final data = await supabase
        .from('PetChoice')
        .select('petChoiceId, category, petBasePath');

    setState(() {
      pets = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          /// 🌄 Background
          Positioned.fill(
            child: Image.asset(
              "assets/images/petBackground.png",
              fit: BoxFit.cover,
            ),
          ),

          /// Page Content
          SafeArea(
            child: Column(
              children: [

                const SizedBox(height: 20),

                /// 🪵 Board Title
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      "assets/images/board.png",
                      width: 220,
                    ),
                    const Text(
                      "Select Pet",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// 📦 Main Container
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),

                      /// Stroke
                      border: Border.all(
                        color: const Color(0xFFA77A5C),
                        width: 5,
                      ),

                      /// Shadow
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),

                    /// 🐾 Pet Grid
                    child: GridView.builder(
                      itemCount: pets.length,
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.9,
                      ),
                      itemBuilder: (context, index) {
                        final pet = pets[index];

                        final imageUrl = pet['petBasePath'];

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NamePetPage(
                                  userId: widget.userId,
                                  petChoiceId: pet['petChoiceId'],
                                  category: pet['category'],
                                  imageUrl: imageUrl,
                                ),
                              ),
                            );
                          },

                          child: petBox(
                            category: pet['category'],
                            imageUrl: imageUrl,
                          ),
                        );
                      },

                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🐾 Pet Box Widget
  Widget petBox({
    required String category,
    required String imageUrl,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1EA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD8C3A5),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(12),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          /// Pet Image
          Expanded(
            child: Image.network(imageUrl),
          ),

          const SizedBox(height: 8),

          /// Category Text
          Text(
            category,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

  }
}
