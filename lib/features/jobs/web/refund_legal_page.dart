import 'legal_page.dart';

/// 환불·청약철회 정책 (앱 내 `/refund` — 정적 `web/refund.html`과 동일 시행일·핵심 내용 유지)
LegalPage buildRefundPage() {
  return const LegalPage(
    title: '환불 및 청약철회 정책',
    emoji: '💳',
    effectiveDate: '2026년 4월 15일',
    sections: [
      LegalSection(
        heading: '1. 적용 대상',
        contents: [
          LegalContent.paragraph(
            '본 정책은 하이진랩 웹에서 제공하는 A·B·C 클래스 등 채용공고 유료 노출 상품에 적용됩니다.',
          ),
        ],
      ),
      LegalSection(
        heading: '2. 상품 요약',
        contents: [
          LegalContent.bullets([
            'A 클래스(프리미엄): 880,000원 · 기본 10일',
            'B 클래스(추천): 440,000원 · 기본 10일',
            'C 클래스(일반): 110,000원 · 기본 10일',
          ]),
        ],
      ),
      LegalSection(
        heading: '3. 서비스 개시',
        contents: [
          LegalContent.paragraph(
            '유료상품은 디지털 노출·광고 서비스이며, 공고가 게시되면 이용이 개시된 것으로 봅니다. '
            '「전자상거래 등에서의 소비자보호에 관한 법률」에 따라 노출이 개시된 경우 청약철회가 제한될 수 있습니다.',
          ),
        ],
      ),
      LegalSection(
        heading: '4. 환불 가능',
        contents: [
          LegalContent.bullets([
            '공고가 실제 게시되기 전까지 전액 환불 요청 가능',
            '자격 확인 불가 등으로 공고 게시가 승인되지 않은 경우 전액 환불',
            '시스템 오류·중복결제 등 회사 또는 결제 시스템 귀책이 확인되는 경우',
          ]),
        ],
      ),
      LegalSection(
        heading: '5. 환불 제한',
        contents: [
          LegalContent.paragraph(
            '공고 게시·노출 시작 후 원칙적으로 환불 불가. 허위 정보 고의 제출, 악의적 반복 등에는 환불이 제한될 수 있습니다.',
          ),
        ],
      ),
      LegalSection(
        heading: '6. 신청 및 문의',
        contents: [
          LegalContent.paragraph(
            '환불 문의: chikabooks.app@gmail.com (결제일로부터 7일 이내 접수 권장). '
            '실제 환불 시점은 카드사·은행·결제대행사(토스페이먼츠) 정책에 따릅니다.',
          ),
        ],
      ),
      LegalSection(
        heading: '7. 사업자 정보',
        contents: [
          LegalContent.bullets([
            '상호: 더글라스필름 · 대표: 홍덕우',
            '사업자등록번호: 211-09-93780',
            '통신판매업 신고: 제 2026-서울강남-01300호',
            '주소: 서울시 강남구 역삼로 215 남국빌딩 2층',
          ]),
        ],
      ),
    ],
  );
}
