// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../models/character.dart';
import '../services/character_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
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
                Text('안녕하세요, ${ch.name ?? '유저'}님'),
                const SizedBox(height: 8),
                Text('호감도: ${ch.affection ?? 0}'),
                const SizedBox(height: 8),
                Text('레벨: ${ch.level?.toStringAsFixed(1) ?? '1.0'}'),
                const SizedBox(height: 24),
                ElevatedButton(
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
