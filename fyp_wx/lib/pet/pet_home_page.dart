import 'package:flutter/material.dart';
import 'package:fyp_wx/pet/pet_shop_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fyp_wx/main.dart';

class PetHomePage extends StatefulWidget {
  final String petId;

  const PetHomePage({
    required this.petId,
  });

  @override
  State<PetHomePage> createState() => _PetHomePageState();
}

class _PetHomePageState extends State<PetHomePage> {
  final supabase = Supabase.instance.client;
  List purchasedItems = [];
  bool showInventory = false;
  String selectedInventoryCategory = "Food";

  List get filteredItems {
    return purchasedItems.where((item) {
      return item['ShopItem']['category'] ==
          selectedInventoryCategory;
    }).toList();
  }


  Map<String, dynamic>? petData;
  int coinBalance = 26; // temporary

  @override
  void initState() {
    super.initState();
    fetchPet();
    fetchEquippedItems();
  }

  List equippedItems = [];

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
        ShopItem (
          itemName,
          category,
          imagePath,
          slotType
        )
      ''');


    setState(() {
      purchasedItems = data;
    });
  }

  Future<void> removeAllEquipment() async {
    await supabase
        .from('PetCustomization')
        .update({
      'isEquipped': false,
    })
        .eq('petId', widget.petId);

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
            "All equipment removed 🚫"),
      ),
    );
  }

  Future<void> applyItem(Map purchasedItem) async {
    final shopItem = purchasedItem['ShopItem'];

    debugPrint(shopItem.toString());


    String slotType = shopItem['slotType'];
    int happinessBoost =
        (shopItem['happinessBoost'] as num?)?.toInt() ?? 0;


    String purchasedItemId =
    purchasedItem['purchasedItemId'];

    /// Generate Customization ID
    String customizationId =
    await generateCustomizationId();

    /// FOOD → consume
    if (slotType == "Food") {
      await consumeFood(
        purchasedItemId,
        customizationId,
        happinessBoost,
      );
    }

    /// ACCESSORIES / CLOTHES → equip
    else {
      await equipItem(
        purchasedItemId,
        customizationId,
        happinessBoost,
        slotType,
      );
    }

    await fetchPet();
    await fetchInventory();
    await fetchEquippedItems();

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

    /// Insert customization record
    await supabase.from('PetCustomization').insert({
      'customizationId': customizationId,
      'appliedAt': DateTime.now().toIso8601String(),
      'isConsumed': true,
      'isEquipped': false,
      'petId': widget.petId,
      'purchasedItemId': purchasedItemId,
    });

    /// Reduce quantity
    final data = await supabase
        .from('UserPurchasedItem')
        .select('quantity')
        .eq('purchasedItemId', purchasedItemId)
        .single();

    int qty = (data['quantity'] as num).toInt();
    qty--;

    if (qty <= 0) {
      await supabase
          .from('UserPurchasedItem')
          .delete()
          .eq('purchasedItemId', purchasedItemId);
    } else {
      await supabase
          .from('UserPurchasedItem')
          .update({'quantity': qty})
          .eq('purchasedItemId', purchasedItemId);
    }

    /// Increase happiness
    await increaseHappiness(happinessBoost);

    showPetMessage("Yum! 🍖 Happiness +$happinessBoost");
  }

  Future<void> equipItem(
      String purchasedItemId,
      String customizationId,
      int happinessBoost,
      String slotType,
      ) async {

    /// 1️⃣ Unequip existing items
    await supabase
        .from('PetCustomization')
        .update({'isEquipped': false})
        .eq('petId', widget.petId);

    /// 2️⃣ Insert new equipped record
    await supabase.from('PetCustomization').insert({
      'customizationId': customizationId,
      'appliedAt': DateTime.now().toIso8601String(),
      'isConsumed': false,
      'isEquipped': true,
      'petId': widget.petId,
      'purchasedItemId': purchasedItemId,
    });

    /// 3️⃣ Increase happiness
    await supabase
        .from('Pet')
        .update({
      'happinessScore':
      petData!['happinessScore'] +
          happinessBoost
    })
        .eq('petId', widget.petId);
  }


  Future<void> increaseHappiness(int boost) async {
    int current =
    (petData!['happinessScore'] as num).toInt();

    int newScore = current + boost;

    if (newScore > 100) newScore = 100;

    await supabase
        .from('Pet')
        .update({'happinessScore': newScore})
        .eq('petId', widget.petId);
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
            border: Border.all(
              color: const Color(0xFFA77A5C),
              width: 3,
            ),
          ),

          child: Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Column(
        children: [

          /// 🏠 TOP 50% (Background + Pet)
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
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },

                      ),

                      const SizedBox(height: 12),

                      iconButton(
                        icon: Icons.store,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PetShopPage(
                                    petId:
                                    widget.petId,
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
                        value:
                        coinBalance.toString(),
                      ),
                      const SizedBox(height: 8),
                      statBox(
                        icon: Icons
                            .sentiment_satisfied,
                        value:
                        "${petData!['happinessScore']}%",
                      ),
                    ],
                  ),
                ),

                /// Pet
                Center(
                  child: SizedBox(
                    height: 220,
                    width: 220,

                    child: Stack(
                      alignment: Alignment.center,
                      children: [

                        /// 🐾 Base Pet
                        Image.network(
                          getPetImage(),
                          height: 220,
                        ),

                        /// 👕 Equipped Items
                        ...equippedItems.map((e) {
                          final item =
                          e['UserPurchasedItem']['ShopItem'];

                          return Image.network(
                            item['imagePath'],
                            height: 220,
                          );
                        }).toList(),
                      ],
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

          /// 🧺 BOTTOM PANEL (only show when open)
          /// 🧺 Bottom Panel Animated
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),

            height: showInventory
                ? MediaQuery.of(context).size.height * 0.5
                : 0,

            child: showInventory
                ? inventoryPanel()
                : null,
          ),


        ],
      ),
    );

  }

  /// Rounded Icon Button
  Widget iconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
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
        child: Icon(
          icon,
          size: 28,
          color: Colors.black,
        ),
      ),
    );
  }

  /// Stat Box (Coin / Happiness)
  Widget statBox({
    required IconData icon,
    required String value,
  }) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EBD9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFA77A5C),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [

          /// Equal icon width
          SizedBox(
            width: 24,
            height: 24,
            child: Icon(icon, size: 20),
          ),

          const SizedBox(width: 6),

          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
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
        border: Border.all(
          color: const Color(0xFFD8C3A5),
          width: 2,
        ),
      ),

      child: Column(
        children: [

          Expanded(
            child: Image.network(
              item['imagePath'],
            ),
          ),

          const SizedBox(height: 4),

        ],
      ),
    );
  }

  Widget inventoryPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          16, 18, 16, 12),

      decoration: BoxDecoration(
        color: const Color(0xFFF5EBD9).withValues(alpha: 0.95),

        borderRadius:
        const BorderRadius.vertical(
          top: Radius.circular(30),
        ),

        border: Border.all(
          color: const Color(0xFFA77A5C),
          width: 3,
        ),
      ),

      child: Column(
        children: [

          const SizedBox(height: 12),

          /// 📂 Categories
          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceEvenly,
            children: [

              inventoryCategoryBtn(
                "Food",
                Icons.restaurant,
              ),

              inventoryCategoryBtn(
                "Accessories",
                Icons.diamond,
              ),

              inventoryCategoryBtn(
                "Clothes",
                Icons.checkroom,
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// 🧺 Items Grid
          Expanded(
            child: GridView.builder(
              itemCount: selectedInventoryCategory == "Food"
                  ? filteredItems.length
                  : filteredItems.length + 1,


              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),

              itemBuilder: (_, i) {

                /// 🚫 FIRST ITEM ONLY for Accessories / Clothes
                if (i == 0 &&
                    selectedInventoryCategory != "Food") {
                  return restrictItem();
                }

                /// Adjust index
                final itemIndex =
                selectedInventoryCategory == "Food"
                    ? i
                    : i - 1;

                final item =
                filteredItems[itemIndex]['ShopItem'];

                return GestureDetector(
                  onTap: () => applyItem(
                    purchasedItems[itemIndex],
                  ),
                  child: inventoryItem(item),
                );

              },

            ),
          ),

        ],
      ),
    );
  }

  Widget inventoryCategoryBtn(
      String category,
      IconData icon,
      ) {
    bool isSelected =
        selectedInventoryCategory ==
            category;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedInventoryCategory =
              category;
        });
      },

      child: Container(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 6,
        ),

        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF5EBD9)
              : const Color(0xFFF5EBD9)
              .withOpacity(0.4),

          borderRadius:
          BorderRadius.circular(14),

          border: Border.all(
            color: const Color(
                0xFFA77A5C),
            width: 2,
          ),
        ),

        child: Row(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(
              category,
              style:
              const TextStyle(
                fontSize: 12,
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget restrictItem() {
    return GestureDetector(
      onTap: removeAllEquipment,

      child: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade200,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFA77A5C),
            width: 2,
          ),
        ),

        child: const Center(
          child: Icon(
            Icons.block,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }


}

