import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/user_public_profile.dart';
import '../../services/user_profile_service.dart';

const List<String> _randomNicknameSuggestions = [
  '스케일링중독자',
  '치은여왕',
  '어금니의비밀',
  '멸균요정',
  '핸드피스마스터',
  '버티는치위생',
  '야근의전설',
  '인상채득러버',
  '치경거울요정',
  '소독실의숨결',
  '핀셋천재',
  '레진수호자',
  '기구정리장인',
  '체어위의철학자',
  '치은선지킴이',
  '석션장인',
  '물분사요정',
  '진료실탐험가',
  '멘탈마취전문',
  '스케일링왕자',
  '칫솔들고철학',
  '레진빛광채',
  '초음파의속삭임',
  '교합의운명',
  '기구트레이요정',
  '진료실생존자',
  '차트의그림자',
  '스케일링한숨',
  '치과의밤바람',
  '멘탈스케일링',
  '실습의추억',
  '소독실은나의것',
  '치은빛노을',
  '체어사이드고수',
  '석션한모금',
  '인상재사랑해',
  '근무표전사',
  '점심은없다',
  '퇴근을꿈꾸는자',
  '치위생감성',
  '사랑니헌터',
  '교정의미학',
  '진료실시인',
  '환자컴플레인버티기',
  '엑스레이철학',
  '치경거울반사광',
  '기구닦는낭만',
  '퇴사고민중',
  '치은의봄',
  '스케일링마법사',
  '석션에진심',
  '기구정렬장인',
  '레진냄새추억',
  '체어위의현실',
  '인상채득장인',
  '마스크속미소',
  '초년차의버팀목',
  '치과의푸른밤',
  '기구트레이장군',
  '물분사중독',
  '소독실낭만',
  '진료실한숨',
  '환자응대전문',
  '차트는나의일기',
  '스케일링감성러',
  '치은빛요정',
  '멸균마스터',
  '핸드피스달인',
  '레진의온도',
  '교합을믿는자',
  '체어의여운',
  '사랑니사냥꾼',
  '근무표의노예',
  '진료실버티기',
  '소독실철학자',
  '인상재와함께',
  '퇴근은신기루',
  '치위생낭만러',
  '치은선따라걷기',
  '스케일링의달',
  '교정의속삭임',
  '환자컴플레인내성자',
  '멘탈관리장인',
  '기구정리요정',
  '초음파전설',
  '체어사이드낭만',
  '인상채득러',
  '레진빛감성',
  '소독실요정',
  '야간진료전사',
  '치과의한숨',
  '핸드피스의노래',
  '퇴사각재는중',
  '근무표탐험가',
  '석션의온기',
  '치위생청춘',
  '체어위버티기',
  '레진빛아침',
  '치은선감성',
  '인상재마스터',
  '초년차의철학',
  '사랑니와나',
  '교합감별사',
  '멘탈체어사이드',
  '기구정리전문',
  '환자대기실낭만',
  '소독실속삭임',
  '레진향기',
  '체어위의봄',
  '퇴근요정',
  '치위생한페이지',
  '스케일링의여백',
  '근무표속낭만',
  '초음파의파동',
  '치은의기억',
  '기구트레이의별',
  '진료실밤공기',
  '인상재빛노을',
  '석션의리듬',
  '레진빛기억',
  '체어위철인',
  '사랑니사색',
  '치위생감각러',
  '멸균속평화',
  '핸드피스낭만',
  '초년차버티기',
  '교합의균형',
  '진료실감성러',
  '소독실바람',
  '레진빛한숨',
  '퇴근은언제쯤',
  '체어위몽상가',
  '기구닦는철학',
  '환자응대달인',
  '치은선수호자',
  '스케일링집착러',
  '인상채득감성',
  '초음파요정',
  '근무표연구자',
  '사랑니연대기',
  '레진빛청춘',
  '치위생기록자',
  '진료실버티는자',
  '석션리듬감',
  '소독실낮달',
  '핸드피스연주자',
  '체어위감정선',
  '교합수집가',
  '치은의노을',
  '퇴근이먼날',
  '초년차이야기',
  '레진빛밤공기',
  '진료실관찰자',
  '기구정렬요정',
  '인상재낭만',
  '스케일링속삭임',
  '환자응대철학',
  '치위생감성장인',
  '체어위기다림',
  '사랑니전설',
  '소독실아침빛',
  '멘탈핸드피스',
  '교합수호자',
  '진료실여운',
  '레진빛미소',
  '초음파기억',
  '기구트레이꿈',
  '근무표사색',
  '치은의별',
  '퇴근의빛',
  '체어위청춘',
  '사랑니탐험가',
  '인상채득노을',
  '스케일링고수',
  '소독실버팀목',
  '핸드피스감성',
  '레진빛요정',
  '진료실청춘러',
  '치위생밤공기',
  '교합장인',
  '멘탈석션',
  '체어위시인',
  '사랑니감별사',
  '인상재빛청춘',
  '소독실은밀한자',
  '레진향기러버',
  '초음파감성',
  '치은빛연대기',
  '진료실리듬',
  '퇴근의기적',
  '체어위단단함',
  '스케일링감각',
  '기구정리명상',
  '레진빛하루',
  '사랑니철학',
  '소독실몽상가',
  '초년차감성러',
  '치은선연구자',
  '교합속이야기',
  '퇴근대기중',
  '체어위달빛',
  '스케일링집요러',
  '레진빛고백',
  '기구트레이감성',
  '사랑니관찰자',
  '소독실파수꾼',
  '초음파속삭임러',
  '치은빛온기',
  '진료실잔상',
  '퇴근의노래',
  '체어위한숨러',
  '스케일링마음',
  '레진빛잔향',
  '기구닦는낮달',
  '사랑니수호자',
  '소독실감각',
  '교합감성러',
  '치위생연대기',
  '진료실청춘록',
  '퇴근예정자',
  '체어위미세먼지',
  '스케일링감성인',
  '레진빛몽상',
  '기구정리속삭임',
  '사랑니빛노을',
  '소독실달빛',
  '초년차속기록',
  '치은빛장면',
  '진료실낮달',
  '퇴근카운트중',
  '체어위고요',
  '스케일링여운',
  '레진빛봄날',
  '기구트레이숨결',
  '사랑니기록자',
  '소독실온기',
  '교합속청춘',
  '치위생별빛',
  '진료실감정선',
  '퇴근러',
  '체어위온도',
  '스케일링빛결',
  '레진빛파도',
  '기구닦는밤',
  '사랑니낭만러',
  '소독실빛결',
  '초음파기억자',
  '치은빛소리',
  '진료실은하수',
  '퇴근을기다림',
  '체어위흔적',
  '스케일링바람',
  '레진빛흐름',
  '기구트레이여백',
  '사랑니별',
  '소독실감성인',
  '교합빛여운',
  '치위생밤빛',
  '진료실기류',
  '퇴근희망',
  '체어위순간',
  '스케일링장면',
  '레진빛낮달',
  '기구닦는빛',
  '사랑니속삭임',
  '소독실파동',
  '초년차청춘',
  '치은빛잔상',
  '진료실풍경',
  '퇴근직전',
  '체어위별빛',
  '스케일링여백러',
  '레진빛물결',
  '기구정리낮빛',
  '사랑니여운',
  '소독실빛노을',
  '교합속바람',
  '치위생하루',
  '진료실조각',
  '퇴근소망',
  '체어위미소',
  '스케일링기억자',
  '레진빛숨',
  '기구트레이파도',
  '사랑니빛',
  '소독실달',
  '초년차빛결',
  '치은빛연결',
  '진료실잔향',
  '퇴근중독',
  '체어위서사',
  '스케일링감성자',
  '레진빛하늘',
  '기구닦는꿈',
  '사랑니빛결',
  '소독실별빛',
  '교합빛',
  '치위생흔적',
  '진료실바람결',
  '퇴근은언젠가',
  '퇴사각',
  '퇴사요정',
  '월급실화',
  '야근러',
  '체어노예',
  '밥안줌',
  '버팀러',
  '근무중독',
  '석션러',
  '레진러',
  '인상러',
  '치은빛',
  '멘탈빵',
  '월급루팡',
  '퇴근러',
  '체어인생',
  '사랑니',
  '마취장인',
  '스켈장인',
  '소독러',
  '핸피러',
  '초음파',
  '기구러',
  '체어꾼',
  '멸균러',
  '퇴근각',
  '진료러',
  '한숨러',
  '야간러',
  '번아웃',
  '환자빔',
  '퇴사빔',
  '체어빛',
  '월급빔',
  '레진빛',
  '석션빛',
  '초년러',
  '연차쌓기',
  '월급짱',
  '야근짱',
  '체어짱',
  '퇴사짱',
  '소독짱',
  '핸피짱',
  '스켈짱',
  '멘탈짱',
  '퇴사러',
  '월급러',
  '체어러',
  '야근빛',
  '체어봄',
  '퇴근봄',
  '월급봄',
  '멘탈봄',
  '레진봄',
  '스켈봄',
  '퇴사봄',
  '체어밤',
  '야근밤',
  '월급밤',
  '멘탈밤',
  '퇴사밤',
  '체어낮',
  '야근낮',
  '월급낮',
  '퇴근낮',
  '체어꿈',
  '야근꿈',
  '월급꿈',
  '퇴사꿈',
  '체어행',
  '야근행',
  '월급행',
  '퇴근행',
  '체어러',
  '스켈러',
  '레진짱',
  '석션짱',
  '소독빛',
  '체어빛',
  '멘탈러',
  '체어짤',
  '월급짤',
  '퇴근짤',
  '야근짤',
  '체어각',
  '월급각',
  '퇴사각',
  '멘탈각',
  '체어킵',
  '월급킵',
  '퇴근킵',
  '야근킵',
  '체어픽',
  '월급픽',
  '퇴사픽',
  '체어템',
  '월급템',
  '퇴사템',
  '야근템',
  '체어봇',
  '월급봇',
  '퇴사봇',
  '야근봇',
  '체어몬',
  '월급몬',
  '퇴사몬',
  '야근몬',
  '체어킹',
  '월급킹',
  '퇴사킹',
  '야근킹',
  '체어맛',
  '월급맛',
  '퇴사맛',
  '야근맛',
  '체어핏',
  '월급핏',
  '퇴사핏',
  '야근핏',
  '체어충',
  '월급충',
  '퇴사충',
  '야근충',
  '체어썸',
  '월급썸',
  '퇴사썸',
  '야근썸',
  '체어덕',
  '월급덕',
  '퇴사덕',
  '야근덕',
  '체어킴',
  '월급킴',
  '퇴사킴',
  '야근킴',
  '체어쨈',
  '월급쨈',
  '퇴사쨈',
  '야근쨈',
  '체어탑',
  '월급탑',
  '퇴사탑',
  '야근탑',
  '체어쿨',
  '월급쿨',
  '퇴사쿨',
  '야근쿨',
  '체어핫',
  '월급핫',
  '퇴사핫',
  '야근핫',
  '체어톡',
  '월급톡',
  '퇴사톡',
  '야근톡',
  '체어짱',
  '월급짱',
  '퇴사짱',
  '야근짱',
  '체어박',
  '월급박',
  '퇴사박',
  '야근박',
  '체어곰',
  '월급곰',
  '퇴사곰',
  '야근곰',
  '체어냥',
  '월급냥',
  '퇴사냥',
  '야근냥',
  '체어삐',
  '월급삐',
  '퇴사삐',
  '야근삐',
  '체어링',
  '월급링',
  '퇴사링',
  '야근링',
  '체어붐',
  '월급붐',
  '퇴사붐',
  '야근붐',
  '체어쭈',
  '월급쭈',
  '퇴사쭈',
  '야근쭈',
  '체어삥',
  '월급삥',
  '퇴사삥',
  '야근삥',
  '체어킁',
  '월급킁',
  '퇴사킁',
  '야근킁',
  '체어팡',
  '월급팡',
  '퇴사팡',
  '야근팡',
  '체어퐁',
  '월급퐁',
  '퇴사퐁',
  '야근퐁',
  '체어후',
  '월급후',
  '퇴사후',
  '야근후',
  '체어쿵',
  '월급쿵',
  '퇴사쿵',
  '야근쿵',
  '체어뿅',
  '월급뿅',
  '퇴사뿅',
  '야근뿅',
  '체어링',
  '월급링',
  '퇴사링',
  '야근링',
  '체어쭉',
  '월급쭉',
  '퇴사쭉',
  '야근쭉',
  '체어슉',
  '월급슉',
  '퇴사슉',
  '야근슉',
  '체어킥',
  '월급킥',
  '퇴사킥',
  '야근킥',
  '체어삑',
  '월급삑',
  '퇴사삑',
  '야근삑',
  '체어팟',
  '월급팟',
  '퇴사팟',
  '야근팟',
  '체어윙',
  '월급윙',
  '퇴사윙',
  '야근윙',
  '체어캬',
  '월급캬',
  '퇴사캬',
  '야근캬',
  '체어크',
  '월급크',
  '퇴사크',
  '야근크',
  '체어힝',
  '월급힝',
  '퇴사힝',
  '야근힝',
  '체어뀨',
  '월급뀨',
  '퇴사뀨',
  '야근뀨',
  '체어롱',
  '월급롱',
  '퇴사롱',
  '야근롱',
  '체어쫑',
  '월급쫑',
  '퇴사쫑',
  '야근쫑',
  '체어짹',
  '월급짹',
  '퇴사짹',
  '야근짹',
  '체어빡',
  '월급빡',
  '퇴사빡',
  '야근빡',
  '체어헉',
  '월급헉',
  '퇴사헉',
  '야근헉',
  '체어후',
  '월급후',
  '퇴사후',
  '야근후',
  '체어앗',
  '월급앗',
  '퇴사앗',
  '야근앗',
  '체어휴',
  '월급휴',
  '퇴사휴',
  '야근휴',
  '체어띵',
  '월급띵',
  '퇴사띵',
  '야근띵',
  '체어쿨',
  '월급쿨',
  '퇴사쿨',
  '야근쿨',
];


/// 최초 로그인 후 온보딩 프로필 설정 화면
/// 전체 화면을 덮는 풀스크린 형태
class OnboardingProfileScreen extends StatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  State<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen> {
  final _nicknameCtrl = TextEditingController();
  String? _selectedCareer;
  String? _selectedRegion;
  final Set<String> _selectedConcerns = {};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  void _generateRandomNickname() {
    final rng = Random();
    final nickname =
        _randomNicknameSuggestions[rng.nextInt(_randomNicknameSuggestions.length)];
    _nicknameCtrl.text = nickname;
    setState(() {});
  }

  void _toggleConcern(String concern) {
    setState(() {
      if (_selectedConcerns.contains(concern)) {
        _selectedConcerns.remove(concern);
      } else {
        if (_selectedConcerns.length < 3) {
          _selectedConcerns.add(concern);
        }
      }
    });
  }

  bool get _canComplete {
    final trimmed = _nicknameCtrl.text.trim();
    return trimmed.isNotEmpty &&
        trimmed.length <= 7 &&
        _selectedCareer != null &&
        _selectedRegion != null &&
        !_saving;
  }

  Future<void> _complete() async {
    if (!_canComplete) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await UserProfileService.completeOnboarding(
        nickname: _nicknameCtrl.text.trim(),
        region: _selectedRegion!,
        careerGroup: _selectedCareer!,
        concernTags: _selectedConcerns.toList(),
      );

      if (mounted) {
        Navigator.of(context).pop(true); // 성공 시 true 반환
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '저장 실패: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '나중에',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ),
        leadingWidth: 70,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ━━━━━━━━━━ 메인 타이틀 ━━━━━━━━━━
                    Center(
                      child: Text(
                        '가벼운 소통을 위해\n나의 캐릭터를 설정해요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D2D2D),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '원하면 노출되지 않고 바꿀 수도 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ━━━━━━━━━━ 1단계: 닉네임 ━━━━━━━━━━
                    _buildSectionTitle('닉네임'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nicknameCtrl,
                            maxLength: 7,
                            style: TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '1~7자',
                              hintStyle: TextStyle(fontSize: 13),
                              counterText: '',
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            onPressed: _generateRandomNickname,
                            icon: const Text('🎲', style: TextStyle(fontSize: 18)),
                            tooltip: '랜덤 닉네임',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ━━━━━━━━━━ 2단계: 연차 ━━━━━━━━━━
                    _buildSectionTitle('연차'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: UserPublicProfile.careerGroups.map((career) {
                        final selected = _selectedCareer == career;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCareer = career),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF6A5ACD)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF6A5ACD)
                                    : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              career,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.grey[700],
                                fontSize: 12,
                                fontWeight:
                                    selected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // ━━━━━━━━━━ 3단계: 지역군 ━━━━━━━━━━
                    _buildSectionTitle('지역군'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: UserPublicProfile.regionList.map((region) {
                        final selected = _selectedRegion == region;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedRegion = region),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF6A5ACD)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF6A5ACD)
                                    : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              region,
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.grey[700],
                                fontSize: 12,
                                fontWeight:
                                    selected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // ━━━━━━━━━━ 4단계: 관심사 ━━━━━━━━━━
                    _buildSectionTitle('관심사 (최대 3개)'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: UserPublicProfile.concernOptions.map((concern) {
                        final selected = _selectedConcerns.contains(concern);
                        final isSpecial = concern == '비밀로 할래요' ||
                            concern == '딱히 없음';
                        return GestureDetector(
                          onTap: () => _toggleConcern(concern),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? (isSpecial
                                      ? const Color(0xFFE8DAFF)
                                      : const Color(0xFF6A5ACD))
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? (isSpecial
                                        ? const Color(0xFFE8DAFF)
                                        : const Color(0xFF6A5ACD))
                                    : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              concern,
                              style: TextStyle(
                                color: selected
                                    ? (isSpecial
                                        ? const Color(0xFF6A5ACD)
                                        : Colors.white)
                                    : Colors.grey[700],
                                fontSize: 12,
                                fontWeight:
                                    selected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // 선택된 개수 표시
                    if (_selectedConcerns.isNotEmpty)
                      Center(
                        child: Text(
                          '${_selectedConcerns.length}/3 선택됨',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // ━━━━━━━━━━ 에러 메시지 ━━━━━━━━━━
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),

            // ━━━━━━━━━━ 완료 버튼 (하단 고정) ━━━━━━━━━━
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _canComplete ? _complete : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A5ACD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '시작할게요',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text('🌟', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2D2D2D),
      ),
    );
  }
}


