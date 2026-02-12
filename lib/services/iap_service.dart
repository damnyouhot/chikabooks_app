// lib/services/iap_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// IAP (인앱 결제) 서비스
/// 
/// 사용 방법:
/// 1. 앱 시작 시 IapService.instance.initialize() 호출
/// 2. 구매: await IapService.instance.buyProduct(productId)
/// 3. 구매 확인: IapService.instance.isPurchased(productId)
class IapService extends ChangeNotifier {
  static final IapService _instance = IapService._();
  static IapService get instance => _instance;
  IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isAvailable = false;
  bool _isInitialized = false;
  
  List<ProductDetails> _products = [];
  final Set<String> _purchasedIds = {};
  
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Getters
  bool get isAvailable => _isAvailable;
  bool get isInitialized => _isInitialized;
  List<ProductDetails> get products => _products;

  /// IAP 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      debugPrint('IAP: 사용 불가능');
      _isInitialized = true;
      return;
    }

    // 구매 스트림 리스닝
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (error) => debugPrint('IAP Error: $error'),
    );

    // 기존 구매 목록 로드 (Firestore에서)
    await _loadPurchasedProducts();

    _isInitialized = true;
    debugPrint('IAP: 초기화 완료');
  }

  /// 상품 목록 로드
  Future<void> loadProducts(Set<String> productIds) async {
    if (!_isAvailable || productIds.isEmpty) return;

    final response = await _iap.queryProductDetails(productIds);
    
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('IAP: 찾을 수 없는 상품: ${response.notFoundIDs}');
    }

    _products = response.productDetails;
    notifyListeners();
    
    debugPrint('IAP: ${_products.length}개 상품 로드됨');
  }

  /// 상품 구매
  Future<bool> buyProduct(String productId) async {
    if (!_isAvailable) {
      debugPrint('IAP: 사용 불가능');
      return false;
    }

    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('상품을 찾을 수 없습니다: $productId'),
    );

    final purchaseParam = PurchaseParam(productDetails: product);
    
    try {
      // 비소모성 상품 (전자책)으로 구매
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      return success;
    } catch (e) {
      debugPrint('IAP 구매 오류: $e');
      return false;
    }
  }

  /// 구매 여부 확인
  bool isPurchased(String productId) {
    return _purchasedIds.contains(productId);
  }

  /// 구매 업데이트 처리
  void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      debugPrint('IAP 구매 상태: ${purchase.productID} - ${purchase.status}');
      
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // 결제 진행 중
          break;
          
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // 결제 완료 또는 복원
          _handleSuccessfulPurchase(purchase);
          break;
          
        case PurchaseStatus.error:
          debugPrint('IAP 오류: ${purchase.error}');
          break;
          
        case PurchaseStatus.canceled:
          debugPrint('IAP 취소됨');
          break;
      }

      // 구매 완료 처리 (필수!)
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  /// 구매 성공 처리
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    final productId = purchase.productID;
    
    // 로컬 상태 업데이트
    _purchasedIds.add(productId);
    notifyListeners();

    // Firestore에 구매 기록 저장
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _db
          .collection('users')
          .doc(uid)
          .collection('purchases')
          .doc(productId)
          .set({
        'productId': productId,
        'purchaseDate': FieldValue.serverTimestamp(),
        'transactionId': purchase.purchaseID,
        'status': 'completed',
      });
    }

    debugPrint('IAP: 구매 완료 - $productId');
  }

  /// Firestore에서 구매 목록 로드
  Future<void> _loadPurchasedProducts() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('purchases')
          .get();

      for (final doc in snapshot.docs) {
        _purchasedIds.add(doc.id);
      }
      
      debugPrint('IAP: ${_purchasedIds.length}개 구매 기록 로드됨');
    } catch (e) {
      debugPrint('IAP 구매 기록 로드 오류: $e');
    }
  }

  /// 구매 복원 (iOS에서 필수)
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;
    await _iap.restorePurchases();
  }

  /// 리소스 해제
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}



























