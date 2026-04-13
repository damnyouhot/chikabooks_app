import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'job_post_form.dart';
import 'job_preview_scroll_anchor.dart';
import '../utils/job_post_field_sync.dart';
import '../utils/job_draft_sync_debug.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../models/job.dart';
import '../../../widgets/job/job_cover_image.dart';
import '../../../widgets/job/job_detail_widgets.dart';

/// AI 추출 직후 좌측 미리보기 — [JobDetailScreen]과 동일 컴포넌트·토큰·타이포 사용.
/// 값이 없는 정보 행은 표시하지 않는다(대시로 채우지 않음).
class JobPostPreview extends StatefulWidget {
  final JobPostData data;

  /// 드래프트 에디터 좌측 등 — 뷰포트 높이 상한. 지정 시 **내부 [ListView]만** 스크롤(바깥 이중 스크롤 방지).
  final double? maxHeight;

  /// 부모가 소유 — [Scrollable.ensureVisible] 연동 시 전달.
  final ScrollController? scrollController;

  /// 섹션 앵커 — [JobDraftEditorPage] 등에서 생성해 전달.
  final Map<JobPreviewScrollAnchor, GlobalKey>? sectionKeys;

  const JobPostPreview({
    super.key,
    required this.data,
    this.maxHeight,
    this.scrollController,
    this.sectionKeys,
  });

  @override
  State<JobPostPreview> createState() => _JobPostPreviewState();
}

class _JobPostPreviewState extends State<JobPostPreview> {
  late final PageController _galleryCtrl;
  int _galleryIndex = 0;
  String? _lastPreviewLogSig;

  JobPostData get data => widget.data;

  @override
  void initState() {
    super.initState();
    _galleryCtrl = PageController();
  }

  @override
  void dispose() {
    _galleryCtrl.dispose();
    super.dispose();
  }

  bool _hasText(String? s) => (s?.trim().isNotEmpty ?? false);

  String _hireRolesLine() {
    return JobPostFieldSync.hireRolesDisplayLine(
      hireRoles: data.hireRoles,
      role: data.role,
    );
  }

  Widget _buildPreviewTitleHeader() {
    final hasTitle = _hasText(data.title);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          hasTitle ? data.title.trim() : '제목 미입력 · 오른쪽에서 입력해 주세요',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
            height: 1.25,
            color: hasTitle ? AppColors.textPrimary : AppColors.textDisabled,
            fontStyle: hasTitle ? FontStyle.normal : FontStyle.italic,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  /// 연속 [JobDetailInfoRow]를 2열로 배치 (모바일 프리뷰 폭 활용)
  Widget _previewInfoGrid(List<Widget> rows) {
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i += 2) {
      if (i + 1 < rows.length) {
        out.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: rows[i]),
              const SizedBox(width: 10),
              Expanded(child: rows[i + 1]),
            ],
          ),
        );
      } else {
        out.add(rows[i]);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: out,
    );
  }

  String? _workDaysLabel() {
    if (data.workDays.isEmpty) return null;
    return data.workDays.map((d) => Job.workDayLabels[d] ?? d).join(', ');
  }

  String _transportValue() {
    if (data.subwayStationName == null ||
        data.subwayStationName!.trim().isEmpty) {
      return '';
    }
    final parts = <String>[data.subwayStationName!.trim()];
    if (data.exitNumber != null && data.exitNumber!.trim().isNotEmpty) {
      parts.add('${data.exitNumber}번 출구');
    }
    if (data.walkingMinutes != null) parts.add('도보 ${data.walkingMinutes}분');
    if (data.walkingDistanceMeters != null) {
      parts.add('(${data.walkingDistanceMeters}m)');
    }
    return parts.join(' · ');
  }

  String _dateFmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _anchor(JobPreviewScrollAnchor anchor, Widget child) {
    final k = widget.sectionKeys?[anchor];
    if (k == null) return child;
    return KeyedSubtree(key: k, child: child);
  }

  List<Widget> _sectionBasicInfo() {
    final hireLine = _hireRolesLine();
    final dutyLine =
        data.mainDutiesList.isNotEmpty ? data.mainDutiesList.join(', ') : '';
    final rows = <Widget>[
      if (_hasText(data.clinicName))
        JobDetailInfoRow(
          icon: Icons.storefront_outlined,
          label: '치과명',
          value: data.clinicName.trim(),
        ),
      if (_hasText(data.career))
        JobDetailInfoRow(
          icon: Icons.work_history_outlined,
          label: '경력',
          value: data.career.trim(),
        ),
      if (_hasText(hireLine))
        JobDetailInfoRow(
          icon: Icons.badge_outlined,
          label: '채용직',
          value: hireLine.trim(),
        ),
      if (_hasText(dutyLine))
        JobDetailInfoRow(
          icon: Icons.task_alt_outlined,
          label: '담당 업무',
          value: dutyLine.trim(),
        ),
      if (_hasText(data.education))
        JobDetailInfoRow(
          icon: Icons.school_outlined,
          label: '학력',
          value: data.education.trim(),
        ),
      if (_hasText(data.employmentType))
        JobDetailInfoRow(
          icon: Icons.work_outline,
          label: '고용 형태',
          value: data.employmentType.trim(),
        ),
      if (_hasText(data.salary))
        JobDetailInfoRow(
          icon: Icons.payments_outlined,
          label: '급여',
          value: data.salary.trim(),
        ),
    ];
    if (rows.isEmpty) return [];
    return [
      const JobDetailSectionTitle('기본 정보'),
      _previewInfoGrid(rows),
      Divider(
        height: AppPublisher.previewSectionDividerHeight,
        color: AppColors.divider,
      ),
    ];
  }

  /// 홍보이미지 — 담당업무 뒤·병원정보 앞에 세로 배치, AI 추출 없이 직접 노출
  List<Widget> _sectionPromotionalImages() {
    final urls = data.promotionalImageUrls;
    if (urls.isEmpty) return [];
    return [
      ...urls.map(
        (url) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppPublisher.softRadius),
            child: Image.network(
              url,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              errorBuilder:
                  (_, __, ___) => Container(
                    width: double.infinity,
                    height: 120,
                    color: AppColors.surfaceMuted,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textDisabled,
                    ),
                  ),
            ),
          ),
        ),
      ),
      Divider(
        height: AppPublisher.previewSectionDividerHeight,
        color: AppColors.divider,
      ),
    ];
  }

  List<Widget> _sectionHospital() {
    final rows = <Widget>[
      if (data.hospitalType != null && data.hospitalType!.isNotEmpty)
        JobDetailInfoRow(
          icon: Icons.business_outlined,
          label: '병원 유형',
          value:
              Job.hospitalTypeLabels[data.hospitalType] ?? data.hospitalType!,
        ),
      if (data.chairCount != null)
        JobDetailInfoRow(
          icon: Icons.airline_seat_recline_normal_outlined,
          label: '체어 수',
          value: '${data.chairCount}대',
        ),
      if (data.staffCount != null)
        JobDetailInfoRow(
          icon: Icons.group_outlined,
          label: '스탭 수',
          value: '${data.staffCount}명',
        ),
      if (data.specialties.isNotEmpty)
        JobDetailInfoRow(
          icon: Icons.medical_services_outlined,
          label: '주요 진료 과목',
          value: data.specialties.join(', '),
        ),
      if (data.hasOralScanner != null)
        JobDetailInfoRow(
          icon: Icons.precision_manufacturing_outlined,
          label: '구강 스캐너',
          value: data.hasOralScanner! ? '보유' : '없음',
        ),
      if (data.hasCT != null)
        JobDetailInfoRow(
          icon: Icons.view_in_ar_outlined,
          label: 'CT',
          value: data.hasCT! ? '보유' : '없음',
        ),
      if (data.has3DPrinter != null)
        JobDetailInfoRow(
          icon: Icons.threed_rotation_outlined,
          label: '3D 프린터',
          value: data.has3DPrinter! ? '보유' : '없음',
        ),
      if (data.digitalEquipmentRaw != null &&
          data.digitalEquipmentRaw!.trim().isNotEmpty)
        JobDetailInfoRow(
          icon: Icons.more_horiz,
          label: '기타 장비',
          value: data.digitalEquipmentRaw!.trim(),
        ),
    ];
    if (rows.isEmpty) return [];
    return [
      const JobDetailSectionTitle('병원 정보'),
      _previewInfoGrid(rows),
      Divider(
        height: AppPublisher.previewSectionDividerHeight,
        color: AppColors.divider,
      ),
    ];
  }

  List<Widget> _sectionWorkConditions() {
    final wd = _workDaysLabel();
    final rows = <Widget>[
      if (_hasText(data.workHours))
        JobDetailInfoRow(
          icon: Icons.schedule_outlined,
          label: '근무 시간',
          value: data.workHours.trim(),
        ),
      if (_hasText(wd))
        JobDetailInfoRow(
          icon: Icons.calendar_month_outlined,
          label: '근무 요일',
          value: wd!.trim(),
        ),
      if (data.weekendWork)
        JobDetailInfoRow(
          icon: Icons.weekend_outlined,
          label: '주말 근무',
          value: '있음',
        ),
      if (data.nightShift)
        JobDetailInfoRow(
          icon: Icons.nights_stay_outlined,
          label: '야간 진료',
          value: '있음',
        ),
    ];
    if (rows.isEmpty) return [];
    return [
      const JobDetailSectionTitle('근무 조건'),
      _previewInfoGrid(rows),
      Divider(
        height: AppPublisher.previewSectionDividerHeight,
        color: AppColors.divider,
      ),
    ];
  }

  List<Widget> _sectionApply() {
    final rows = <Widget>[
      if (data.applyMethod.isNotEmpty)
        JobDetailInfoRow(
          icon: Icons.send_outlined,
          label: '지원 방법',
          value: data.applyMethod
              .map((m) => Job.applyMethodLabels[m] ?? m)
              .join(', '),
        ),
      if (data.requiredDocuments.isNotEmpty)
        JobDetailInfoRow(
          icon: Icons.description_outlined,
          label: '제출서류',
          value: data.requiredDocuments.join(', '),
        ),
      JobDetailInfoRow(
        icon: Icons.all_inclusive,
        label: '상시채용',
        value: data.isAlwaysHiring ? '예' : '아니오',
      ),
      if (data.closingDate != null)
        JobDetailInfoRow(
          icon: Icons.event_busy_outlined,
          label: '마감일',
          value: _dateFmt(data.closingDate!),
        ),
    ];
    return [
      const JobDetailSectionTitle('지원 방법 · 마감'),
      _previewInfoGrid(rows),
      Divider(
        height: AppPublisher.previewSectionDividerHeight,
        color: AppColors.divider,
      ),
    ];
  }

  List<Widget> _sectionAddress() {
    final tv = _transportValue();
    final rows = <Widget>[
      if (_hasText(data.address))
        JobDetailInfoRow(
          icon: Icons.location_on_outlined,
          label: '주소',
          value: data.address.trim(),
        ),
      if (_hasText(data.contact))
        JobDetailInfoRow(
          icon: Icons.phone_outlined,
          label: '연락처',
          value: data.contact.trim(),
        ),
      if (_hasText(tv))
        JobDetailInfoRow(
          icon: Icons.subway_outlined,
          label: '교통',
          value: tv.trim(),
        ),
      if (data.parking)
        JobDetailInfoRow(
          icon: Icons.local_parking_outlined,
          label: '주차',
          value: '가능',
        ),
    ];
    final hasSubway = data.subwayLines.isNotEmpty;
    final hasLatLng = data.lat != null && data.lng != null;
    if (rows.isEmpty && !hasSubway && !hasLatLng) return [];
    return [
      const JobDetailSectionTitle('주소 · 연락처 · 교통'),
      if (hasLatLng) _buildMapWidget(data.lat!, data.lng!),
      if (rows.isNotEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
      if (hasSubway)
        Padding(
          padding: const EdgeInsets.only(
            left: 18 + AppSpacing.sm,
            bottom: AppSpacing.md,
          ),
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children:
                data.subwayLines
                    .map(
                      (l) => Text(
                        l,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
    ];
  }

  /// 주소 섹션 최상단 지도 위젯.
  /// 웹에서는 HtmlElementView 가 Clip 컨테이너를 벗어나는 렌더링 문제가 있어
  /// PointerSignalResolver 로 스크롤 이벤트를 흡수해 지도 위에서 리스트가 스크롤되도록 처리.
  Widget _buildMapWidget(double lat, double lng) {
    final latLng = LatLng(lat, lng);
    final mapChild = ClipRRect(
      borderRadius: BorderRadius.circular(AppPublisher.softRadius),
      child: SizedBox(
        height: 160,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: latLng, zoom: 15),
          markers: {
            Marker(markerId: const MarkerId('clinic'), position: latLng),
          },
          zoomControlsEnabled: false,
          scrollGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          zoomGesturesEnabled: false,
          myLocationButtonEnabled: false,
          liteModeEnabled: !kIsWeb,
        ),
      ),
    );

    // 웹: 지도 위에서 발생하는 스크롤 이벤트를 부모 ListView 로 전달
    if (kIsWeb) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              // 이벤트를 소비해 지도가 가로채지 않도록 처리
              GestureBinding.instance.pointerSignalResolver.register(
                event,
                (e) {
                  if (e is! PointerScrollEvent) return;
                  final ctx = context;
                  if (!ctx.mounted) return;
                  final scrollable = Scrollable.maybeOf(ctx);
                  if (scrollable == null) return;
                  final pos = scrollable.position;
                  final newOffset =
                      (pos.pixels + e.scrollDelta.dy).clamp(
                        pos.minScrollExtent,
                        pos.maxScrollExtent,
                      );
                  pos.jumpTo(newOffset);
                },
              );
            }
          },
          child: mapChild,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: mapChild,
    );
  }

  @override
  Widget build(BuildContext context) {
    const phoneW = 390.0;
    final phoneH = (widget.maxHeight ?? 844.0).clamp(280.0, 844.0);

    if (kDebugMode) {
      final sig =
          '${data.address}|${data.contact}|${data.description.length}|${data.workHours}|${data.tags.length}';
      if (sig != _lastPreviewLogSig) {
        _lastPreviewLogSig = sig;
        JobDraftSyncDebug.logPipeline('preview', data);
      }
    }

    return Center(
      child: SizedBox(
        width: phoneW,
        height: phoneH,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.appBg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.14),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Scaffold(
            backgroundColor: AppColors.appBg,
            appBar: AppBar(
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              backgroundColor: AppColors.appBg,
              leading: const Icon(
                Icons.arrow_back,
                color: AppColors.textPrimary,
              ),
              title: Text(
                data.clinicName.trim().isEmpty
                    ? '(샘플) 치과명'
                    : data.clinicName.trim(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.emphasisBadgeBg,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        child: Text(
                          '초안 미리보기',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.emphasisBadgeText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: ListView(
              controller: widget.scrollController,
              primary: widget.scrollController == null,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg + 10,
                AppSpacing.md,
                AppSpacing.lg,
                88,
              ),
              physics: const BouncingScrollPhysics(),
              children: [
                _anchor(
                  JobPreviewScrollAnchor.basicInfo,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPreviewTitleHeader(),
                      if (data.images.isNotEmpty) ...[
                        _buildImageGallery(),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      ..._sectionBasicInfo(),
                    ],
                  ),
                ),
                _anchor(
                  JobPreviewScrollAnchor.workConditions,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _sectionWorkConditions(),
                  ),
                ),
                _anchor(
                  JobPreviewScrollAnchor.hospital,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ..._sectionPromotionalImages(),
                      ..._sectionHospital(),
                    ],
                  ),
                ),
                _anchor(
                  JobPreviewScrollAnchor.benefits,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const JobDetailSectionTitle('복리후생'),
                      if (data.benefits.isEmpty)
                        Text(
                          '복리후생 미확인 · 오른쪽에서 입력해 주세요',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.textDisabled,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        _buildBenefitsWrap(),
                      Divider(
                        height: AppPublisher.previewSectionDividerHeight,
                        color: AppColors.divider,
                      ),
                    ],
                  ),
                ),
                _anchor(
                  JobPreviewScrollAnchor.apply,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _sectionApply(),
                  ),
                ),
                _anchor(
                  JobPreviewScrollAnchor.description,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const JobDetailSectionTitle('상세 내용'),
                      Text(
                        data.description.trim().isNotEmpty
                            ? data.description.trim()
                            : '병원 소개 미입력 · 오른쪽에서 입력해 주세요',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color:
                              data.description.trim().isNotEmpty
                                  ? AppColors.textSecondary
                                  : AppColors.textDisabled,
                          fontStyle:
                              data.description.trim().isEmpty
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
                _anchor(
                  JobPreviewScrollAnchor.addressContact,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ..._sectionAddress(),
                      const SizedBox(height: AppSpacing.xl),
                      Center(
                        child: Text(
                          'AI가 정리한 공고 초안 · 오른쪽에서 수정 후 등록하세요',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textDisabled,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const int _kBenefitsMaxVisible = 12;

  Widget _buildBenefitsWrap() {
    final list = data.benefits;
    final visible = list.take(_kBenefitsMaxVisible).toList();
    final rest = list.length - visible.length;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        ...visible.map((b) => JobBenefitChip(label: b)),
        if (rest > 0)
          Chip(
            label: Text(
              '+$rest',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.jobPreviewOverflowChipText,
              ),
            ),
            backgroundColor: AppColors.jobPreviewOverflowChipBg,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            side: BorderSide.none,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _buildImageGallery() {
    final count = data.images.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            height: 220,
            child:
                count == 1
                    ? _coverForIndex(0)
                    : PageView.builder(
                      controller: _galleryCtrl,
                      itemCount: count,
                      onPageChanged: (i) => setState(() => _galleryIndex = i),
                      itemBuilder:
                          (_, i) => SizedBox.expand(child: _coverForIndex(i)),
                    ),
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(count, (i) {
              final active = i == _galleryIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : AppColors.divider,
                  borderRadius: BorderRadius.circular(AppRadius.xs / 2),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _coverForIndex(int i) {
    final path = data.images[i].path;
    if (kIsWeb) {
      return JobCoverImage(source: path, fit: BoxFit.cover);
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      width: double.infinity,
      height: 220,
      errorBuilder:
          (_, __, ___) => Container(
            color: AppColors.disabledBg,
            child: const Icon(
              Icons.business,
              size: 48,
              color: AppColors.textDisabled,
            ),
          ),
    );
  }
}
