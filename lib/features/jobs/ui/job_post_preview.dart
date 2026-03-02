import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'job_post_form.dart';

// ── 팔레트 ─────────────────────────────────────────────
const _kBg = Color(0xFFF1F7F7);
const _kText = Color(0xFF3D4A5C);
const _kBlue = Color(0xFF4A90D9);
const _kPink = Color(0xFFF7CBCA);
const _kCardBg = Colors.white;

/// 지원자 관점 공고 미리보기 (앱 화면 비율 모방)
///
/// 웹 좌측 패널에서 사용. 실제 앱 상세 화면처럼 보이는 모바일 프레임.
class JobPostPreview extends StatelessWidget {
  final JobPostData data;

  const JobPostPreview({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // 942px * 0.8 ≈ 754px
    const double mockupHeight = 754;

    return Center(
      child: SizedBox(
        width: 360,
        height: mockupHeight,
        child: Container(
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(46),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 40,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 상단 상태바 (시뮬레이션) ──
              _buildStatusBar(),
              // ── 앱 바 ──
              _buildAppBar(),
              // ── 스크롤 내용 ── (고정 높이의 나머지를 채움)
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 대표 이미지
                      _buildHeroImage(),
                      // 내용
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 16),
                            _divider(),
                            const SizedBox(height: 16),
                            _buildInfoRows(),
                            const SizedBox(height: 16),
                            if (data.benefits.isNotEmpty) ...[
                              _divider(),
                              const SizedBox(height: 16),
                              _buildBenefits(),
                              const SizedBox(height: 16),
                            ],
                            if (data.description.isNotEmpty) ...[
                              _divider(),
                              const SizedBox(height: 16),
                              _buildDescription(),
                              const SizedBox(height: 16),
                            ],
                            if (data.address.isNotEmpty) ...[
                              _divider(),
                              const SizedBox(height: 16),
                              _buildAddress(),
                              const SizedBox(height: 24),
                            ],
                            // 지원 버튼 (비활성 - 미리보기)
                            _buildApplyButton(),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                '미리보기 화면입니다. 실제 앱 화면과 다를 수 있어요.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _kText.withOpacity(0.35),
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
      color: _kBlue.withOpacity(0.08),
      // 상단 padding을 크게 주어 둥근 모서리 안으로 내용이 충분히 들어오게 함
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 8),
      child: Row(
        children: [
          Text(
            '9:41',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kText.withOpacity(0.7),
            ),
          ),
          const Spacer(),
          Icon(
            Icons.signal_cellular_alt,
            size: 14,
            color: _kText.withOpacity(0.5),
          ),
          const SizedBox(width: 4),
          Icon(Icons.wifi, size: 14, color: _kText.withOpacity(0.5)),
          const SizedBox(width: 4),
          Icon(Icons.battery_full, size: 14, color: _kText.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: _kCardBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.arrow_back_ios, size: 18, color: _kText.withOpacity(0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '구인공고',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ),
          Icon(Icons.bookmark_border, size: 20, color: _kText.withOpacity(0.5)),
          const SizedBox(width: 12),
          Icon(Icons.share_outlined, size: 20, color: _kText.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    if (data.images.isEmpty) {
      return Container(
        height: 180,
        color: _kPink.withOpacity(0.25),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.business_outlined,
                size: 40,
                color: _kText.withOpacity(0.25),
              ),
              const SizedBox(height: 8),
              Text(
                '대표 이미지',
                style: TextStyle(fontSize: 13, color: _kText.withOpacity(0.35)),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 180,
      child:
          kIsWeb
              ? Image.network(
                data.images.first.path,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                      height: 180,
                      color: _kPink.withOpacity(0.25),
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined),
                      ),
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
              color: _kPink.withOpacity(0.35),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              data.clinicName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          data.title.isEmpty ? '공고 제목을 입력해주세요' : data.title,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: data.title.isEmpty ? _kText.withOpacity(0.3) : _kText,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (data.role.isNotEmpty) _tag(data.role),
            if (data.role.isNotEmpty && data.employmentType.isNotEmpty)
              const SizedBox(width: 6),
            if (data.employmentType.isNotEmpty) _tag(data.employmentType),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRows() {
    final rows = <_InfoRow>[
      if (data.workHours.isNotEmpty)
        _InfoRow(icon: Icons.access_time, label: '근무시간', value: data.workHours),
      if (data.salary.isNotEmpty)
        _InfoRow(icon: Icons.paid_outlined, label: '급여', value: data.salary),
      if (data.contact.isNotEmpty)
        _InfoRow(icon: Icons.phone_outlined, label: '연락처', value: data.contact),
    ];

    if (rows.isEmpty) {
      return Text(
        '근무조건을 입력하면 여기에 표시돼요.',
        style: TextStyle(fontSize: 13, color: _kText.withOpacity(0.35)),
      );
    }

    return Column(
      children:
          rows
              .map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(r.icon, size: 16, color: _kBlue.withOpacity(0.7)),
                      const SizedBox(width: 8),
                      Text(
                        '${r.label}  ',
                        style: TextStyle(
                          fontSize: 13,
                          color: _kText.withOpacity(0.55),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          r.value,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _kText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildBenefits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '복리후생',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _kText.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children:
              data.benefits
                  .map(
                    (b) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _kBlue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        b,
                        style: TextStyle(
                          fontSize: 12,
                          color: _kBlue.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '상세 내용',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _kText.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          data.description,
          style: TextStyle(
            fontSize: 13,
            color: _kText.withOpacity(0.75),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildAddress() {
    return Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 16,
          color: _kText.withOpacity(0.45),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            data.address,
            style: TextStyle(fontSize: 13, color: _kText.withOpacity(0.7)),
          ),
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
          backgroundColor: _kBlue,
          disabledBackgroundColor: _kBlue.withOpacity(0.35),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '지원하기 (미리보기)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kPink.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: _kText.withOpacity(0.75)),
      ),
    );
  }

  Widget _divider() => Divider(color: Colors.grey.withOpacity(0.15));
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
}


