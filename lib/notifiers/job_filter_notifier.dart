import 'package:flutter/material.dart';

class JobFilterNotifier extends ChangeNotifier {
  String _careerFilter = '전체';
  String _regionFilter = '전체'; // ◀◀◀ 지역 필터 상태 추가
  RangeValues _salaryRange = const RangeValues(0, 10000); // ◀◀◀ 급여 범위 상태 추가

  String get careerFilter => _careerFilter;
  String get regionFilter => _regionFilter;
  RangeValues get salaryRange => _salaryRange;

  void setCareerFilter(String newFilter) {
    if (_careerFilter != newFilter) {
      _careerFilter = newFilter;
      notifyListeners();
    }
  }

  void setRegionFilter(String newFilter) {
    if (_regionFilter != newFilter) {
      _regionFilter = newFilter;
      notifyListeners();
    }
  }

  void setSalaryRange(RangeValues newRange) {
    _salaryRange = newRange;
    notifyListeners();
  }
}
