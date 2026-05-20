import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:extended_text_library/extended_text_library.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_confirm_modal.dart';
import '../../core/widgets/app_muted_card.dart';
import '../../features/senior_qna/widgets/senior_sticker_widgets.dart';
import '../../services/admin_activity_service.dart';
import '../../services/diary_image_service.dart';
import '../diary_input_sheet.dart';
import '../user_goal_sheet.dart';

/// 스티커 인라인 토큰 — 텍스트 안에 `[[s:stickerId]]` 형태로 끼워 저장하고
/// 렌더링 시 [SeniorStickerView] 로 치환한다. 형식이 단순하고 사람이 읽어도
/// 의미를 짐작할 수 있어 마이그레이션·디버깅에 안전.
final RegExp _kStickerToken = RegExp(r'\[\[s:([A-Za-z0-9_\-]+)\]\]');

/// ExtendedTextField 용 — 입력칸에서도 토큰 [[s:id]] 을 실시간으로
/// SeniorStickerView 인라인 위젯으로 치환해 보여준다. 백스페이스 한 번에
/// 토큰이 통째로 지워지는 「special text」 처리는 라이브러리가 알아서 해 줌.
const String _kStickerStartFlag = '[[s:';
const String _kStickerEndFlag = ']]';

class _StickerSpanBuilder extends SpecialTextSpanBuilder {
  _StickerSpanBuilder();

  @override
  SpecialText? createSpecialText(
    String flag, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
    int? index,
  }) {
    if (flag.isEmpty) return null;
    if (flag == _kStickerStartFlag) {
      return _StickerSpecialText(textStyle, onTap, start: index ?? 0);
    }
    return null;
  }
}

class _StickerSpecialText extends SpecialText {
  _StickerSpecialText(
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap, {
    required this.start,
  }) : super(_kStickerStartFlag, _kStickerEndFlag, textStyle, onTap: onTap);

  final int start;

  @override
  InlineSpan finishText() {
    final raw = toString();
    final id = raw.substring(
      _kStickerStartFlag.length,
      raw.length - _kStickerEndFlag.length,
    );
    return ExtendedWidgetSpan(
      actualText: raw,
      start: start,
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: SeniorStickerView(stickerId: id, size: 20),
      ),
      deleteAll: true,
    );
  }
}

/// 스티커 토큰을 [InlineSpan] 시퀀스로 변환.
List<InlineSpan> buildInlineStickerSpans(
  String text, {
  TextStyle? textStyle,
  double stickerSize = 22,
}) {
  final spans = <InlineSpan>[];
  int last = 0;
  for (final m in _kStickerToken.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start), style: textStyle));
    }
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: SeniorStickerView(stickerId: m.group(1)!, size: stickerSize),
        ),
      ),
    );
    last = m.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: textStyle));
  }
  return spans;
}

/// 「기록하기」 통합 풀스크린 페이지 (B안 — 기존 BottomSheet 에서 페이지로 승격)
///
/// - 1탭(나) 「기록하기」(앱 레드) 버튼을 누르면 이 페이지가 push 된다.
/// - 두 기능을 한 화면에 섞지 않고 **세그먼트로 명확히 분리**한다:
///   - 「오늘, 지금」: 트위터식 자기 글 피드 + 하단 고정 입력 바
///     (별도 「지난 기록」 진입이 필요 없음 — 화면 자체가 피드)
///   - 「목표」: 기존 [UserGoalContent] 그대로 임베드
///
/// 마지막으로 선택한 탭은 SharedPreferences 에 저장되어 다음 진입 시 복원된다.
/// 페이지가 닫힐 때 발생한 마지막 캐릭터 멘트를 [push] 결과로 반환한다.
class RecordHubSheet {
  /// SharedPreferences 키 — 마지막으로 본 탭 인덱스(0=오늘 한줄, 1=목표).
  static const String prefsLastTabKey = 'record_hub_last_tab';

  /// 페이지를 띄우고 마지막 캐릭터 멘트를 반환한다.
  static Future<String?> show(BuildContext context) async {
    int initialTab = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(prefsLastTabKey);
      if (stored == 0 || stored == 1) initialTab = stored!;
    } catch (_) {/* 기본 0 으로 진행 */}
    if (!context.mounted) return null;
    return await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _RecordHubPage(initialTab: initialTab),
        fullscreenDialog: true,
      ),
    );
  }
}

class _RecordHubPage extends StatefulWidget {
  const _RecordHubPage({required this.initialTab});

  final int initialTab;

  @override
  State<_RecordHubPage> createState() => _RecordHubPageState();
}

class _RecordHubPageState extends State<_RecordHubPage> {
  /// 0 = 오늘, 지금 / 1 = 목표
  late int _index = widget.initialTab;

  /// 페이지가 닫힐 때 캐릭터 말풍선으로 노출할 마지막 멘트.
  String? _pendingCharacterMent;

  void _selectTab(int index) {
    if (_index == index) return;
    setState(() => _index = index);
    AdminActivityService.log(
      index == 0
          ? ActivityEventType.tapRecordTabDiary
          : ActivityEventType.tapRecordTabGoal,
      page: 'record_hub',
    );
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setInt(RecordHubSheet.prefsLastTabKey, index))
        .catchError((_) => false);
  }

  void _bufferCharacterMent(String ment) {
    _pendingCharacterMent = ment;
  }

  @override
  Widget build(BuildContext context) {
    // PopScope 로 시스템 백/AppBar 백 누를 때 마지막 멘트를 결과로 실어 보낸다.
    return PopScope<String?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop<String?>(_pendingCharacterMent);
      },
      child: Scaffold(
        backgroundColor: AppColors.appBg,
        appBar: AppBar(
          backgroundColor: AppColors.appBg,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.lime,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '기록하기',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () =>
                Navigator.of(context).pop<String?>(_pendingCharacterMent),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 4),
              _buildSegments(),
              const SizedBox(height: 8),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: [
                    _DiaryFeedTab(onCharacterMent: _bufferCharacterMent),
                    UserGoalContent(
                      embedded: true,
                      onCharacterMent: _bufferCharacterMent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegments() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.xl,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            _SegmentTab(
              label: '오늘, 지금',
              icon: Icons.edit_outlined,
              selected: _index == 0,
              onTap: () => _selectTab(0),
            ),
            _SegmentTab(
              label: '목표',
              icon: Icons.flag_outlined,
              selected: _index == 1,
              onTap: () => _selectTab(1),
            ),
          ],
        ),
      ),
    );
  }
}

/// 피드 카드 순번 라벨 — 「기록 01」 형식(2자리 0 패딩).
String _recordOrderLabel(int orderNumber) =>
    '기록 ${orderNumber.toString().padLeft(2, '0')}';

// ═════════════════════════════════════════════════════════════════
// 다이어리 피드 탭 — 트위터식 자기 글 피드 + 하단 고정 입력 바
// ═════════════════════════════════════════════════════════════════
//
// 위쪽: 자기 글 최신순 (Firestore stream, 클라이언트 정렬 — 인덱스 의존 없음)
// 아래: 텍스트필드 + 사진(0~3장) + 전송 버튼이 키보드 위에 고정.
//
// (스티커 인라인 삽입은 다음 라운드에서 senior_qna 스티커 시스템과 연결.
//  지금은 기존 mood 단일 이모지 호환성 유지.)

class _DiaryFeedTab extends StatefulWidget {
  const _DiaryFeedTab({required this.onCharacterMent});

  final ValueChanged<String> onCharacterMent;

  @override
  State<_DiaryFeedTab> createState() => _DiaryFeedTabState();
}

class _DiaryFeedTabState extends State<_DiaryFeedTab> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final List<XFile> _selectedImages = [];
  bool _isSaving = false;

  /// 편집 중인 노트 ID. null 이면 신규 작성 모드.
  String? _editingNoteId;

  /// 편집 진입 시 기존에 저장돼 있던 이미지 URL 목록(읽기 전용).
  /// 사용자가 그대로 두면 유지되고, 「사진 비우기」 버튼으로 모두 제거 가능.
  List<String> _editingExistingUrls = const [];
  bool _editingClearImages = false;

  static const int _maxImages = 3;
  static const int _maxLen = 500;

  static const String _composerHint =
      '예: 바쁜 하루였지만, 한 가지는 잘 해냈다고 적어볼게요.';
  static const String _composerEditHint = '기록을 고쳐 보세요.';

  void _enterEdit({
    required String noteId,
    required String text,
    required List<String> imageUrls,
  }) {
    setState(() {
      _editingNoteId = noteId;
      _editingExistingUrls = imageUrls;
      _editingClearImages = false;
      _selectedImages.clear();
      _controller.text = text;
      _controller.selection = TextSelection.collapsed(offset: text.length);
    });
    _focus.requestFocus();
  }

  void _cancelEdit() {
    setState(() {
      _editingNoteId = null;
      _editingExistingUrls = const [];
      _editingClearImages = false;
      _selectedImages.clear();
      _controller.clear();
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _insertSticker() async {
    final pickedId = await showSeniorStickerPicker(context);
    if (!mounted || pickedId == null || pickedId.isEmpty) return;
    final token = '[[s:$pickedId]]';
    final sel = _controller.selection;
    final txt = _controller.text;
    // 커서 위치가 유효하지 않으면 끝에 붙인다.
    final start = (sel.start >= 0 && sel.start <= txt.length) ? sel.start : txt.length;
    final end = (sel.end >= 0 && sel.end <= txt.length) ? sel.end : txt.length;
    final next = txt.replaceRange(start, end, token);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    setState(() {});
    _focus.requestFocus();
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _selectedImages.length;
    if (remaining <= 0) return;
    final picked = await DiaryImageService.pickImages(remaining: remaining);
    if (!mounted || picked.isEmpty) return;
    setState(() => _selectedImages.addAll(picked));
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    final isEditing = _editingNoteId != null;
    final keepingExistingImages =
        isEditing && !_editingClearImages && _editingExistingUrls.isNotEmpty;
    if (text.isEmpty &&
        _selectedImages.isEmpty &&
        !keepingExistingImages) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('로그인 필요');

      if (isEditing) {
        // ── 수정 모드 ────────────────────────────────────────────
        // 기존 첨부 이미지 처리:
        // - 「비우기」 했으면 모두 삭제.
        // - 사용자가 새 이미지를 추가했으면 기존 것 모두 삭제 후 새로 업로드
        //   (mixed 케이스를 단순화. 부분 교체는 나중 라운드에서 고려).
        final noteId = _editingNoteId!;
        List<String> finalUrls = _editingExistingUrls;

        if (_editingClearImages || _selectedImages.isNotEmpty) {
          if (_editingExistingUrls.isNotEmpty) {
            await DiaryImageService.deleteAll(
              uid: uid,
              noteId: noteId,
              imageUrls: _editingExistingUrls,
            );
          }
          if (_selectedImages.isNotEmpty) {
            finalUrls = await DiaryImageService.uploadAll(
              uid: uid,
              noteId: noteId,
              files: _selectedImages,
            );
          } else {
            finalUrls = const [];
          }
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notes')
            .doc(noteId)
            .update({
          'text': text,
          'imageUrls': finalUrls,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        AdminActivityService.log(
          ActivityEventType.noteEdit,
          page: 'record_hub',
          targetId: noteId,
          extra: {
            'imageCount': finalUrls.length,
            'textLength': text.length,
          },
        );

        if (!mounted) return;
        _cancelEdit();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('수정됐어요.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 1500),
          ),
        );
      } else {
        // ── 신규 작성 모드 ──────────────────────────────────────
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notes')
            .doc();
        final noteId = docRef.id;

        List<String> imageUrls = [];
        if (_selectedImages.isNotEmpty) {
          imageUrls = await DiaryImageService.uploadAll(
            uid: uid,
            noteId: noteId,
            files: _selectedImages,
          );
        }

        await docRef.set({
          'text': text,
          'imageUrls': imageUrls,
          'createdAt': FieldValue.serverTimestamp(),
          'visibility': 'private',
        });

        AdminActivityService.log(
          ActivityEventType.noteSaveSuccess,
          page: 'record_hub',
          targetId: noteId,
          extra: {
            'mode': 'create',
            'hasImages': imageUrls.isNotEmpty,
            'imageCount': imageUrls.length,
            'textLength': text.length,
          },
        );

        widget.onCharacterMent(DiaryResponseService.getRandomResponse(text));

        if (!mounted) return;
        _controller.clear();
        setState(() => _selectedImages.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장됐어요. 오늘도 한 줄 남겼네.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      AdminActivityService.log(
        ActivityEventType.noteSaveFail,
        page: 'record_hub',
        extra: {'error': e.toString(), 'mode': isEditing ? 'edit' : 'create'},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('로그인이 필요합니다'));
    }
    return Column(
      children: [
        // ── 피드 ──
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('notes')
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: const Text(
                      '기록을 불러오지 못했어요. 잠시 뒤 다시 시도해 주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                );
              }
              final docs = [...?snap.data?.docs];
              docs.sort((a, b) {
                final at = (a.data() as Map)['createdAt'] as Timestamp?;
                final bt = (b.data() as Map)['createdAt'] as Timestamp?;
                if (at != null && bt != null) return bt.compareTo(at);
                if (at != null) return -1;
                if (bt != null) return 1;
                return b.id.compareTo(a.id);
              });
              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl),
                    child: AppMutedCard(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xxl,
                          horizontal: AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            '기억해야 할 지금을 남겨보세요',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '나만 볼 수 있어요',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final m = d.data() as Map<String, dynamic>;
                  final urls = _parseImageUrls(m);
                  final txt = m['text'] as String? ?? '';
                  // 최신순 → i=0 이 가장 최근. 순번은 오래된 글=01, 최신=N.
                  final orderNumber = docs.length - i;
                  return _FeedCard(
                    recordLabel: _recordOrderLabel(orderNumber),
                    noteId: d.id,
                    uid: uid,
                    text: txt,
                    mood: m['mood'] as String?,
                    createdAt: m['createdAt'] as Timestamp?,
                    imageUrls: urls,
                    isEditing: _editingNoteId == d.id,
                    onTapEdit: () => _enterEdit(
                      noteId: d.id,
                      text: txt,
                      imageUrls: urls,
                    ),
                  );
                },
              );
            },
          ),
        ),
        // ── 하단 고정 입력 바 (키보드 따라 올라옴) ──
        _buildComposer(),
      ],
    );
  }

  Widget _buildComposer() {
    final isEditing = _editingNoteId != null;
    final keepingExistingImages =
        isEditing && !_editingClearImages && _editingExistingUrls.isNotEmpty;
    final canSave = !_isSaving &&
        (_controller.text.trim().isNotEmpty ||
            _selectedImages.isNotEmpty ||
            keepingExistingImages);
    final stickerCount = _kStickerToken.allMatches(_controller.text).length;

    // 속닥속닥 입력 카드와 같은 3단 구조: 헤더 → 본문 → 작은 아이콘 툴바.
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.sm + MediaQuery.of(context).viewInsets.bottom,
      ),
      color: AppColors.appBg,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEditing) ...[
              Row(
                children: [
                  const Icon(Icons.edit_outlined,
                      size: 14, color: AppColors.textPrimary),
                  const SizedBox(width: 6),
                  const Text(
                    '기록 수정 중',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (keepingExistingImages) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _editingClearImages = true),
                      child: const Text(
                        '사진 비우기',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelEdit,
                    child: const Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ] else ...[
              const Text(
                '나만 보는 한 줄',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            ExtendedTextField(
              controller: _controller,
              focusNode: _focus,
              maxLength: _maxLen,
              minLines: 2,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              specialTextSpanBuilder: _StickerSpanBuilder(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: isEditing ? _composerEditHint : _composerHint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDisabled.withValues(alpha: 0.85),
                ),
                border: InputBorder.none,
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_selectedImages[i].path),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedImages.removeAt(i)),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                _RecordComposerAction(
                  icon: Icons.image_outlined,
                  label:
                      '이미지 ${_selectedImages.length}/$_maxImages',
                  onTap: _isSaving || _selectedImages.length >= _maxImages
                      ? null
                      : _pickImages,
                ),
                const SizedBox(width: AppSpacing.sm),
                _RecordComposerAction(
                  icon: Icons.emoji_emotions_outlined,
                  label: stickerCount > 0
                      ? '스티커 $stickerCount'
                      : '스티커',
                  onTap: _isSaving ? null : _insertSticker,
                ),
                const Spacer(),
                TextButton(
                  onPressed: canSave && !_isSaving ? _save : null,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.lime,
                    disabledForegroundColor: AppColors.textDisabled,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.lime,
                          ),
                        )
                      : Text(isEditing ? '수정' : '저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static List<String> _parseImageUrls(Map<String, dynamic> data) {
    final raw = data['imageUrls'];
    if (raw is List) return raw.cast<String>();
    return [];
  }
}

// ═════════════════════════════════════════════════════════════════
// 피드 카드 — 트위터식 1열 카드
// ═════════════════════════════════════════════════════════════════

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.recordLabel,
    required this.noteId,
    required this.uid,
    required this.text,
    required this.mood,
    required this.createdAt,
    required this.imageUrls,
    required this.isEditing,
    required this.onTapEdit,
  });

  final String recordLabel;
  final String noteId;
  final String uid;
  final String text;
  final String? mood;
  final Timestamp? createdAt;
  final List<String> imageUrls;
  final bool isEditing;
  final VoidCallback onTapEdit;

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays == 0) return DateFormat('HH:mm').format(d);
    if (diff.inDays == 1) return '어제 ${DateFormat('HH:mm').format(d)}';
    if (d.year == now.year) {
      return DateFormat('M월 d일 HH:mm').format(d);
    }
    return DateFormat('yy/M/d HH:mm').format(d);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmModal(
        title: '기록 삭제',
        message: imageUrls.isEmpty
            ? '이 기록을 삭제하시겠습니까?'
            : '이 기록과 첨부된 사진 ${imageUrls.length}장을 함께 삭제합니다.',
        confirmLabel: '삭제',
        destructive: true,
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      if (imageUrls.isNotEmpty) {
        await DiaryImageService.deleteAll(
          uid: uid,
          noteId: noteId,
          imageUrls: imageUrls,
        );
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notes')
          .doc(noteId)
          .delete();
    } catch (_) {/* 토스트는 부모 컨텍스트에서 처리하지 않음 */}
  }

  @override
  Widget build(BuildContext context) {
    return AppMutedCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                recordLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.schedule,
                  size: 12, color: AppColors.textDisabled),
              const SizedBox(width: 3),
              Text(
                _formatDate(createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (isEditing) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.lime.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '수정 중',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: onTapEdit,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: isEditing
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _confirmDelete(context),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Icon(Icons.delete_outline,
                      size: 16, color: AppColors.textDisabled),
                ),
              ),
            ],
          ),
          if (text.isNotEmpty || (mood != null && mood!.isNotEmpty)) ...[
            const SizedBox(height: 6),
            // 본문 — 스티커 토큰 [[s:id]] 은 인라인 위젯스팬으로 치환.
            // 기존 mood(단일 이모지) 데이터는 본문 앞에 그대로 표시해 호환.
            Text.rich(
              TextSpan(
                children: [
                  if (mood != null && mood!.isNotEmpty)
                    TextSpan(
                      text: '$mood  ',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ...buildInlineStickerSpans(
                    text,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: AppColors.textPrimary,
                    ),
                    stickerSize: 22,
                  ),
                ],
              ),
            ),
          ],
          if (imageUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  return GestureDetector(
                    onTap: () => _openLightbox(context, i),
                    child: Hero(
                      tag: 'note_$noteId\_$i',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrls[i],
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 76,
                            height: 76,
                            color: AppColors.surfaceMuted,
                            child: const Icon(Icons.broken_image_outlined,
                                size: 18, color: AppColors.textDisabled),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openLightbox(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => _ImageLightbox(
          noteId: noteId,
          urls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

/// 사진 라이트박스 — 풀스크린 + 핀치 줌 + PageView 좌우 스와이프.
/// 어디든 탭하면 닫힘.
class _ImageLightbox extends StatefulWidget {
  const _ImageLightbox({
    required this.noteId,
    required this.urls,
    required this.initialIndex,
  });

  final String noteId;
  final List<String> urls;
  final int initialIndex;

  @override
  State<_ImageLightbox> createState() => _ImageLightboxState();
}

class _ImageLightboxState extends State<_ImageLightbox> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMany = widget.urls.length > 1;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.urls.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  return Center(
                    child: Hero(
                      tag: 'note_${widget.noteId}_$i',
                      child: InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: Image.network(
                          widget.urls[i],
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (hasMany)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.urls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 속닥속닥 [_ComposerAction] 과 동일 톤 — 작은 아이콘 + 라벨.
class _RecordComposerAction extends StatelessWidget {
  const _RecordComposerAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: onTap == null
                  ? AppColors.textDisabled
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: onTap == null
                    ? AppColors.textDisabled
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.lime : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected ? AppColors.lime : Colors.transparent,
              width: selected ? 1.5 : 0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? AppColors.onCardEmphasis
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected
                      ? AppColors.onCardEmphasis
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
