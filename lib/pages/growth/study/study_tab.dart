import 'package:badges/badges.dart' as badges; // 뱃지 패키지 import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'ebook_list_page.dart';
import 'mydesk_tab.dart';

class StudyTab extends StatelessWidget {
  const StudyTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: TabBar(
            tabs: [
              const Tab(text: '나의 서재'),
              // ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼ 쿠폰 갯수를 보여주는 뱃지 추가 ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('coupons')
                    .where('isUsed', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.docs.length ?? 0;
                  return badges.Badge(
                    showBadge: count > 0,
                    badgeContent: Text('$count',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10)),
                    child: const Tab(text: '전자책 스토어'),
                  );
                },
              ),
              // ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲ 쿠폰 갯수를 보여주는 뱃지 추가 ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MyDeskTab(),
            EbookListPage(),
          ],
        ),
      ),
    );
  }
}
