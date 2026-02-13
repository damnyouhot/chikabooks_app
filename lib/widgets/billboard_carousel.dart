import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/enthrone.dart';
import 'billboard_card.dart';

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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('billboardPosts')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snap) {
        // 로딩 중
        if (!snap.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // 에러
        if (snap.hasError) {
          return _buildEmptyState();
        }

        // 데이터 변환
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          _timer?.cancel();
          return _buildEmptyState();
        }

        final posts = docs
            .map((doc) => BillboardPost.fromDoc(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ))
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

