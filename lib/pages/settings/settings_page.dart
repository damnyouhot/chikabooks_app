import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'partner_preferences_page.dart';
import '../onboarding/onboarding_profile_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  PackageInfo? _pkg;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _pkg = info);
  }

  User? get _user => _auth.currentUser;

  /// ✅ Firestore에서 사용자 프로필 읽기
  Future<Map<String, dynamic>?> _loadUserProfile() async {
    final user = _user;
    if (user == null) return null;

    try {
      final snap = await _firestore.collection('users').doc(user.uid).get();
      return snap.data();
    } catch (e) {
      debugPrint('⚠️ 사용자 프로필 로드 실패: $e');
      return null;
    }
  }

  /// ✅ Provider 라벨 (Firestore 기반)
  String _providerLabelFromFirestore(Map<String, dynamic>? data) {
    if (data == null) return '알 수 없음';
    
    final provider = data['provider'] as String?;
    
    return switch (provider) {
      'kakao' => '카카오',
      'naver' => '네이버',
      'apple' => 'Apple',
      'google' => 'Google',
      'password' => '이메일',
      _ => provider != null ? '기타($provider)' : '알 수 없음',
    };
  }

  /// ⚠️ 백업: providerData 기반 (Firestore 실패 시)
  String _providerLabelFromAuth(User user) {
    final providers = user.providerData.map((e) => e.providerId).toSet();

    if (providers.contains('password')) return '이메일';
    if (providers.contains('google.com')) return 'Google';
    if (providers.contains('apple.com')) return 'Apple';

    // UID 기반 추측
    if (user.uid.startsWith('kakao_')) return '카카오';
    if (user.uid.startsWith('naver_')) return '네이버';
    if (user.uid.startsWith('apple_')) return 'Apple';

    if (providers.isNotEmpty) {
      final first = providers.first;
      if (first.contains('kakao')) return '카카오';
      if (first.contains('naver')) return '네이버';
      return '기타($first)';
    }
    return '알 수 없음';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크를 열 수 없어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('메일 앱을 열 수 없어요.')),
      );
    }
  }

  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        content: const Text('로그아웃하면 다시 로그인해야 내 서재와 구매한 책을 볼 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (result == true) {
      // Firebase Auth + Google Sign-In 로그아웃
      await GoogleSignIn().signOut();
      await _auth.signOut();
      
      if (!mounted) return;
      
      // 설정 페이지 닫기 (AuthGate로 돌아가서 자동으로 로그인 페이지로 이동)
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃 되었어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    // 🧩 디버그: 현재 로그인 상태 확인
    debugPrint('🧩 SETTINGS currentUser = ${user?.uid}');
    debugPrint('🧩 SETTINGS email = ${user?.email}');
    debugPrint('🧩 SETTINGS providerData = ${user?.providerData.map((e) => e.providerId).toList()}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // 1) 계정
          const _SectionTitle(title: '계정'),
          if (user == null)
            const _InfoTile(
              icon: Icons.person_outline,
              title: '로그인 정보가 없어요',
              subtitle: '로그인이 필요합니다.',
            )
          else
            // ✅ FutureBuilder로 Firestore 프로필 읽기
            FutureBuilder<Map<String, dynamic>?>(
              future: _loadUserProfile(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  );
                }

                final data = snapshot.data;
                final provider = _providerLabelFromFirestore(data);
                
                // 백업: Firestore에 없으면 providerData/UID 기반으로 추측
                final displayProvider = (data == null || data['provider'] == null)
                    ? _providerLabelFromAuth(user)
                    : provider;

                return _AccountCard(
                  email: user.email ?? data?['email'] as String? ?? '이메일 정보 없음',
                  displayName: data?['nickname'] as String? ??  // ✅ nickname 필드 우선
                      user.displayName ?? 
                      data?['displayName'] as String? ?? 
                      '닉네임 없음',
                  provider: displayProvider,
                  uid: user.uid,
                );
              },
            ),

          const SizedBox(height: 12),

          // ━━━━━ 파트너와 나 섹션 추가 ━━━━━
          const _SectionTitle(title: '파트너와 나'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('내 캐릭터 설정'),
            subtitle: const Text('닉네임, 연차, 지역군, 관심사 설정'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OnboardingProfileScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('파트너 선정 기준'),
            subtitle: const Text('매칭 우선순위 설정'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PartnerPreferencesPage(),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // 2) 고객센터 & 법적 정보
          const _SectionTitle(title: '고객센터 · 약관'),
          ListTile(
            leading: const Icon(Icons.support_agent_outlined),
            title: const Text('문의하기'),
            subtitle: const Text('메일로 문의를 보낼 수 있어요'),
            onTap: () {
              final uid = user?.uid ?? 'unknown';
              final email = user?.email ?? 'unknown';
              final platform = Platform.isIOS ? 'iOS' : (Platform.isAndroid ? 'Android' : 'Unknown');
              final version = _pkg == null ? 'unknown' : '${_pkg!.version} (${_pkg!.buildNumber})';

              _sendEmail(
                to: 'doughong@naver.com',
                subject: '[치카북스 문의] ',
                body: '''
안녕하세요. 치카북스 문의드립니다.

- UID: $uid
- 이메일: $email
- 플랫폼: $platform
- 앱 버전: $version

[문의 내용]
''',
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('이용약관'),
            onTap: () {
              // TODO: 실제 약관 URL로 변경 필요
              _openUrl('https://www.chikabooks.com/terms');
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('개인정보처리방침'),
            onTap: () {
              // TODO: 실제 개인정보처리방침 URL로 변경 필요
              _openUrl('https://www.chikabooks.com/privacy');
            },
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('오픈소스 라이선스'),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: _pkg?.appName ?? '치카북스',
                applicationVersion: _pkg == null ? null : '${_pkg!.version} (${_pkg!.buildNumber})',
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('앱 버전'),
            subtitle: Text(
              _pkg == null ? '불러오는 중…' : '${_pkg!.version} (${_pkg!.buildNumber})',
            ),
          ),

          const SizedBox(height: 12),

          // 3) 로그아웃
          const _SectionTitle(title: '로그인'),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            textColor: Theme.of(context).colorScheme.error,
            iconColor: Theme.of(context).colorScheme.error,
            onTap: user == null ? null : _confirmLogout,
          ),

          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '약관 및 개인정보처리방침 링크는 실제 운영 URL로 교체해야 심사에서 안전합니다.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final String displayName;
  final String email;
  final String provider;
  final String uid;

  const _AccountCard({
    required this.displayName,
    required this.email,
    required this.provider,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                child: Icon(Icons.person),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Chip(text: '로그인: $provider'),
                        _Chip(text: 'UID: ${uid.substring(0, uid.length >= 8 ? 8 : uid.length)}…'),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

