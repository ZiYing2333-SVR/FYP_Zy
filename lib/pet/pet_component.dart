import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

class Pet extends PositionComponent with TapCallbacks, HasGameRef {
  final Map<String, dynamic> petData;
  final List equippedItems;

  late SpriteComponent body;

  Map<String, Sprite> sprites = {};

  double time = 0;

  Pet(this.petData, this.equippedItems);

  @override
  Future<void> onLoad() async {
    size = Vector2(200, 200);
    anchor = Anchor.center;

    final choice = petData['PetChoice'];

    /// 🐾 Load pet images
    sprites['idle'] =
        Sprite(await loadNetworkImage(choice['petBasePath']));
    sprites['happy'] =
        Sprite(await loadNetworkImage(choice['petHappyPath']));
    sprites['sad'] =
        Sprite(await loadNetworkImage(choice['petSadPath']));

    body = SpriteComponent()
      ..sprite = sprites['idle']
      ..size = size;

    add(body);

    await loadClothes();
  }

  /// 👕 Load clothes
  Future<void> loadClothes() async {
    for (var e in equippedItems) {
      final item = e['UserPurchasedItem']['ShopItem'];

      final image = await loadNetworkImage(item['imagePath']);

      final cloth = SpriteComponent()
        ..sprite = Sprite(image)
        ..size = size
        ..priority = 1       // always above body
        ..anchor = Anchor.center;

      switch (item['slotType']) {
        case "Head":
          cloth.position = Vector2(50, 20); // 👈 up
          cloth.scale = Vector2.all(0.4);
          break;

        case "Body":
          cloth.position = Vector2(90, 150); // 👈 down
          cloth.scale = Vector2(0.9, 0.4);
          break;

        case "Accessory":
          cloth.position = Vector2(95, 150); // 👈 right side
          cloth.scale = Vector2.all(0.6);
          break;
      }

      add(cloth);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    /// 🌬️ breathing animation
    time += dt;
    scale = Vector2.all(1 + 0.02 * sin(time));

    /// 🧠 state change
    int happiness = petData['happinessScore'];

    if (happiness <= 50) {
      body.sprite = sprites['sad'];
    } else if (happiness <= 75) {
      body.sprite = sprites['idle'];
    } else {
      body.sprite = sprites['happy'];
    }
  }

  /// 👆 tap reaction
  @override
  void onTapDown(TapDownEvent event) {
    body.scale = Vector2.all(1.2);

    Future.delayed(const Duration(milliseconds: 150), () {
      body.scale = Vector2.all(1.0);
    });
  }

  /// 🌐 LOAD NETWORK IMAGE (FIXED)
  Future<ui.Image> loadNetworkImage(String url) async {
    final completer = Completer<ui.Image>();

    final stream =
    NetworkImage(url).resolve(const ImageConfiguration());

    stream.addListener(
      ImageStreamListener((info, _) {
        completer.complete(info.image);
      }),
    );

    return completer.future;
  }
}