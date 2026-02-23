import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/policy_update.dart';

/// 🏥 급여 변경 임박 카드 (3초 간격 자동 로테이션)
class SalaryUpdateCard extends StatefulWidget {
  final List<PolicyUpdate>? updates;
  final VoidCallback? onTap;

  const SalaryUpdateCard({super.key, this.updates, this.onTap});

  @override
  State<SalaryUpdateCard> createState() => _SalaryUpdateCardState();
}

class _SalaryUpdateCardState extends State<SalaryUpdateCard> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.updates != null && widget.updates!.length > 1) {
      _startAutoRotation();
    }
  }

  void _startAutoRotation() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && widget.updates != null && widget.updates!.isNotEmpty) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % widget.updates!.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final updates = widget.updates;

    // 로딩 상태
    if (updates == null) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('🏥', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 3),
                    Text(
                      '임박 제도 변경',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('로딩 중...', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    // 데이터 없음
    if (updates.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('🏥', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 3),
                    Text(
                      '임박 제도 변경',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('예정된 제도 변경 없음', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    final update = updates[_currentIndex];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 타이틀
              Row(
                children: [
                  Text('🏥', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 3),
                  Text(
                    '임박 제도 변경',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // 슬라이드 애니메이션 (위로 밀려나기)
              ClipRect(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (
                    Widget child,
                    Animation<double> animation,
                  ) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
                  child: Column(
                    key: ValueKey(_currentIndex),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목
                      Text(
                        update.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // 시행일 + D-day
                      Text(
                        '시행일: ${update.effectiveDate?.month ?? '?'}월 ${update.effectiveDate?.day ?? '?'}일 (${update.ddayString})',
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
