import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PetShopPage extends StatefulWidget {
  final String petId;
  final String userId;

  const PetShopPage({
    super.key,
    required this.petId,
    required this.userId,
  });

  @override
  State<PetShopPage> createState() => _PetShopPageState();
}

class _PetShopPageState extends State<PetShopPage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? petData;
  List items = [];

  String selectedCategory = "Food";
  int coinBalance = 0;

  @override
  void initState() {
    super.initState();
    fetchItems();
    fetchPet();
    fetchUser();
  }

  /// 🐾 Fetch Pet + Mood Paths
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

  /// 🧠 Mood Logic
  String getPetImage() {
    if (petData == null) return "";

    int happiness =
    (petData!['happinessScore'] as num).toInt();

    final choice = petData!['PetChoice'];

    if (happiness <= 50) {
      return choice['petSadPath'];
    } else if (happiness <= 75) {
      return choice['petBasePath'];
    } else {
      return choice['petHappyPath'];
    }
  }


  /// 🛒 Fetch Items
  Future<void> fetchItems() async {
    final data = await supabase
        .from('ShopItem')
        .select(
        'itemId, category, price, imagePath, happinessBoost, slotType')
        .eq('category', selectedCategory);

    setState(() {
      items = data;
    });
  }

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

  /// 💰 Generate Purchase ID
  Future<String> generatePurchaseId() async {
    final data = await supabase
        .from('UserPurchasedItem')
        .select('purchasedItemId')
        .order('purchasedItemId', ascending: false)
        .limit(1);

    if (data.isEmpty) return "UPI00001";

    String lastId = data.first['purchasedItemId'];
    int number = int.parse(lastId.substring(3));
    number++;

    return "UPI${number.toString().padLeft(5, '0')}";
  }

  Future<Map<String, dynamic>?> getExistingItem(String itemId) async {
    final data = await supabase
        .from('UserPurchasedItem')
        .select('purchasedItemId, quantity')
        .eq('userId', widget.userId)
        .eq('itemId', itemId)
        .limit(1);

    if (data.isEmpty) return null;
    return data.first;
  }

  /// 🛍 Buy Item
  Future<void> buyItem(Map item) async {
    int price = (item['price'] as num).toInt();
    String slotType = item['slotType'];

    if (coinBalance < price) {
      showMessage("Coin not enough.", success: false);
      return;
    }

    final existing = await getExistingItem(item['itemId']);

    /// ❌ Non-food already owned → block
    if (existing != null && slotType != "Consumable") {
      showMessage("You already own this item!", success: false);
      return;
    }

    /// 💰 Deduct coin FIRST
    int newBalance = coinBalance - price;

    await supabase
        .from('User')
        .update({'coinbalance': newBalance})
        .eq('userId', widget.userId);

    /// 🍖 FOOD → increase quantity
    if (existing != null && slotType == "Consumable") {
      int newQty = (existing['quantity'] as num).toInt() + 1;

      await supabase
          .from('UserPurchasedItem')
          .update({'quantity': newQty})
          .eq('purchasedItemId', existing['purchasedItemId']);
    }

    /// 🆕 NEW ITEM
    else {
      String purchaseId = await generatePurchaseId();

      await supabase.from('UserPurchasedItem').insert({
        'purchasedItemId': purchaseId,
        'quantity': 1,
        'isUnlocked': true,
        'acquiredAt': DateTime.now().toIso8601String(),
        'userId': widget.userId,
        'itemId': item['itemId'],
      });
    }

    await fetchUser();

    showMessage("Purchase Success 🎉", success: true);
  }

  /// 🔔 Confirm Dialog
  void confirmBuy(Map item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),

          decoration: BoxDecoration(
            color: const Color(0xFFF5EBD9), // theme fill
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: const Color(0xFFA77A5C),
              width: 4,
            ),
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              /// Title
              const Text(
                "Confirm Purchase",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              /// Message
              Text(
                "Buy this item for ${item['price']} coins?",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),

              const SizedBox(height: 20),

              /// Buttons
              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceEvenly,
                children: [

                  /// NO
                  dialogBtn(
                    text: "Cancel",
                    color: Colors.grey,
                    onTap: () =>
                        Navigator.pop(context),
                  ),

                  /// YES
                  dialogBtn(
                    text: "Buy",
                    color: const Color(0xFFA77A5C),
                    onTap: () {
                      Navigator.pop(context);
                      buyItem(item);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  /// 🔔 Message Dialog
  void showMessage(String msg,
      {bool success = true}) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),

          decoration: BoxDecoration(
            color: const Color(0xFFF5EBD9),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: const Color(0xFFA77A5C),
              width: 4,
            ),
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              /// Icon
              Icon(
                success
                    ? Icons.check_circle
                    : Icons.cancel,
                color: success
                    ? Colors.green
                    : Colors.red,
                size: 48,
              ),

              const SizedBox(height: 12),

              /// Text
              Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 18),

              /// OK Button
              dialogBtn(
                text: "OK",
                color: const Color(0xFFA77A5C),
                onTap: () =>
                    Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget dialogBtn({
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),

        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFA77A5C),
            width: 2,
          ),
        ),

        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [

          /// 🏪 Top 50% (Background + Pet)
          Expanded(
            flex: 5,
            child: Stack(
              children: [

                Positioned.fill(
                  child: Image.asset(
                    "assets/images/petShop.png",
                    fit: BoxFit.cover,
                  ),
                ),

                /// Pet Preview
                if (petData != null)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Image.network(
                        getPetImage(),
                        height: 180,
                      ),
                    ),
                  ),

                /// Paw Back
                Positioned(
                  top: 40,
                  left: 16,
                  child: iconButton(
                    Icons.pets,
                        () =>
                        Navigator.pop(context),
                  ),
                ),

                /// Coin
                Positioned(
                  top: 40,
                  right: 16,
                  child: coinBox(),
                ),
              ],
            ),
          ),

          /// 🛒 Bottom 50% Shop Panel
          Expanded(
            flex: 5,
            child: Container(
              margin:
              const EdgeInsets.only(top: 6),

              padding:
              const EdgeInsets.fromLTRB(
                16,
                18,
                16,
                12,
              ),

              decoration: BoxDecoration(
                color:
                const Color(0xFFF5EBD9).withValues(alpha: 0.95),

                borderRadius:
                const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),

                border: Border.all(
                  color: const Color(0xFFA77A5C),
                  width: 3,
                ),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),

              child: Column(
                children: [

                  /// Category Board
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        categoryBtn(
                          "Food",
                          Icons.restaurant,
                        ),
                        categoryBtn(
                          "Accessories",
                          Icons.diamond,
                        ),
                        categoryBtn(
                          "Clothes",
                          Icons.checkroom,
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  /// Items Grid
                  Expanded(
                    child:
                    GridView.builder(
                      padding: const EdgeInsets.only(top: 6),

                      itemCount: items.length,

                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.78,
                      ),

                      itemBuilder:
                          (_, i) {
                        final item = items[i];

                        return GestureDetector(
                          onTap: () =>
                              confirmBuy(
                                  item),
                          child:
                          itemBox(item),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Icon Button
  Widget iconButton(
      IconData icon,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5EBD9),
          borderRadius:
          BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFA77A5C),
            width: 5,
          ),
        ),
        child: Icon(icon, size: 28),
      ),
    );
  }

  /// 💰 Coin Box
  Widget coinBox() {
    return Container(
      padding:
      const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EBD9),
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color:const Color(0xFFA77A5C),
          width: 3,
        ),
      ),
      child: Row(
        children: [
          const Icon(
              Icons.monetization_on),
          const SizedBox(width: 6),
          Text("$coinBalance"),
        ],
      ),
    );
  }

  /// 📂 Category Button
  Widget categoryBtn(
      String category,
      IconData icon,
      ) {
    bool isSelected = selectedCategory == category;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCategory = category;
        });
        fetchItems();
      },

      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,   // 👈 smaller width
          vertical: 6,      // 👈 smaller height
        ),

        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5EBD9)
              : const Color(0xFFF5EBD9).withValues(alpha: 0.4),

          borderRadius: BorderRadius.circular(14),

          border: Border.all(
            color: const Color(0xFFA77A5C),
            width: 2,
          ),
        ),

        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [

            /// Icon smaller
            Icon(
              icon,
              size: 18,
            ),

            const SizedBox(width: 4),

            /// Text smaller
            Text(
              category,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// Item Card
  Widget itemBox(Map item) {
    return Container(
      padding:
      const EdgeInsets.all(8),

      decoration: BoxDecoration(
        color: const Color(0xFFF4F1EA),
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD8C3A5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset:
            const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        children: [
          Expanded(
            child: Image.network(
              item['imagePath'],
            ),
          ),

          Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.monetization_on,
                size: 16,
              ),
              Text(
                  "${item['price']}"),
            ],
          ),
        ],
      ),
    );
  }
}
