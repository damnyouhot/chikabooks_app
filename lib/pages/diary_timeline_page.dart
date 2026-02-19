import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// 나의 기록 타임라인 페이지
/// 
/// 과거에 작성한 "오늘, 지금" 기록들을 시간 순으로 보여줌
class DiaryTimelinePage extends StatelessWidget {
  const DiaryTimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('나의 기록'),
          backgroundColor: const Color(0xFFF1F7F7),
          foregroundColor: const Color(0xFF5D6B6B),
          elevation: 0,
        ),
        body: const Center(
          child: Text('로그인이 필요합니다'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F7F7),
      appBar: AppBar(
        title: const Text(
          '나의 기록',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFFF1F7F7),
        foregroundColor: const Color(0xFF5D6B6B),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('오류가 발생했습니다: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF7BA5A5),
              ),
            );
          }

          final notes = snapshot.data?.docs ?? [];

          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_note_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '아직 기록이 없어요',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '오늘의 마음을 기록해보세요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              final data = note.data() as Map<String, dynamic>;
              final text = data['text'] as String;
              final createdAt = data['createdAt'] as Timestamp?;

              return _NoteCard(
                noteId: note.id,
                text: text,
                createdAt: createdAt,
                uid: uid,
              );
            },
          );
        },
      ),
    );
  }
}

/// 개별 기록 카드
class _NoteCard extends StatelessWidget {
  final String noteId;
  final String text;
  final Timestamp? createdAt;
  final String uid;

  const _NoteCard({
    required this.noteId,
    required this.text,
    required this.createdAt,
    required this.uid,
  });

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '날짜 없음';
    
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    
    // 요일 배열
    final weekday = ['월', '화', '수', '목', '금', '토', '일'][date.weekday - 1];

    if (diff.inDays == 0) {
      // 오늘
      return '오늘 ${DateFormat('HH시 mm분').format(date)}';
    } else if (diff.inDays == 1) {
      // 어제
      return '어제 ${DateFormat('HH시 mm분').format(date)}';
    } else {
      // 과거 (어제보다 이전)
      final isThisYear = date.year == now.year;
      
      if (isThisYear) {
        // 올해: 연도 제외
        return '${date.month}월 ${date.day}일, $weekday요일 ${DateFormat('HH시 mm분').format(date)}';
      } else {
        // 지난 해 이상: 연도 포함 (YY년 형식)
        final yearShort = date.year % 100; // 2025 → 25
        return '${yearShort}년 ${date.month}월 ${date.day}일, $weekday요일 ${DateFormat('HH시 mm분').format(date)}';
      }
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('notes')
                    .doc(noteId)
                    .delete();
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('기록이 삭제되었습니다')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('삭제 실패: $e')),
                  );
                }
              }
            },
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD5E5E5).withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜/시간
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(),
              // 삭제 버튼
              GestureDetector(
                onTap: () => _showDeleteDialog(context),
                child: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 기록 내용
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF5D6B6B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}







