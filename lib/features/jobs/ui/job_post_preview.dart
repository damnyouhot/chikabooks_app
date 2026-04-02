import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'job_post_form.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_muted_card.dart';
import '../../../models/job.dart';
import '../../../widgets/job/job_cover_image.dart';
import '../../../widgets/job/job_detail_widgets.dart';

/// 지원자 관점 공고 미리보기 — [JobDetailScreen] 레이아웃·타이포·간격과 동일하게 맞춤.
///
/// 기기 비율: iPhone 14 계열 논리 해상도(390×844)에 대응하는 고정 프레임.
class JobPostPreview extends StatefulWidget {
  final JobPostData data;

  const JobPostPreview({super.key, required this.data});

  @override
  State<JobPostPreview> createState() => _JobPostPreviewState();
}

class _JobPostPreviewState extends State<JobPostPreview> {
  late final PageController _galleryCtrl;
  int _galleryIndex = 0;

  JobPostData get data => widget.data;

  /// 앱 목록 2행과 동일 규칙 ([Job.listRoleLine])
  String get _metaLine {
    final parts = <String>[];
    if (data.role.trim().isNotEmpty) parts.add(data.role.trim());
    if (data.employmentType.trim().isNotEmpty) {
      parts.add(data.employmentType.trim());
    }
    final c = data.career.trim();
    if (c.isNotEmpty && c != '미정') parts.add(c);
    return parts.join(' · ');
  }

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

  @override
  Widget build(BuildContext context) {
    const phoneW = 390.0;
    const phoneH = 844.0;

    return Center(
      child: SizedBox(
        width: phoneW,
        height: phoneH,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.appBg,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withOpacity(0.14),
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
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () {},
              ),
              title: Text(
                data.clinicName.trim().isEmpty ? '(샘플) 치과명' : data.clinicName.trim(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.star_border, color: AppColors.textSecondary),
                  onPressed: () {},
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {},
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              elevation: 0,
              icon: const Icon(Icons.send_outlined),
              label: const Text('원클릭 지원'),
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              physics: const BouncingScrollPhysics(),
              children: [
                if (data.images.isNotEmpty) ...[
                  _buildImageGallery(),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (data.address.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppColors.textDisabled,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          data.address,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (data.tags.isNotEmpty ||
                    data.isAlwaysHiring ||
                    data.closingDate != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (data.isAlwaysHiring)
                          _DetailBadgePreview(
                            label: '상시채용',
                            color: AppColors.success,
                          ),
                        if (!data.isAlwaysHiring && data.closingDate != null)
                          _DetailBadgePreview(
                            label:
                                'D-${data.closingDate!.difference(DateTime.now()).inDays}',
                            color: AppColors.error,
                          ),
                        ...data.tags.map(
                          (t) => _DetailBadgePreview(
                            label: t,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  data.title.isEmpty ? '(샘플) 공고 제목' : data.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                if (_metaLine.isNotEmpty)
                  Text(
                    _metaLine,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                if (data.salary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    data.salary,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
                if (data.subwayStationName != null &&
                    data.subwayStationName!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildTransportation(),
                ],
                Divider(height: AppSpacing.xxl, color: AppColors.divider),
                if (data.hospitalType != null ||
                    data.chairCount != null ||
                    data.staffCount != null) ...[
                  const JobDetailSectionTitle('병원 정보'),
                  if (data.hospitalType != null)
                    JobDetailInfoRow(
                      icon: Icons.business_outlined,
                      label: '유형',
                      value: Job.hospitalTypeLabels[data.hospitalType] ??
                          data.hospitalType!,
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
                  Divider(height: AppSpacing.xxl, color: AppColors.divider),
                ],
                if (data.workHours.isNotEmpty ||
                    data.contact.isNotEmpty ||
                    data.workDays.isNotEmpty ||
                    data.applyMethod.isNotEmpty) ...[
                  const JobDetailSectionTitle('근무 조건'),
                  ..._buildWorkConditionRows(),
                  Divider(height: AppSpacing.xxl, color: AppColors.divider),
                ],
                const JobDetailSectionTitle('업무 내용'),
                Text(
                  data.description.isNotEmpty
                      ? data.description
                      : '등록된 상세 설명이 없어요.',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (data.benefits.isNotEmpty) ...[
                  const JobDetailSectionTitle('복리후생'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: data.benefits
                        .map((b) => JobBenefitChip(label: b))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                AppMutedCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '원클릭 지원 (이력서 확인 후 제출)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        '누르면 바로 전송되지 않아요. 이력서를 확인/수정한 뒤 제출해요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
                Center(
                  child: Text(
                    '미리보기입니다. 실제 앱과 동일한 레이아웃을 반영했어요.',
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
        ),
      ),
    );
  }

  List<Widget> _buildWorkConditionRows() {
    final out = <Widget>[];
    if (data.workDays.isNotEmpty) {
      const order = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      final sorted = List<String>.from(data.workDays)
        ..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
      final labels = sorted.map((d) => Job.workDayLabels[d] ?? d).toList();
      final summary = labels.join(', ') +
          (data.weekendWork ? ' (주말근무)' : '') +
          (data.nightShift ? ' · 야간진료' : '');
      out.add(
        JobDetailInfoRow(
          icon: Icons.calendar_month_outlined,
          label: '근무 요일',
          value: summary,
        ),
      );
    }
    if (data.workHours.isNotEmpty) {
      out.add(
        JobDetailInfoRow(
          icon: Icons.schedule_outlined,
          label: '근무 시간',
          value: data.workHours,
        ),
      );
    }
    if (data.contact.isNotEmpty) {
      out.add(
        JobDetailInfoRow(
          icon: Icons.phone_outlined,
          label: '연락처',
          value: data.contact,
        ),
      );
    }
    if (data.applyMethod.isNotEmpty) {
      out.add(
        JobDetailInfoRow(
          icon: Icons.send_outlined,
          label: '지원 방법',
          value: data.applyMethod
              .map((m) => Job.applyMethodLabels[m] ?? m)
              .join(', '),
        ),
      );
    }
    return out;
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
            child: count == 1
                ? _coverForIndex(0)
                : PageView.builder(
                    controller: _galleryCtrl,
                    itemCount: count,
                    onPageChanged: (i) => setState(() => _galleryIndex = i),
                    itemBuilder: (_, i) => SizedBox.expand(child: _coverForIndex(i)),
                  ),
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: 8),
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
                  borderRadius: BorderRadius.circular(3),
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
      errorBuilder: (_, __, ___) => _placeholderImageArea(),
    );
  }

  Widget _placeholderImageArea() {
    return Container(
      color: AppColors.disabledBg,
      child: const Center(
        child: Icon(
          Icons.business,
          size: 48,
          color: AppColors.textDisabled,
        ),
      ),
    );
  }

  Widget _buildTransportation() {
    final parts = <String>[data.subwayStationName ?? ''];
    if (data.walkingMinutes != null) parts.add('도보 ${data.walkingMinutes}분');
    if (data.walkingDistanceMeters != null) {
      parts.add('(${data.walkingDistanceMeters}m)');
    }
    final line = parts.join(' ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.subway, size: 16, color: AppColors.accent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            data.exitNumber != null && data.exitNumber!.isNotEmpty
                ? '$line · ${data.exitNumber}'
                : line,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (data.parking)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(width: 8),
              Icon(Icons.local_parking, size: 14, color: AppColors.textDisabled),
              SizedBox(width: 2),
              Text('주차', style: TextStyle(fontSize: 11, color: AppColors.textDisabled)),
            ],
          ),
      ],
    );
  }
}

/// [JobDetailScreen]의 [_DetailBadge]와 동일 스타일
class _DetailBadgePreview extends StatelessWidget {
  final String label;
  final Color color;

  const _DetailBadgePreview({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
