import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../models/ebook.dart';
import '../models/hira_update.dart';
import '../services/ebook_service.dart';
import '../services/hira_update_service.dart';
import '../widgets/hira_update_detail_sheet.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_tokens.dart';
import '../core/widgets/app_muted_card.dart';
import '../core/widgets/app_segmented_control.dart';
import 'ebook/ebook_list_page.dart';
import 'ebook/ebook_detail_page.dart';
import 'quiz_today_page.dart';
import 'hira_update_page.dart';
import 'settings/settings_page.dart';

/// 성장 탭 (3탭)
///
/// 내부 소탭 4개:
/// 1. 오늘의 퀴즈 — 매일 2문제
/// 2. 급여변경 — HIRA 수가/급여 변경 포인트
/// 3. 성장하기 3번 탭(라벨: 치과책방) — e-Book 스토어
/// 4. 내 서재 — 구매한 e-Book 목록
class GrowthPage extends StatefulWidget {
  final ValueNotifier<int>? subTabNotifier;
  /// 보험정보(HiraUpdatePage) 내부 소탭: 0=수가 조회, 1=제도 변경
  final ValueNotifier<int>? hiraTabRequestNotifier;

  const GrowthPage({super.key, this.subTabNotifier, this.hiraTabRequestNotifier});

  @override
  State<GrowthPage> createState() => _GrowthPageState();
}

class _GrowthPageState extends State<GrowthPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    widget.subTabNotifier?.addListener(_onSubTabChanged);
  }

  void _onSubTabChanged() {
    final idx = widget.subTabNotifier?.value ?? -1;
    if (idx >= 0 && idx < 4) {
      _tabCtrl.animateTo(idx);
    }
  }

  @override
  void dispose() {
    widget.subTabNotifier?.removeListener(_onSubTabChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // 세그먼트 탭바 → AppSegmentedControl
            AppSegmentedControl(
              controller: _tabCtrl,
              labels: const ['오늘 퀴즈', '보험정보', '치과책방', '내 서재'],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  const QuizTodayPage(),
                  HiraUpdatePage(tabRequestNotifier: widget.hiraTabRequestNotifier),
                  const EbookListPage(),
                  const _MyLibraryView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 타이틀 + 아이콘 (한 행으로 통합) ──
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xl, right: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '성장하기',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.info_outline,
                  color: AppColors.textDisabled,
                  size: 18,
                ),
                onPressed: () => _showConceptDialog(context),
              ),
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: AppColors.textDisabled,
                  size: 20,
                ),
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    ),
              ),
            ],
          ),
        ),
        // ── 서브타이틀 ──
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xl),
          child: Text(
            '오늘도 하나씩, 꾸준히 성장해요.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  void _showConceptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text(
              '성장하기 탭에 대해서',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('퀴즈, 보험정보, 책으로 치과 직무를 배우고 기록하는 공간이에요.', style: TextStyle(fontSize: 13, height: 1.5)),
                  SizedBox(height: 16),
                  Text('📝 오늘 퀴즈', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text(
                    '매일 국시·임상 문제를 풀어요. (스케줄에 따라 하루 2문항)',
                    style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
                  ),
                  SizedBox(height: 16),
                  Text('📋 보험정보', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('수가 조회와 HIRA 급여·수가 제도 변경 소식을 확인해요.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
                  SizedBox(height: 16),
                  Text('📖 하이진랩', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('하이진랩에 올라온 책들을 볼 수 있는 공간이에요.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
                  SizedBox(height: 16),
                  Text('📗 내 서재', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('연동 전자책 스토어에서 구매한 책들을 볼 수 있는 곳이에요.', style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('닫기'),
              ),
            ],
          ),
    );
  }
}

// ═══════════════════════════════════════════════════
// 내 서재 (구매한 e-Book + 저장한 HIRA 목록)
// ═══════════════════════════════════════════════════

class _MyLibraryView extends StatefulWidget {
  const _MyLibraryView();

  @override
  State<_MyLibraryView> createState() => _MyLibraryViewState();
}

class _MyLibraryViewState extends State<_MyLibraryView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 서브 탭바 → AppSegmentedControl
        AppSegmentedControl(
          controller: _tabCtrl,
          labels: const ['전자책', '저장한 변경사항'],
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: const [_MyBooksTab(), _SavedHiraTab()],
          ),
        ),
      ],
    );
  }
}

class _MyBooksTab extends StatefulWidget {
  const _MyBooksTab();

  @override
  State<_MyBooksTab> createState() => _MyBooksTabState();
}

class _MyBooksTabState extends State<_MyBooksTab> {
  bool _syncing = false;
  bool _loading = true;
  List<Ebook> _myBooks = [];

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadMyBooks();
      _checkAliasNotification();
    }
  }

  /// alias 이메일로 구매내역이 연결된 경우 1회 안내 다이얼로그 표시
  Future<void> _checkAliasNotification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final data = doc.data();
      if (data == null) return;

      // aliasNotified == false 이고 emailAliases 가 있을 때만 표시
      final notified = data['aliasNotified'] as bool? ?? true;
      if (notified) return;

      final aliases = List<String>.from(data['emailAliases'] as List? ?? []);
      if (aliases.isEmpty) return;

      // 안내 후 즉시 true 로 업데이트 (중복 표시 방지)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'aliasNotified': true},
      );

      if (!mounted) return;

      // 안내 다이얼로그 표시
      final aliasEmail = aliases.first;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                '구매 이메일 안내',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              content: Text(
                "연동 스토어에서 '$aliasEmail' 이메일로\n구매된 기록이 확인되었습니다.\n\n"
                '구매 내역은 정상적으로 연결되어 있습니다.\n'
                '앞으로는 현재 로그인한 이메일로 이용해 주세요.',
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('확인'),
                ),
              ],
            ),
      );
    } catch (e) {
      debugPrint('⚠️ alias 알림 확인 오류: $e');
    }
  }

  Future<void> _loadMyBooks() async {
    try {
      final service = context.read<EbookService>();
      final purchasedIds = await service.fetchPurchasedEbookIds();
      if (purchasedIds.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final allBooks = await service.fetchAllEbooks();
      final myBooks =
          allBooks.where((b) => purchasedIds.contains(b.id)).toList();
      if (mounted) {
        setState(() {
          _myBooks = myBooks;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ _MyBooksTab._loadMyBooks error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 아임웹 구매내역 수동 동기화
  Future<void> _syncPurchases() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    String? warning;
    final email =
        FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();
    if (email?.isNotEmpty == true) {
      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('imweb_sync_issues')
                .doc(email!)
                .get();
        if (doc.exists) {
          warning = doc.data()?['message'] as String?;
        }
      } catch (e) {
        debugPrint('⚠️ imweb_sync_issues 조회 실패: $e');
      }
    }

    if (warning != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warning),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    try {
      final service = context.read<EbookService>();
      final result = await service.syncImwebPurchases();
      final synced = result['synced'] as int? ?? 0;
      final message = result['message'] as String? ?? '동기화 완료';

      if (!mounted) return;

      if (synced > 0) {
        // 새 구매내역 발견 → 스낵바
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $message'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // 내역 없음 → 이메일 확인 안내 다이얼로그
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  '구매내역을 찾지 못했습니다',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                content: const Text(
                  '구매 시 사용한 이메일 주소로\n로그인하셨나요?\n\n'
                  '구매 시 사용한 이메일 계정으로\n로그인하면 자동으로 연결됩니다.',
                  style: TextStyle(fontSize: 14, height: 1.55),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('확인'),
                  ),
                ],
              ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('동기화 실패: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
        _loadMyBooks(); // 동기화 후 목록 새로고침
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── 동기화 버튼 배너 ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            0,
          ),
          child: InkWell(
            onTap: _syncing ? null : _syncPurchases,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.textDisabled.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.sync_rounded, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '전자책 구매내역이 보이지 않나요?',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (_syncing)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      '동기화',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // ── 구매 도서 목록 ──────────────────────────────
        Expanded(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _myBooks.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.menu_book_outlined,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '구매한 도서가 없습니다.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '치과책방 홈페이지에서 구매가 가능합니다',
                          style: TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: _loadMyBooks,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      itemCount: _myBooks.length,
                      separatorBuilder:
                          (_, __) => const SizedBox(height: AppSpacing.md),
                      itemBuilder:
                          (context, i) => _MyBookTile(book: _myBooks[i]),
                    ),
                  ),
        ),
      ],
    );
  }
}

class _SavedHiraTab extends StatelessWidget {
  const _SavedHiraTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HiraUpdate>>(
      stream: HiraUpdateService.watchSavedUpdates(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final savedUpdates = snapshot.data ?? [];
        if (savedUpdates.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.bookmark_border,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '저장한 변경사항이 없습니다',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '보험정보 탭에서 항목을 저장하세요.',
                  style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.xl),
          itemCount: savedUpdates.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) => _SavedHiraTile(update: savedUpdates[i]),
        );
      },
    );
  }
}

// ── 저장한 HIRA 타일 ──────────────────────────────────────────

class _SavedHiraTile extends StatelessWidget {
  final HiraUpdate update;
  const _SavedHiraTile({required this.update});

  @override
  Widget build(BuildContext context) {
    return AppMutedCard(
      padding: const EdgeInsets.all(AppSpacing.lg - 2),
      onTap:
          () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => HiraUpdateDetailSheet(update: update),
          ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  update.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${update.publishedAt.year}.'
                  '${update.publishedAt.month.toString().padLeft(2, '0')}.'
                  '${update.publishedAt.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textDisabled,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textDisabled,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ── 내 e-Book 타일 ───────────────────────────────────────────

class _MyBookTile extends StatelessWidget {
  final Ebook book;
  const _MyBookTile({required this.book});

  @override
  Widget build(BuildContext context) {
    return AppMutedCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EbookDetailPage(ebook: book)),
          ),
      child: Row(
        children: [
          // 커버: 화면 너비 13%, 최소44·최대68, 비율 3:4
          LayoutBuilder(
            builder: (ctx, constraints) {
              final screenW = MediaQuery.of(ctx).size.width;
              final coverW = (screenW * 0.13).clamp(44.0, 68.0);
              final coverH = coverW * (4 / 3);
              return ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                child: Image.network(
                  book.coverUrl,
                  width: coverW,
                  height: coverH,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => Container(
                        width: coverW,
                        height: coverH,
                        color: AppColors.disabledBg,
                        child: const Icon(
                          Icons.book,
                          color: AppColors.textDisabled,
                        ),
                      ),
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.lg - 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  book.author,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textDisabled,
            size: 20,
          ),
        ],
      ),
    );
  }
}
