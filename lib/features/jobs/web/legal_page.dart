import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

// _kPink는 치카북스 브랜드 핑크 — 의도적 유지
const _kPink = Color(0xFFFF6B9D);

/// 약관/개인정보처리방침 등 법적 문서를 표시하는 공용 웹 페이지
///
/// 로그인 없이 접근 가능 (/privacy, /terms)
class LegalPage extends StatelessWidget {
  final String title;
  final String emoji;
  final List<LegalSection> sections;
  final String effectiveDate;

  const LegalPage({
    super.key,
    required this.title,
    required this.emoji,
    required this.sections,
    required this.effectiveDate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SelectionArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              children: [
                // ── 제목 ──
                Text(
                  '$emoji $title',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: _kPink, thickness: 2),
                const SizedBox(height: 24),

                // ── 섹션들 ──
                for (final section in sections) ...[
                  _buildSection(section),
                  const SizedBox(height: 24),
                ],

                // ── 푸터 ──
                const SizedBox(height: 24),
                Divider(color: AppColors.divider),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '본 ${title.contains('약관') ? '약관' : '방침'}은 ${effectiveDate}부터 적용됩니다.',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 13,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    '© 치과책방. All rights reserved.',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 13,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(LegalSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 제목
        Text(
          section.heading,
          style: GoogleFonts.notoSansKr(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // 본문
        for (final content in section.contents) _buildContent(content),
      ],
    );
  }

  Widget _buildContent(LegalContent content) {
    switch (content.type) {
      case LegalContentType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            content.text,
            style: GoogleFonts.notoSansKr(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.7,
            ),
          ),
        );

      case LegalContentType.subheading:
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(
            content.text,
            style: GoogleFonts.notoSansKr(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        );

      case LegalContentType.bulletList:
        return Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                content.items!
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '•  ',
                              style: GoogleFonts.notoSansKr(
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item,
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                  height: 1.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
          ),
        );

      case LegalContentType.note:
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1), // 노란 노트 배경 — 의도적 유지
            border: const Border(
              left: BorderSide(color: Color(0xFFFFC107), width: 4), // 황색 경고 테두리 — 의도적 유지
            ),
          ),
          child: Text(
            content.text,
            style: GoogleFonts.notoSansKr(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.7,
            ),
          ),
        );
    }
  }
}

// ── 데이터 모델 ─────────────────────────────────────────
enum LegalContentType { paragraph, subheading, bulletList, note }

class LegalContent {
  final LegalContentType type;
  final String text;
  final List<String>? items;

  const LegalContent.paragraph(this.text)
    : type = LegalContentType.paragraph,
      items = null;

  const LegalContent.subheading(this.text)
    : type = LegalContentType.subheading,
      items = null;

  const LegalContent.bullets(this.items)
    : type = LegalContentType.bulletList,
      text = '';

  const LegalContent.note(this.text)
    : type = LegalContentType.note,
      items = null;
}

class LegalSection {
  final String heading;
  final List<LegalContent> contents;

  const LegalSection({required this.heading, required this.contents});
}

// ═══════════════════════════════════════════════════════════
// 개인정보처리방침 데이터
// ═══════════════════════════════════════════════════════════

LegalPage buildPrivacyPage() {
  return const LegalPage(
    title: '개인정보처리방침',
    emoji: '🔐',
    effectiveDate: '2026년 3월 19일',
    sections: [
      LegalSection(
        heading: '1. 개인정보처리방침의 목적',
        contents: [
          LegalContent.paragraph(
            '홍덕우(이하 "사업자")는 모바일 앱 「치카북스」(표시명, 이하 "서비스")를 포함한 치과책방 관련 서비스 제공을 위해 개인정보를 처리하며, 「개인정보 보호법」 등 관련 법령을 준수합니다.',
          ),
        ],
      ),
      LegalSection(
        heading: '2. 수집하는 개인정보 항목',
        contents: [
          LegalContent.paragraph('사업자는 다음 정보를 수집·처리할 수 있습니다.'),
          LegalContent.subheading('회원가입 / 로그인 (소셜 로그인 포함)'),
          LegalContent.subheading('필수 수집 항목'),
          LegalContent.bullets([
            'Firebase UID (계정 식별자)',
            '이메일',
            '로그인 제공자 정보 (providerId)',
          ]),
          LegalContent.subheading('선택 수집 항목'),
          LegalContent.bullets([
            '닉네임',
            '프로필 이미지 (업로드 시)',
            '지역 / 경력 / 관심사 (서비스 기능 제공을 위해 입력되는 정보)',
          ]),
          LegalContent.subheading('서비스 이용 과정에서 자동 수집될 수 있는 정보'),
          LegalContent.bullets([
            '기기 정보 (모델명, OS 버전 등)',
            '앱 버전',
            '접속 로그',
            'IP 주소',
            '쿠키 및 유사 기술 식별자',
            '광고 식별자 (IDFA / ADID 등, 광고 또는 분석 SDK 사용 시)',
            '이용 기록 (화면 이용 기록, 기능 사용 로그, 오류 로그 등)',
          ]),
          LegalContent.subheading('돌보기(캐릭터 상호작용)'),
          LegalContent.bullets([
            '배고픔·기분·에너지·유대(친밀도) 등 돌보기 상태 값',
            '수면 여부, 밥주기·쓰다듬기 등 상호작용 및 일일 카운터',
          ]),
          LegalContent.subheading('전자책·학습·퀴즈'),
          LegalContent.bullets([
            '열람·서재·외부 몰 연동 구매 등 전자책 관련 식별·이용 기록',
            '퀴즈 풀이·정답 여부 등 학습 기록',
            '제도·HIRA 등 저장·열람 콘텐츠 이용 기록',
          ]),
          LegalContent.subheading('공감 투표·커뮤니티'),
          LegalContent.bullets([
            '투표 선택·직접 추가한 보기 문구, 종료 투표 한마디(댓글)',
            '게시글·댓글·이미지 등 피드·커뮤니티 콘텐츠',
          ]),
          LegalContent.subheading('커리어·이력서·지원'),
          LegalContent.bullets([
            '이력서 본문, 학력·경력·자격 등 입력 정보',
            '이력서·증빙 파일(PDF·이미지 등) 업로드',
            '지원서·지원 내역, 구인측 열람·처리와 관련된 기록',
          ]),
          LegalContent.subheading('고객 문의'),
          LegalContent.bullets(['문의 내용', '회신을 위한 연락 정보 (이메일 등)']),
          LegalContent.note(
            '※ 참고\n사업자는 서비스 운영 및 개선, 광고 제공 등을 위해 분석 도구 또는 광고 SDK를 사용할 수 있으며 적용 시 본 방침에 따라 처리합니다.',
          ),
        ],
      ),
      LegalSection(
        heading: '3. 개인정보의 처리 목적',
        contents: [
          LegalContent.paragraph('수집한 개인정보는 다음 목적에 사용됩니다.'),
          LegalContent.bullets([
            '회원 식별 및 인증, 계정 관리',
            '돌보기·성장·퀴즈·전자책 열람 등 서비스 기능 제공',
            '공감 투표·게시·댓글 등 커뮤니티 기능 제공',
            '이력서·지원·구인공고 열람 및 매칭(유료 기능 포함)',
            '구인공고 등록 및 유료서비스 제공(결제 확인 포함)',
            '이용환경 개선, 오류 분석, 통계·운영 분석 및 서비스 품질 개선',
            '맞춤형 또는 비맞춤형 광고 제공(도입/운영 시)',
            '부정 이용 방지 및 보안',
          ]),
        ],
      ),
      LegalSection(
        heading: '4. 개인정보의 보유 및 이용 기간',
        contents: [
          LegalContent.bullets([
            '원칙: 회원 탈퇴(계정 삭제) 시 지체 없이 파기',
            '예외: 관련 법령에 따른 보관 의무가 있는 경우 해당 기간 보관 후 파기',
            '콘텐츠: 회원 탈퇴 시 작성한 게시물은 커뮤니티 연속성을 위해 작성자 식별정보를 제거한 형태로 익명화되어 유지될 수 있습니다.',
            '파일: 탈퇴 시 이력서·업로드 파일 등 Storage에 저장된 개인 관련 객체는 삭제 또는 익명화 조치를 원칙으로 합니다(법령·분쟁 대응 예외).',
            '퀴즈·학습 기록: 탈퇴 시 원칙적으로 삭제하되, 통계 목적의 비식별 형태로 남을 수 있습니다.',
          ]),
        ],
      ),
      LegalSection(
        heading: '5. 개인정보의 제3자 제공',
        contents: [
          LegalContent.paragraph(
            '사업자는 원칙적으로 이용자의 개인정보를 제3자에게 제공하지 않습니다.\n다만 다음의 경우 예외로 합니다.',
          ),
          LegalContent.bullets(['이용자가 사전에 동의한 경우', '법령에 따라 제공 의무가 있는 경우']),
        ],
      ),
      LegalSection(
        heading: '6. 개인정보 처리의 위탁 및 국외 이전',
        contents: [
          LegalContent.paragraph('서비스는 아래 외부 서비스(수탁자)를 사용할 수 있습니다.'),
          LegalContent.subheading('Google Firebase (Google LLC)'),
          LegalContent.bullets([
            '목적: 사용자 인증(Auth), 데이터베이스(Firestore), 파일 저장(Storage), 서버 로직(Cloud Functions), 로그 및 분석(도입 시)',
            '처리 항목: 계정 식별자(UID), 이메일, 이용 기록, 저장된 회원 정보 및 콘텐츠, 기기 정보(설정에 따라)',
            '이전 국가: 미국 등 서비스 제공 국가',
            '보유 및 이용 기간: 서비스 제공 목적 달성 시까지 또는 관련 법령에 따른 기간',
          ]),
          LegalContent.subheading('Apple/Google 앱마켓 결제 시스템(인앱결제)'),
          LegalContent.bullets([
            '목적: 결제 처리 및 환불/청약철회 처리',
            '처리 항목: 결제 식별 정보(결제 토큰 등)',
          ]),
          LegalContent.note(
            '※ 참고: 광고 SDK 사용 시, 해당 광고 사업자/네트워크가 추가될 수 있으며 도입 시 본 방침에 반영합니다.',
          ),
        ],
      ),
      LegalSection(
        heading: '7. 개인정보의 파기 절차 및 방법',
        contents: [
          LegalContent.bullets([
            '파기 절차: 목적 달성 또는 보유기간 종료 시 내부 절차에 따라 지체 없이 파기',
            '파기 방법: 전자적 파일은 복구 불가능한 방법으로 삭제, 종이는 분쇄/소각',
          ]),
        ],
      ),
      LegalSection(
        heading: '8. 이용자의 권리와 행사 방법',
        contents: [
          LegalContent.paragraph('이용자는 언제든지 다음 권리를 행사할 수 있습니다.'),
          LegalContent.bullets(['개인정보 열람, 정정, 삭제, 처리정지 요청', '계정 삭제(탈퇴) 요청']),
          LegalContent.paragraph('행사 방법: 앱 내 설정 또는 고객센터 문의(이메일)로 요청'),
        ],
      ),
      LegalSection(
        heading: '9. 개인정보의 안전성 확보 조치',
        contents: [
          LegalContent.paragraph('사업자는 개인정보 보호를 위해 다음 조치를 수행합니다.'),
          LegalContent.bullets([
            '접근 권한 관리, 인증 및 권한 부여',
            '데이터베이스 접근 통제 및 보안 규칙 적용',
            '전송구간 암호화(HTTPS)',
            '로그 모니터링 및 부정 이용 방지',
          ]),
        ],
      ),
      LegalSection(
        heading: '10. 광고 및 맞춤형 광고(해당 시)',
        contents: [
          LegalContent.paragraph(
            '서비스는 광고를 포함할 수 있으며, 광고 제공을 위해 광고 식별자(IDFA/ADID 등) 및 이용기록이 사용될 수 있습니다. 이용자는 OS 설정에서 광고 추적 제한 또는 맞춤형 광고 설정을 변경할 수 있습니다.',
          ),
        ],
      ),
      LegalSection(
        heading: '11. 개인정보 보호책임자 및 문의처',
        contents: [
          LegalContent.bullets([
            '개인정보 보호책임자: 홍덕우',
            '문의 이메일: chikabooks.app@gmail.com',
            '사업자 정보: 치과책방',
          ]),
        ],
      ),
    ],
  );
}

// ═══════════════════════════════════════════════════════════
// 이용약관 데이터
// ═══════════════════════════════════════════════════════════

LegalPage buildTermsPage() {
  return const LegalPage(
    title: '치카북스 이용약관',
    emoji: '📄',
    effectiveDate: '2026년 3월 19일',
    sections: [
      LegalSection(
        heading: '제1조(목적)',
        contents: [
          LegalContent.paragraph(
            '본 약관은 홍덕우(이하 "사업자")가 제공하는 모바일 앱 「치카북스」 및 관련 웹페이지(이하 통칭 "서비스")의 이용과 관련하여 사업자와 회원 간 권리·의무 및 책임사항, 서비스 이용조건 및 절차를 규정함을 목적으로 합니다. 서비스는 치과책방 브랜드로 운영될 수 있습니다.',
          ),
        ],
      ),
      LegalSection(
        heading: '제2조(정의)',
        contents: [
          LegalContent.bullets([
            '"서비스"란 사업자가 모바일 앱 및 관련 웹페이지를 통해 제공하는 돌보기·성장(퀴즈 등)·공감 투표·커뮤니티·커리어(이력서·지원·구인공고)·전자책 열람·외부 연동, 광고 노출, 기타 부가 기능 일체를 말합니다.',
            '"회원"이란 본 약관에 동의하고 소셜 로그인 등으로 계정을 생성하여 서비스를 이용하는 자를 말합니다.',
            '"콘텐츠"란 회원이 서비스에 게시하는 글, 이미지, 댓글, 반응(리액션), 추대(전광판 추천) 등 일체의 게시물 및 이에 준하는 정보를 말합니다.',
            '"구인공고 등록자"란 서비스에 구인공고를 등록하는 치과 등 사업자를 말합니다.',
            '"유료서비스"란 구인공고 등록 등 사업자가 정한 대가를 지불하고 이용하는 기능을 말합니다(인앱결제 포함).',
            '"익명화"란 회원 탈퇴 시 콘텐츠의 작성자 식별정보(UID, 닉네임, 프로필 이미지 등)를 제거하거나 "탈퇴한 사용자"로 치환하여 개인을 식별할 수 없도록 하는 처리를 말합니다.',
            '"전자책 연동"이란 외부 전자상거래·이메일 등과 연계하여 구매·열람 권한을 동기화하는 기능을 말하며, 실제 매매·환불 관계는 해당 정책이 우선합니다.',
            '"공감 투표"란 일일 주제에 대해 보기를 선택하거나 보기를 추가하고, 종료 후 결과·한마디(댓글)를 남기는 기능을 말합니다.',
          ]),
        ],
      ),
      LegalSection(
        heading: '제3조(약관의 효력 및 변경)',
        contents: [
          LegalContent.bullets([
            '본 약관은 서비스 내 게시 또는 연결 화면을 통해 공지함으로써 효력이 발생합니다.',
            '사업자는 관련 법령을 위반하지 않는 범위에서 약관을 변경할 수 있으며, 변경 시 적용일 및 변경 사유를 명시하여 서비스 내 공지합니다.',
            '회원이 변경 약관에 동의하지 않을 경우 회원은 이용계약을 해지(탈퇴)할 수 있습니다.',
          ]),
        ],
      ),
      LegalSection(
        heading: '제4조(이용계약의 성립 및 계정)',
        contents: [
          LegalContent.bullets([
            '이용계약은 회원이 약관 및 개인정보처리방침에 동의하고, 사업자가 제공하는 소셜 로그인 등 인증수단을 통해 가입을 완료함으로써 성립합니다.',
            '회원은 본인 명의로만 계정을 이용해야 하며, 타인의 정보를 도용할 수 없습니다.',
            '사업자는 운영상 필요한 경우 특정 기능의 이용을 제한하거나 추가 인증을 요구할 수 있습니다.',
          ]),
        ],
      ),
      LegalSection(
        heading: '제5조(서비스 제공 및 변경)',
        contents: [
          LegalContent.paragraph('사업자는 다음 서비스를 제공합니다.'),
          LegalContent.bullets([
            '캐릭터 돌보기·상태·친밀도 등 1탭 기능',
            '퀴즈·제도·전자책 열람·내 서재 등 성장·콘텐츠 기능',
            '공감 투표·보기 추가·종료 투표 한마디(댓글)·피드 등 커뮤니티',
            '커뮤니티(글/댓글/반응/추대 등), 파트너 매칭 및 파트너 기반 기능',
            '이력서 작성·지원·구인공고 열람 및 등록(유료서비스 포함)',
            '전광판(추천·추대 기반 노출)',
            '광고 노출',
          ]),
          LegalContent.paragraph(
            '사업자는 운영상·기술상 필요에 따라 서비스의 전부 또는 일부를 변경·중단·제한할 수 있으며, 이용자에게 불리한 중요한 변경은 사전에 공지합니다. 무료로 제공되는 기능은 사업자 정책에 따라 수정·종료될 수 있습니다.',
          ),
        ],
      ),
      LegalSection(
        heading: '제5조의2(전자책·외부 연동)',
        contents: [
          LegalContent.paragraph(
            '전자책 열람·서재·구매 연동은 외부 전자상거래·이메일 연동 등을 포함할 수 있습니다. 실제 매매·결제·환불·청약철회에 관한 관계는 해당 사업자의 약관 및 정책이 우선하며, 본 서비스는 열람·연동 편의를 제공합니다.',
          ),
        ],
      ),
      LegalSection(
        heading: '제5조의3(공감 투표·한마디)',
        contents: [
          LegalContent.bullets([
            '회원은 투표 규칙 및 운영 정책에 따라 보기를 추가하거나 종료된 투표에 한마디를 남길 수 있습니다.',
            '욕설·비방·개인정보 노출 등 부적절한 내용은 삭제·제한될 수 있으며, 반복 시 이용 제한 등 조치가 있을 수 있습니다.',
          ]),
        ],
      ),
      LegalSection(
        heading: '제5조의4(이력서·지원)',
        contents: [
          LegalContent.bullets([
            '회원은 본인의 경력·학력 등 사실에 맞게 이력서를 작성해야 하며, 허위 기재에 대한 책임은 회원에게 있습니다.',
            '지원서 및 업로드 파일(PDF 등)은 구인 당사자·사업자의 운영 정책에 따라 열람·보관·삭제될 수 있습니다.',
            '사업자는 구인자와 구직자 간 채용·계약 체결의 당사자가 아니며, 그 결과에 대해 보증하지 않습니다.',
          ]),
        ],
      ),
      LegalSection(
        heading: '제6조(회원의 의무)',
        contents: [
          LegalContent.paragraph('회원은 다음 행위를 하여서는 안 됩니다.'),
          LegalContent.bullets([
            '타인의 계정 도용, 부정한 로그인 시도',
            '허위 구인공고 등록 또는 사실과 다른 정보 게시, 허위 이력서·지원',
            '공감 투표·댓글·게시물에서의 조작·어뷰징, 타인 권리 침해',
            '음란/혐오/차별/폭력/불법행위 조장 콘텐츠 게시',
            '타인을 비방하거나 명예를 훼손하는 행위',
            '서비스의 안정적 운영을 방해하는 행위(자동화/스크래핑/비정상 트래픽 등)',
            '기타 법령 또는 공서양속에 반하는 행위',
          ]),
        ],
      ),
      LegalSection(
        heading: '제7조(콘텐츠의 권리 및 이용)',
        contents: [
          LegalContent.bullets([
            '회원이 게시한 콘텐츠의 저작권은 회원에게 귀속됩니다.',
            '다만 사업자는 서비스 운영·표시·홍보·기능 제공(검색/추천/전광판 노출 등)을 위하여, 회원 콘텐츠를 서비스 내에서 복제·전송·전시·편집(형식 변환 포함)할 수 있는 비독점적·무상·전세계적 라이선스를 가집니다.',
            '회원은 언제든지 본인이 게시한 콘텐츠에 대해 삭제 또는 비공개 요청을 할 수 있으며, 사업자는 운영정책 및 관련 법령에 따라 처리합니다.',
          ]),
        ],
      ),
      LegalSection(
        heading: '제8조(전광판/추천(추대) 기능)',
        contents: [
          LegalContent.bullets([
            '전광판은 회원의 추대·반응 등 서비스 내 신호를 기반으로 콘텐츠 일부를 노출하는 기능입니다.',
            '전광판 노출 여부·순서는 운영 및 기술적 기준에 따라 결정될 수 있으며, 사업자는 이를 보장하지 않습니다.',
            '전광판 및 추천 기능 악용(조작, 비정상 반복행위 등)이 확인될 경우 사업자는 해당 콘텐츠 노출 제한, 계정 제한 등 조치를 할 수 있습니다.',
          ]),
        ],
      ),
      LegalSection(
        heading: '제9조(구인공고 및 직업정보 관련)',
        contents: [
          LegalContent.bullets([
            '사업자는 직업정보를 제공하는 플랫폼으로서, 구인공고 등록자와 회원 간 고용계약 및 그 결과(급여, 근로조건, 분쟁 등)에 대해 당사자가 아니며 이를 보증하지 않습니다.',
            '구인공고의 내용은 등록자 책임 하에 작성되며, 사업자는 필요 시 운영정책에 따라 허위·불법 공고를 제한·삭제할 수 있습니다.',
            '직업정보제공사업 관련 신고번호는 발급 완료 후 서비스 내에 고지합니다(현재 발급 진행 중).',
          ]),
        ],
      ),
      LegalSection(
        heading: '제10조(유료서비스 및 결제)',
        contents: [
          LegalContent.bullets([
            '유료서비스의 이용요금, 제공내용, 과금방식, 환불 정책은 서비스 내 별도 안내에 따릅니다.',
            '인앱결제로 결제되는 경우, 결제·환불·청약철회 등은 원칙적으로 해당 앱마켓(Apple/Google)의 정책 및 절차를 따릅니다.',
            '사업자는 부정 결제 또는 약관 위반이 의심되는 경우 결제 취소, 이용 제한 등 필요한 조치를 할 수 있습니다.',
          ]),
        ],
      ),
      LegalSection(
        heading: '제11조(광고)',
        contents: [
          LegalContent.paragraph(
            '서비스에는 광고가 포함될 수 있으며, 사업자는 광고주가 제공하는 정보 또는 광고 내용에 대해 보증하지 않습니다. 회원은 광고를 통해 연결되는 외부 사이트의 거래·이용에 대해 해당 외부 사업자와 직접 관계를 맺습니다.',
          ),
        ],
      ),
      LegalSection(
        heading: '제12조(계정 삭제 및 데이터 처리)',
        contents: [
          LegalContent.bullets([
            '회원은 설정 메뉴 등 서비스 내 절차를 통해 계정 삭제를 요청할 수 있습니다.',
            '계정 삭제 시, 회원의 개인 식별정보(계정 식별자, 이메일 등)는 삭제됩니다.',
            '이력서·업로드 파일 등 회원이 업로드한 자료는 원칙적으로 삭제 또는 익명화 조치를 시도하며, 법령·분쟁 대응에 필요한 최소 범위는 예외로 보관될 수 있습니다.',
            '다만 커뮤니티 및 파트너 기능의 연속성을 위해, 회원이 작성한 콘텐츠는 작성자 식별정보가 제거되어 "탈퇴한 사용자"로 표시되는 방식으로 익명화 처리되어 유지될 수 있습니다.',
            '법령에 따라 보관 의무가 있는 정보는 해당 법령이 정한 기간 동안 보관 후 파기합니다.',
          ]),
        ],
      ),
      LegalSection(
        heading: '제13조(서비스 이용 제한)',
        contents: [
          LegalContent.paragraph(
            '사업자는 다음 사유가 있는 경우 서비스 이용을 제한(경고, 게시물 삭제, 이용정지, 계정 정지 등)할 수 있습니다.',
          ),
          LegalContent.bullets([
            '본 약관 위반',
            '법령 위반 또는 위반 우려',
            '타인의 권리 침해',
            '서비스 운영 방해',
          ]),
        ],
      ),
      LegalSection(
        heading: '제14조(면책)',
        contents: [
          LegalContent.bullets([
            '사업자는 천재지변, 불가항력, 통신장애, 서비스 점검 등으로 인한 서비스 제공 불가에 대해 책임을 지지 않습니다(고의·중과실 제외).',
            '회원 상호 간 또는 회원과 제3자 간 분쟁은 당사자 간 해결이 원칙이며, 사업자는 법령상 요구되는 범위를 제외하고 개입하지 않습니다.',
          ]),
        ],
      ),
      LegalSection(
        heading: '제15조(준거법 및 관할)',
        contents: [
          LegalContent.paragraph(
            '본 약관은 대한민국 법령을 준거법으로 하며, 분쟁 발생 시 민사소송법상 관할법원에 따릅니다.',
          ),
        ],
      ),
    ],
  );
}
