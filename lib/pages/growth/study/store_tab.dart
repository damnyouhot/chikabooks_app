// lib/pages/growth/study/store_tab.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../models/ebook.dart';
import '../../../services/ebook_service.dart';

class StoreTab extends StatefulWidget {
  const StoreTab({super.key});
  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab> {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final iap = InAppPurchase.instance;

  List<ProductDetails> _products = [];
  bool _iapReady = false;
  late Stream<List<Ebook>> _booksStream;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  @override
  void initState() {
    super.initState();
    _booksStream = context.read<EbookService>().watchEbooks();
    _listenPurchases();
    _loadIAP();
  }

  void _listenPurchases() {
    _purchaseSub = iap.purchaseStream.listen((purchases) async {
      for (final p in purchases) {
        if (p.status == PurchaseStatus.purchased) {
          await _grantBookByProductId(p.productID);
        }
      }
    });
  }

  Future<void> _loadIAP() async {
    try {
      final books = await _booksStream.first;
      final ids =
          books.where((e) => e.price > 0).map((e) => e.productId).toSet();
      if (ids.isEmpty) {
        return;
      }

      final resp = await iap.queryProductDetails(ids);
      if (mounted) {
        setState(() {
          _products = resp.productDetails;
          _iapReady = true;
        });
      }
    } catch (e) {
      debugPrint('[StoreTab] IAP load error: $e');
    }
  }

  Future<void> _buy(Ebook book) async {
    if (book.price == 0) {
      await _grantBook(book);
      return;
    }
    if (!_iapReady) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('상품 정보를 불러오는 중입니다.')));
      }
      return;
    }

    final product = _products.firstWhere(
      (p) => p.id == book.productId,
      orElse:
          () => ProductDetails(
            id: '',
            title: '',
            description: '',
            price: '',
            rawPrice: 0,
            currencyCode: 'KRW',
          ),
    );
    if (product.id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('인앱 상품을 찾을 수 없습니다.')));
      }
      return;
    }

    final param = PurchaseParam(productDetails: product);
    iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> _grantBookByProductId(String productId) async {
    final ebooks = await _booksStream.first;
    // orElse에서 Ebook.empty()를 호출합니다.
    final book = ebooks.firstWhere(
      (e) => e.productId == productId,
      orElse: () => Ebook.empty(),
    );
    if (book.title.isNotEmpty) {
      await _grantBook(book);
    }
  }

  Future<void> _grantBook(Ebook book) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('purchases')
        .doc(book.id)
        .set({
          'progress': 0,
          'lastOpened': null,
          'title': book.title,
          'author': book.author,
          'coverUrl': book.coverUrl,
          'fileUrl': book.fileUrl,
        }, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('도서가 라이브러리에 추가되었습니다!')));
    }
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ebook>>(
      stream: _booksStream,
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final books = snap.data!;
        if (books.isEmpty) {
          return const Center(child: Text('등록된 책이 없습니다.'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: books.length,
          itemBuilder: (_, i) {
            final b = books[i];
            return Card(
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child:
                        b.coverUrl.isEmpty
                            ? const Icon(Icons.menu_book, size: 48)
                            : Image.network(
                              b.coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) =>
                                      const Icon(Icons.menu_book, size: 48),
                            ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(
                      b.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    b.price == 0 ? '무료' : '${b.price}원',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ElevatedButton(
                      onPressed: () => _buy(b),
                      child: Text(b.price == 0 ? '받기' : '구매'),
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
