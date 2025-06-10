// lib/models/store_item.dart (전체 코드)
import 'package:cloud_firestore/cloud_firestore.dart';

enum StoreItemType { cosmetic, coupon }

class StoreItem {
  final String id;
  final String name;
  final String description;
  final int price;
  final String imageUrl;
  final StoreItemType type;
  final double? value; // 쿠폰일 경우 할인율/할인액

  StoreItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.type = StoreItemType.cosmetic,
    this.value,
  });

  factory StoreItem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoreItem(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: data['price'] ?? 9999,
      imageUrl: data['imageUrl'] ?? '',
      type: StoreItemType.values.byName(data['type'] ?? 'cosmetic'),
      value: (data['value'] ?? 0).toDouble(),
    );
  }
}
