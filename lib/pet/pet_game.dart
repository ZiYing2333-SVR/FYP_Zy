import 'dart:ui';

import 'package:flame/game.dart';
import 'pet_component.dart';

class PetGame extends FlameGame {
final Map<String, dynamic> petData;
final List equippedItems;

late Pet pet;

PetGame({
  required this.petData,
  required this.equippedItems,
});

@override
Color backgroundColor() => const Color(0x00000000); // 🔥 TRANSPARENT

@override
Future<void> onLoad() async {
  await super.onLoad();

  pet = Pet(petData, equippedItems)
    ..position = Vector2(size.x / 2, size.y / 2);

  add(pet);
}
}