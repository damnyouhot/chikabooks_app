import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/enthrone.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import 'billboard_card.dart';

/// 전광판 자동 순환 위젯 (가장 단순한 방식)
/// 
/// 여러 개의 추대된 게시물을 3초마다 자동으로 순환하여 표시합니다.
class BillboardCarousel extends StatefulWidget {
  const BillboardCarousel({super.key});

  @override
  State<BillboardCarousel> createState() => _BillboardCarouselState();
}

class _BillboardCarouselState extends State<BillboardCarousel> {
  Timer? _timer;
  int _currentIndex = 0;
  Stream<QuerySnapshot>? _stream;

  @override
  void initState() {
    super.initState();
    // 스트림을 1회만 생성 - build()에서 만들면 탭 전환 시마다 새 스트림 → 로딩 반복
    final cutoff = DateTime.now().subtract(const Duration(hours: 12));
    _stream = FirebaseFirestore.instance
        .collection('billboardPosts')
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('expiresAt')
        .limit(10)
        .snapshots();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snap) {
        // 에러 표시
        if (snap.hasError) {
          if (kDebugMode) {
            print('🔴 Billboard error: ${snap.error}');
          }
          return Container(
            height: 200,
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Billboard error: ${snap.error}',
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // 개발 모드 상태 로깅
        if (kDebugMode) {
          print('🔍 Billboard state=${snap.connectionState}, hasData=${snap.hasData}, docs=${snap.data?.docs.length ?? 0}');
        }

        // 로딩 중
        if (!snap.hasData) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (kDebugMode) ...[
                    const SizedBox(height: 12),
                    Text(
                      'state=${snap.connectionState}\nhasData=${snap.hasData}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textDisabled),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        // 데이터 변환
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          _timer?.cancel();
          return _buildEmptyState();
        }

        // isActive = status == confirmed && !isExpired (클라이언트 필터)
        final posts = docs
            .map((doc) => BillboardPost.fromDoc(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ))
            .where((post) => post.isActive)
            .take(5)
            .toList();

        // 인덱스 범위 체크
        if (_currentIndex >= posts.length) {
          _currentIndex = 0;
        }

        // 타이머 시작 (2개 이상일 때만)
        if (posts.length > 1 && _timer == null) {
          _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
            if (mounted) {
              setState(() {
                _currentIndex = (_currentIndex + 1) % posts.length;
              });
            }
          });
        }

        // 1개만 있으면 타이머 중지
        if (posts.length == 1) {
          _timer?.cancel();
          _timer = null;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 카드 표시
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeIn,
              switchOutCurve: Curves.easeOut,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: Container(
                key: ValueKey(posts[_currentIndex].id),
                child: BillboardCard(post: posts[_currentIndex]),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 인디케이터 (2개 이상일 때만)
            if (posts.length > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(posts.length, (index) {
                  final isActive = _currentIndex == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.textSecondary.withOpacity(0.6)
                          : AppColors.divider,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  );
                }),
              ),
          ],
        );
      },
    );
  }


  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.divider.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 32,
            color: AppColors.textDisabled.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            '아직 추대된 글이 없어요',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '좋은 글에 추대 버튼을 눌러보세요',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

