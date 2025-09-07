// lib/pages/job_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../models/character.dart';
import '../services/character_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // [수정] context.watch<User?>() 대신 FirebaseAuth.instance.currentUser 사용
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다')));
    }

    return StreamBuilder<Character>(
      stream: CharacterService.watchCharacter(user.uid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final ch = snap.data!;

        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // [수정] Character 모델에 name이 없으므로, 임시로 ID를 표시하거나 주석 처리합니다.
                // Text('안녕하세요, ${ch.name ?? '유저'}님'),
                Text('캐릭터 ID: ${ch.id}'),
                const SizedBox(height: 8),
                Text('호감도: ${ch.affection}'),
                const SizedBox(height: 8),
                // [수정] level이 null일 수 있으므로 안전하게 처리
                Text('레벨: ${ch.level?.toStringAsFixed(1) ?? '1.0'}'),
                const SizedBox(height: 24),
                ElevatedButton(
                  // [수정] feedCharacter는 인자가 없으므로 () 사용
                  onPressed: () async => await CharacterService.feedCharacter(),
                  child: const Text('간식 주기 (+호감/경험치)'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
