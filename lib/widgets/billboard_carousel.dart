import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/enthrone.dart';
import 'billboard_card.dart';

// ignore_for_file: avoid_print

// ── 디자인 팔레트 ──
const _kText = Color(0xFF5D6B6B);
const _kShadow2 = Color(0xFFD5E5E5);
const _kCardBg = Colors.white;

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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 만료 기준: 12시간 전 (expiresAt = 생성+12h이므로 24h 안쪽 게시물만 포함)
    // 복합 인덱스 없이 동작하도록 expiresAt 단일 필터만 Firestore에서 처리.
    // status/isExpired 는 클라이언트에서 isActive 체크로 필터링.
    final cutoff = DateTime.now().subtract(const Duration(hours: 12));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('billboardPosts')
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(cutoff))
          .orderBy('expiresAt')
          .limit(10) // 클라이언트 필터 여분 고려해 여유 있게 가져옴
          .snapshots(),
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
                  const Icon(Icons.error_outline, color: Colors.red, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Billboard error: ${snap.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
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
                      style: TextStyle(fontSize: 10, color: _kText.withOpacity(0.5)),
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
                          ? _kText.withOpacity(0.6)
                          : _kShadow2,
                      borderRadius: BorderRadius.circular(4),
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
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _kShadow2.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 32,
            color: _kText.withOpacity(0.3),
          ),
          const SizedBox(height: 8),
          Text(
            '아직 추대된 글이 없어요',
            style: TextStyle(
              fontSize: 13,
              color: _kText.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '좋은 글에 추대 버튼을 눌러보세요',
            style: TextStyle(
              fontSize: 11,
              color: _kText.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

