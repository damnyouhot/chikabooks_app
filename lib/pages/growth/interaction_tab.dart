// lib/pages/growth/interaction_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chikabooks_app/services/growth_service.dart';

class InteractionTab extends StatefulWidget {
  const InteractionTab({super.key});

  @override
  _InteractionTabState createState() => _InteractionTabState();
}

class _InteractionTabState extends State<InteractionTab> {
  final _controller = TextEditingController();
  bool _isAnonymous = false;
  final uid = FirebaseAuth.instance.currentUser!.uid;

  void _postMessage() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    await FirebaseFirestore.instance.collection('interactions').add({
      'userId': uid,
      'content': content,
      'likes': 0,
      'cheers': 0,
      'isAnonymous': _isAnonymous,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await GrowthService.recordEvent(
      uid: uid,
      type: 'interaction',
      value: 1.0,
    );

    _controller.clear();
  }

  void _addStamp() async {
    await FirebaseFirestore.instance.collection('stamps').add({
      'userId': uid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await GrowthService.recordEvent(
      uid: uid,
      type: 'stamp',
      value: 1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 익명 체크 & 입력
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Checkbox(
                value: _isAnonymous,
                onChanged: (v) => setState(() => _isAnonymous = v ?? false),
              ),
              const Text('익명으로(마니또)'),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(hintText: '응원의 글을 남겨보세요'),
                ),
              ),
              IconButton(icon: const Icon(Icons.send), onPressed: _postMessage),
            ],
          ),
        ),

        // 방문 도장 찍기 버튼 (Icon 교체)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            onPressed: _addStamp,
            icon: const Icon(Icons.emoji_events),
            label: const Text('방문 도장 찍기'),
          ),
        ),

        const Divider(),

        // 메시지 리스트
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('interactions')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                children: snap.data!.docs.map((doc) {
                  final d = doc.data()! as Map<String, dynamic>;
                  final author = d['isAnonymous'] == true ? '익명' : d['userId'];
                  return ListTile(
                    title: Text(d['content']),
                    subtitle: Text(
                        '$author • 좋아요 ${d['likes']}  • 힘내요 ${d['cheers']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.thumb_up),
                            onPressed: () {
                              doc.reference
                                  .update({'likes': FieldValue.increment(1)});
                            }),
                        IconButton(
                            icon: const Icon(Icons.outlined_flag),
                            onPressed: () {
                              doc.reference
                                  .update({'cheers': FieldValue.increment(1)});
                            }),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}
