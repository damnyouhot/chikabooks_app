import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'job_post_form.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/job.dart';

/// 지원자 관점 공고 미리보기 (앱 화면 비율 모방)
///
/// 웹 좌측 패널에서 사용. 실제 앱 상세 화면처럼 보이는 모바일 프레임.
class JobPostPreview extends StatelessWidget {
  final JobPostData data;

  const JobPostPreview({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    const double mockupHeight = 754;

    return Center(
      child: SizedBox(
        width: 360,
        height: mockupHeight,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.appBg,
            borderRadius: BorderRadius.circular(46),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withOpacity(0.18),
                blurRadius: 40,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusBar(),
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroImage(),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 12),

                            // 태그 + 마감일 배지
                            if (data.tags.isNotEmpty || data.isAlwaysHiring || data.closingDate != null)
                              _buildTagsBadges(),

                            // 교통편
                            if (data.subwayStationName != null && data.subwayStationName!.isNotEmpty)
                              _buildTransportation(),

                            _divider(),
                            const SizedBox(height: 12),

                            // 병원 정보
                            if (data.hospitalType != null || data.chairCount != null || data.staffCount != null) ...[
                              _buildHospitalInfo(),
                              _divider(),
                              const SizedBox(height: 12),
                            ],

                            // 근무 조건
                            _buildWorkConditions(),
                            _divider(),
                            const SizedBox(height: 12),

                            // 복리후생
                            if (data.benefits.isNotEmpty) ...[
                              _buildBenefits(),
                              _divider(),
                              const SizedBox(height: 12),
                            ],

                            // 상세 내용
                            if (data.description.isNotEmpty) ...[
                              _buildDescription(),
                              _divider(),
                              const SizedBox(height: 12),
                            ],

                            // 주소
                            if (data.address.isNotEmpty) ...[
                              _buildAddress(),
                              const SizedBox(height: 16),
                            ],

                            // 지원 방법
                            if (data.applyMethod.isNotEmpty) ...[
                              _buildApplyMethods(),
                              const SizedBox(height: 16),
                            ],

                            _buildApplyButton(),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                '미리보기 화면입니다. 실제 앱 화면과 다를 수 있어요.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textDisabled,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      color: AppColors.accent.withOpacity(0.08),
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 8),
      child: Row(
        children: [
          Text(
            '9:41',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Icon(Icons.signal_cellular_alt, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Icon(Icons.wifi, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Icon(Icons.battery_full, size: 14, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.arrow_back_ios, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '구인공고',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Icon(Icons.bookmark_border, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Icon(Icons.share_outlined, size: 20, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    if (data.images.isEmpty) {
      return Container(
        height: 180,
        color: AppColors.error.withOpacity(0.25),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.business_outlined, size: 40, color: AppColors.textDisabled),
              const SizedBox(height: 8),
              Text('대표 이미지', style: TextStyle(fontSize: 13, color: AppColors.textDisabled)),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 180,
      child: kIsWeb
          ? Image.network(
              data.images.first.path,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 180,
                color: AppColors.error.withOpacity(0.25),
                child: const Center(child: Icon(Icons.broken_image_outlined)),
              ),
            )
          : Image.file(
              File(data.images.first.path),
              width: double.infinity,
              fit: BoxFit.cover,
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.clinicName.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.35),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              data.clinicName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          data.title.isEmpty ? '공고 제목을 입력해주세요' : data.title,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: data.title.isEmpty ? AppColors.textDisabled : AppColors.textPrimary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        // 직무 · 경력 · 고용형태 태그
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (data.role.isNotEmpty) _tag(data.role),
            if (data.career.isNotEmpty) _tag(data.career),
            if (data.employmentType.isNotEmpty) _tag(data.employmentType),
          ],
        ),
        if (data.salary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            data.salary,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTagsBadges() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          if (data.isAlwaysHiring)
            _badge('상시채용', AppColors.success),
          if (!data.isAlwaysHiring && data.closingDate != null)
            _badge(
              'D-${data.closingDate!.difference(DateTime.now()).inDays}',
              AppColors.error,
            ),
          ...data.tags.map((t) => _badge(t, AppColors.accent)),
        ],
      ),
    );
  }

  Widget _buildTransportation() {
    final parts = <String>[data.subwayStationName ?? ''];
    if (data.walkingMinutes != null) parts.add('도보 ${data.walkingMinutes}분');
    if (data.walkingDistanceMeters != null) parts.add('(${data.walkingDistanceMeters}m)');
    final line = parts.join(' ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.subway, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              data.exitNumber != null && data.exitNumber!.isNotEmpty
                  ? '$line · ${data.exitNumber}'
                  : line,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
      ),
    );
  }

  Widget _buildHospitalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('병원 정보'),
        const SizedBox(height: 8),
        if (data.hospitalType != null)
          _infoRow(Icons.business_outlined, '유형',
              Job.hospitalTypeLabels[data.hospitalType] ?? data.hospitalType!),
        if (data.chairCount != null)
          _infoRow(Icons.airline_seat_recline_normal_outlined, '체어 수',
              '${data.chairCount}대'),
        if (data.staffCount != null)
          _infoRow(Icons.group_outlined, '스탭 수', '${data.staffCount}명'),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildWorkConditions() {
    final hasContent = data.workDays.isNotEmpty ||
        data.workHours.isNotEmpty ||
        data.contact.isNotEmpty;

    if (!hasContent) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          '근무조건을 입력하면 여기에 표시돼요.',
          style: TextStyle(fontSize: 13, color: AppColors.textDisabled),
        ),
      );
    }

    // 근무요일 요약
    String workDaysSummary = '';
    if (data.workDays.isNotEmpty) {
      const order = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      final sorted = List<String>.from(data.workDays)
        ..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
      final labels = sorted.map((d) => Job.workDayLabels[d] ?? d).toList();
      workDaysSummary = labels.join(', ');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('근무 조건'),
        const SizedBox(height: 8),
        if (data.workDays.isNotEmpty)
          _infoRow(Icons.calendar_month_outlined, '근무 요일',
              workDaysSummary +
                  (data.weekendWork ? ' (주말근무)' : '') +
                  (data.nightShift ? ' · 야간진료' : '')),
        if (data.workHours.isNotEmpty)
          _infoRow(Icons.schedule_outlined, '근무 시간', data.workHours),
        if (data.salary.isNotEmpty)
          _infoRow(Icons.paid_outlined, '급여', data.salary),
        if (data.contact.isNotEmpty)
          _infoRow(Icons.phone_outlined, '연락처', data.contact),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildBenefits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('복리후생'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: data.benefits
              .map((b) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      b,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.accent.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('상세 내용'),
        const SizedBox(height: 8),
        Text(
          data.description,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildAddress() {
    return Row(
      children: [
        const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textDisabled),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            data.address,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildApplyMethods() {
    final labels = data.applyMethod
        .map((m) => Job.applyMethodLabels[m] ?? m)
        .toList();
    return Row(
      children: [
        const Icon(Icons.send_outlined, size: 14, color: AppColors.textDisabled),
        const SizedBox(width: 6),
        Text(
          '지원: ${labels.join(', ')}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          disabledBackgroundColor: AppColors.accent.withOpacity(0.35),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text(
          '지원하기 (미리보기)',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.white),
        ),
      ),
    );
  }

  // ── 헬퍼 위젯 ──

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.accent.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text(
            '$label  ',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(color: AppColors.divider);
}
