import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home/home_shell.dart';
import 'sign_in_page.dart';

/// 인증 상태 확인 게이트
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    if (user == null) return const SignInPage();

    // 유저 문서 존재 여부만 확인 (Character 초기화 제거)
    return const HomeShell();
  }
}





