// lib/pages/growth/study/mydesk_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'epub_reader_page.dart'; // 수정: EpubReaderPage 경로 추가
import '../../../models/ebook.dart'; // 수정: Ebook 모델 경로 추가

class MyDeskTab extends StatelessWidget {
  const MyDeskTab({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final purchasesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('purchases');

    return StreamBuilder<QuerySnapshot>(
      stream: purchasesRef.snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.data!.docs.isEmpty) {
          return const Center(child: Text('구매한 책이 없습니다.'));
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: snap.data!.docs.map((doc) {
            final d = doc.data()! as Map<String, dynamic>;

            if (!(d.containsKey('title') &&
                d.containsKey('fileUrl') &&
                d.containsKey('coverUrl'))) {
              return const SizedBox.shrink();
            }

            // 모델을 사용하여 데이터를 더 안전하게 관리
            final ebook = Ebook.fromJson(d, id: doc.id);

            return Card(
              child: ListTile(
                leading: ebook.coverUrl.isEmpty
                    ? const Icon(Icons.menu_book, size: 48)
                    : Image.network(
                        ebook.coverUrl,
                        width: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.menu_book, size: 48),
                      ),
                title: Text(ebook.title),
                subtitle: LinearProgressIndicator(
                    value: (d['progress'] ?? 0).toDouble() / 100),
                trailing: ElevatedButton(
                  child: const Text('이어읽기'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EpubReaderPage(ebook: ebook),
                      ),
                    );
                  },
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
