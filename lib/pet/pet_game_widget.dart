import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'pet_game.dart';

class PetGameWidget extends StatelessWidget {
  final Map<String, dynamic> petData;
  final List equippedItems;

  const PetGameWidget({
    super.key,
    required this.petData,
    required this.equippedItems,
  });

  @override
  Widget build(BuildContext context) {
    return GameWidget(
      game: PetGame(
        petData: petData,
        equippedItems: equippedItems,
      ),
      backgroundBuilder: (context) => Container(
        color: Colors.transparent,
      ),
    );
  }
}