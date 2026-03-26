import 'package:flutter/material.dart';
import 'package:fyp_wx/pet/pet_home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class PetGreetingPage extends StatelessWidget {
  final String userId;
  final String petId;
  final String petName;
  final String imageUrl;

  const PetGreetingPage({
    super.key,
    required this.userId,
    required this.petId,
    required this.petName,
    required this.imageUrl,
  });

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
                      width: 200,
                    ),
                    const Text(
                      "Pet",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// Container
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),

                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: const Color(0xFFA77A5C),
                        width: 5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),

                    child: Column(
                      children: [

                        /// 🐾 Inner Preview Container (BIGGER)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 24,
                          ),

                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F1EA),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFD8C3A5),
                              width: 2,
                            ),
                          ),

                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              /// Bigger Pet Image
                              Image.network(
                                imageUrl,
                                height: 240,
                              ),

                              const SizedBox(height: 20),

                              /// Greeting Text
                              Text(
                                "Hi, $petName !!",
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),


                    const SizedBox(height: 30),

                    const SizedBox(height: 30),

                      /// Continue Button (still inside big container)
                        SizedBox(
                          width: 220,
                          height:55,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PetHomePage(
                                    userId: userId,
                                    petId: petId,
                                  ),
                                ),
                              );
                            },

                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFA77A5C),
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text(
                              "Continue",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
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
