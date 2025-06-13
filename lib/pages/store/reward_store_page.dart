// lib/pages/store/reward_store_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/store_item.dart';
import '../../services/store_service.dart';

class RewardStorePage extends StatefulWidget {
  const RewardStorePage({super.key});

  @override
  State<RewardStorePage> createState() => _RewardStorePageState();
}

class _RewardStorePageState extends State<RewardStorePage> {
  // ▼▼▼ 변경될 일이 없는 변수이므로 final로 선언 ▼▼▼
  final Set<String> _isPurchasing = {};

  @override
  Widget build(BuildContext context) {
    final storeService = Provider.of<StoreService>(context, listen: false);

    return FutureBuilder<List<StoreItem>>(
      future: storeService.fetchStoreItems(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('판매중인 아이템이 없습니다.'));
        }

        final items = snapshot.data!;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final purchasing = _isPurchasing.contains(item.id);

            return Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) => const Icon(
                            Icons.redeem,
                            size: 48,
                            color: Colors.grey,
                          ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('${item.price} 포인트'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed:
                          purchasing
                              ? null
                              : () async {
                                setState(() => _isPurchasing.add(item.id));
                                final result = await storeService.purchaseItem(
                                  item,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(result)),
                                  );
                                }
                                setState(() => _isPurchasing.remove(item.id));
                              },
                      child:
                          purchasing
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('구매하기'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
