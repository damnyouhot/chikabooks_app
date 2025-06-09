import 'package:flutter/foundation.dart';

// 구직 필터의 상태를 관리할 '인테리어 디자이너'
class JobFilterNotifier extends ChangeNotifier {
  String _careerFilter = '전체'; // 기본값은 '전체'

  String get careerFilter => _careerFilter;

  // 필터 값을 변경하는 함수
  void setCareerFilter(String newFilter) {
    if (_careerFilter != newFilter) {
      _careerFilter = newFilter;
      // "상태가 변경되었으니, 나를 지켜보는 모든 위젯들아, 화면을 새로 그려라!"
      // 라고 알려주는 가장 중요한 부분입니다.
      notifyListeners();
    }
  }
}
