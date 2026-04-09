import 'package:flutter/material.dart';
import 'package:fyp_zy/pet/pet_shop_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fyp_zy/main.dart';
import 'package:fyp_zy/screens/home_screen.dart';
import 'dart:async';
import 'package:fyp_zy/pet/pet_game_widget.dart';

class PetHomePage extends StatefulWidget {
  final String petId;
  final String userId;

  const PetHomePage({required this.petId, required this.userId});

  @override
  State<PetHomePage> createState() => _PetHomePageState();
}

class _PetHomePageState extends State<PetHomePage> {
  final supabase = Supabase.instance.client;
  List purchasedItems = [];
  bool showInventory = false;
  String selectedInventoryCategory = "Food";
  Timer? happinessTimer;

  List get filteredItems {
    return purchasedItems.where((item) {
      return item['ShopItem']['category'] == selectedInventoryCategory;
    }).toList();
  }

  Map<String, dynamic>? petData;
  int coinBalance = 0;

  @override
  void initState() {
    super.initState();
    initData();
  }

  Future<void> initData() async {
    await fetchPet();
    await fetchUser();
    await fetchEquippedItems();

    startHappinessDecay();
  }

  @override
  void dispose() {
    happinessTimer?.cancel(); // ✅ stop timer
    super.dispose();
  }

  List equippedItems = [];

  Map<String, Map<String, dynamic>> slotConfig = {
    "Hat": {"top": 10, "left": 0, "right": 0, "scale": 1.0},
    "Clothes": {"top": 60, "left": 0, "right": 0, "scale": 1.0},
    "Accessory": {"top": 40, "left": 20, "scale": 0.6},
  };

  Future<void> fetchUser() async {
    final data = await supabase
        .from('User')
        .select('coinbalance')
        .eq('userId', widget.userId)
        .single();

    setState(() {
      coinBalance = (data['coinbalance'] as num).toInt();
    });
  }

  Future<void> fetchEquippedItems() async {
    final data = await supabase
        .from('PetCustomization')
        .select('''
        isEquipped,
        UserPurchasedItem (
          ShopItem (
            imagePath,
            slotType
          )
        )
      ''')
        .eq('petId', widget.petId)
        .eq('isEquipped', true);

    setState(() {
      equippedItems = data;
    });
  }

  /// 🐾 Fetch Pet + PetChoice
  Future<void> fetchPet() async {
    final data = await supabase
        .from('Pet')
        .select('''
          happinessScore,
          PetChoice (
            petBasePath,
            petHappyPath,
            petSadPath
          )
        ''')
        .eq('petId', widget.petId)
        .single();

    setState(() {
      petData = data;
    });
  }

  Future<void> fetchInventory() async {
    final data = await supabase
        .from('UserPurchasedItem')
        .select('''
      purchasedItemId,
      itemId,
      quantity,
      ShopItem (
        itemName,
        category,
        imagePath,
        slotType,
        happinessBoost
      )
    ''')
        .eq('userId', widget.userId)
        .gte('quantity', 1);

    setState(() {
      purchasedItems = data;
    });

    print(data);
  }

  void startHappinessDecay() {
    happinessTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return; // 🔥 IMPORTANT

      if (petData == null) return;

      int current = (petData!['happinessScore'] as num).toInt();

      if (current <= 0) return;

      int newScore = current - 1;

      await supabase
          .from('Pet')
          .update({'happinessScore': newScore})
          .eq('petId', widget.petId);

      if (!mounted) return; // 🔥 DOUBLE SAFETY

      setState(() {
        petData!['happinessScore'] = newScore;
      });
    });
  }

  Future<void> removeAllEquipment() async {
    await supabase
        .from('PetCustomization')
        .update({'isEquipped': false})
        .eq('petId', widget.petId);

    await fetchEquippedItems();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("All equipment removed 🚫")));
  }

  Future<void> removeBySlot(String slotType) async {
    final data = await supabase
        .from('PetCustomization')
        .select('''
        customizationId,
        UserPurchasedItem (
          ShopItem (slotType)
        )
      ''')
        .eq('petId', widget.petId)
        .eq('isEquipped', true);

    for (var item in data) {
      final itemSlot = item['UserPurchasedItem']?['ShopItem']?['slotType'];

      if (itemSlot == slotType) {
        await supabase
            .from('PetCustomization')
            .update({'isEquipped': false})
            .eq('customizationId', item['customizationId']);
      }
    }

    await fetchEquippedItems();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("$slotType removed 🚫")));
  }

  Future<List<String>> _getSameSlotItems(String slotType) async {
    final data = await supabase.from('UserPurchasedItem').select('''
        purchasedItemId,
        ShopItem (slotType)
      ''');

    return data
        .where((item) => item['ShopItem']['slotType'] == slotType)
        .map<String>((item) => item['purchasedItemId'])
        .toList();
  }

  Future<void> applyItem(Map purchasedItem) async {
    final shopItem = purchasedItem['ShopItem'];

    String slotType = shopItem['slotType'];
    int happinessBoost = (shopItem['happinessBoost'] as num?)?.toInt() ?? 0;

    String purchasedItemId = purchasedItem['purchasedItemId'];

    String customizationId = await generateCustomizationId();

    if (slotType == "Consumable") {
      await consumeFood(purchasedItemId, customizationId, happinessBoost);
    } else {
      await equipItem(
        purchasedItemId,
        customizationId,
        happinessBoost,
        slotType,
      );
    }

    /// 🔥 MUST refresh AFTER action
    await fetchInventory();
    await fetchEquippedItems();
    await fetchPet(); // (optional but good)

    setState(() {});
  }

  Future<String> generateCustomizationId() async {
    final data = await supabase
        .from('PetCustomization')
        .select('customizationId')
        .order('customizationId', ascending: false)
        .limit(1);

    if (data.isEmpty) return "CI000001";

    String lastId = data.first['customizationId'];
    int number = int.parse(lastId.substring(2));
    number++;

    return "CI${number.toString().padLeft(6, '0')}";
  }

  Future<void> consumeFood(
    String purchasedItemId,
    String customizationId,
    int happinessBoost,
  ) async {
    await supabase.from('PetCustomization').insert({
      'customizationId': customizationId,
      'appliedAt': DateTime.now().toIso8601String(),
      'isConsumed': true,
      'isEquipped': false,
      'petId': widget.petId,
      'purchasedItemId': purchasedItemId,
    });

    final data = await supabase
        .from('UserPurchasedItem')
        .select('quantity')
        .eq('purchasedItemId', purchasedItemId)
        .single();

    int qty = (data['quantity'] as num).toInt();

    print("Before consume qty = $qty");

    if (qty > 1) {
      await supabase
          .from('UserPurchasedItem')
          .update({'quantity': qty - 1})
          .eq('purchasedItemId', purchasedItemId);
    } else {
      await supabase
          .from('UserPurchasedItem')
          .update({'quantity': 0})
          .eq('purchasedItemId', purchasedItemId);
    }

    await increaseHappiness(happinessBoost);

    showPetMessage("Yum! 🍖 Happiness +$happinessBoost");

    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> equipItem(
    String purchasedItemId,
    String customizationId,
    int happinessBoost,
    String slotType,
  ) async {
    /// 1️⃣ Unequip same slot
    final existing = await supabase
        .from('PetCustomization')
        .select('''
        customizationId,
        UserPurchasedItem (
          ShopItem (slotType)
        )
      ''')
        .eq('petId', widget.petId)
        .eq('isEquipped', true);

    for (var item in existing) {
      final existingSlot = item['UserPurchasedItem']?['ShopItem']?['slotType'];

      if (existingSlot == slotType) {
        await supabase
            .from('PetCustomization')
            .update({'isEquipped': false})
            .eq('customizationId', item['customizationId']);
      }
    }

    /// 2️⃣ Check duplicate
    final existingItem = await supabase
        .from('PetCustomization')
        .select('customizationId')
        .eq('petId', widget.petId)
        .eq('purchasedItemId', purchasedItemId)
        .maybeSingle();

    if (existingItem != null) {
      /// ✅ UPDATE
      await supabase
          .from('PetCustomization')
          .update({
            'isEquipped': true,
            'isConsumed': false,
            'appliedAt': DateTime.now().toIso8601String(),
          })
          .eq('customizationId', existingItem['customizationId']);
    } else {
      /// ✅ INSERT
      await supabase.from('PetCustomization').insert({
        'customizationId': customizationId,
        'appliedAt': DateTime.now().toIso8601String(),
        'isConsumed': false,
        'isEquipped': true,
        'petId': widget.petId,
        'purchasedItemId': purchasedItemId,
      });
    }

    /// 3️⃣ Update happiness
    await increaseHappiness(happinessBoost);
  }

  Future<void> increaseHappiness(int boost) async {
    int current = (petData!['happinessScore'] as num).toInt();

    int newScore = current + boost;

    if (newScore > 100) newScore = 100;

    await supabase
        .from('Pet')
        .update({'happinessScore': newScore})
        .eq('petId', widget.petId);

    setState(() {
      petData!['happinessScore'] = newScore;
    });
  }

  void showPetMessage(String msg) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            color: const Color(0xFFF5EBD9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFA77A5C), width: 3),
          ),

          child: Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }

  /// 🧠 Decide which image to show
  String getPetImage() {
    if (petData == null) return "";

    int happiness = petData!['happinessScore'];
    final choice = petData!['PetChoice'];

    if (happiness <= 50) {
      return choice['petSadPath'];
    } else if (happiness <= 75) {
      return choice['petBasePath'];
    } else {
      return choice['petHappyPath'];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (petData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    "assets/images/petLivingRoom.png",
                    fit: BoxFit.cover,
                  ),
                ),

                /// Left buttons
                Positioned(
                  top: 10,
                  left: 10,
                  child: Column(
                    children: [
                      iconButton(
                        icon: Icons.home,
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  HomeScreen(userId: widget.userId),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      iconButton(
                        icon: Icons.store,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PetShopPage(
                                petId: widget.petId,
                                userId: widget.userId,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                /// Stats
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      statBox(
                        icon: Icons.monetization_on,
                        value: coinBalance.toString(),
                      ),
                      const SizedBox(height: 8),
                      statBox(
                        icon: Icons.sentiment_satisfied,
                        value: "${petData!['happinessScore']}%",
                      ),
                    ],
                  ),
                ),

                /// Pet
                Center(
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: ClipRect(
                      child: PetGameWidget(
                        key: ValueKey(
                          "${petData!['happinessScore']}_${equippedItems.length}",
                        ),
                        petData: petData!,
                        equippedItems: equippedItems,
                      ),
                    ),
                  ),
                ),

                /// Arrow
                /// 🔽⬆ Toggle Arrow
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: iconButton(
                    icon: showInventory
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,

                    onTap: () async {
                      if (!showInventory) {
                        await fetchInventory();
                      }

                      setState(() {
                        showInventory = !showInventory;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          /// BOTTOM PANEL (only show when open)
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),

            height: showInventory
                ? MediaQuery.of(context).size.height * 0.5
                : 0,

            child: showInventory ? inventoryPanel() : null,
          ),
        ],
      ),
    );
  }

  /// Rounded Icon Button
  Widget iconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5EBD9), // fill
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFA77A5C), // stroke
            width: 3,
          ),
        ),
        child: Icon(icon, size: 28, color: Colors.black),
      ),
    );
  }

  /// Stat Box (Coin / Happiness)
  Widget statBox({required IconData icon, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EBD9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA77A5C), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// Equal icon width
          SizedBox(width: 24, height: 24, child: Icon(icon, size: 20)),

          const SizedBox(width: 6),

          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget inventoryItem(Map item) {
    return Container(
      padding: const EdgeInsets.all(8),

      decoration: BoxDecoration(
        color: const Color(0xFFF4F1EA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8C3A5), width: 2),
      ),

      child: Column(
        children: [
          Expanded(child: Image.network(item['imagePath'])),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget inventoryPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),

      decoration: BoxDecoration(
        color: const Color(0xFFF5EBD9).withValues(alpha: 0.95),

        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),

        border: Border.all(color: const Color(0xFFA77A5C), width: 3),
      ),

      child: Column(
        children: [
          const SizedBox(height: 12),

          /// 📂 Categories
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              inventoryCategoryBtn("Food", Icons.restaurant),

              inventoryCategoryBtn("Accessories", Icons.diamond),

              inventoryCategoryBtn("Clothes", Icons.checkroom),
            ],
          ),

          const SizedBox(height: 12),

          /// 🧺 Items Grid
          Expanded(
            child: GridView.builder(
              itemCount: selectedInventoryCategory == "Food"
                  ? filteredItems.length
                  : filteredItems.length + 1,

              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),

              itemBuilder: (_, i) {
                /// 🚫 FIRST ITEM ONLY for Accessories / Clothes
                if (i == 0 && selectedInventoryCategory != "Food") {
                  return restrictItem();
                }

                /// Adjust index
                final itemIndex = selectedInventoryCategory == "Food"
                    ? i
                    : i - 1;

                final item = filteredItems[itemIndex]['ShopItem'];

                return GestureDetector(
                  onTap: () async {
                    await applyItem(filteredItems[itemIndex]);
                  },
                  child: inventoryItem(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget inventoryCategoryBtn(String category, IconData icon) {
    bool isSelected = selectedInventoryCategory == category;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedInventoryCategory = category;
        });
      },

      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),

        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF5EBD9)
              : const Color(0xFFF5EBD9).withOpacity(0.4),

          borderRadius: BorderRadius.circular(14),

          border: Border.all(color: const Color(0xFFA77A5C), width: 2),
        ),

        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(
              category,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget restrictItem() {
    return GestureDetector(
      onTap: () {
        String slotType;

        if (selectedInventoryCategory == "Accessories") {
          slotType = "Head";
        } else if (selectedInventoryCategory == "Clothes") {
          slotType = "Body";
        } else {
          return; // Food no remove
        }

        removeBySlot(slotType);
      },

      child: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade200,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFA77A5C), width: 2),
        ),

        child: const Center(
          child: Icon(Icons.block, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}
