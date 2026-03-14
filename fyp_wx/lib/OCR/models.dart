class ParsedReceipt {
  final List<String> items;
  final String amount;
  final String? date;
  final String? categoryId;
  final String categoryName;

  ParsedReceipt({
    required this.items,
    required this.amount,
    this.date,
    this.categoryId,
    required this.categoryName,
  });
}


