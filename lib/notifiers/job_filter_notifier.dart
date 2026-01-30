import 'package:flutter/material.dart';

class JobFilterNotifier extends ChangeNotifier {
  String _careerFilter = '전체';
  String _regionFilter = '전체';
  String _positionFilter = '전체'; // 직종 필터 추가
  String _searchQuery = ''; // 검색어 추가
  RangeValues _salaryRange = const RangeValues(0, 10000);

  String get careerFilter => _careerFilter;
  String get regionFilter => _regionFilter;
  String get positionFilter => _positionFilter;
  String get searchQuery => _searchQuery;
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

  void setPositionFilter(String newFilter) {
    if (_positionFilter != newFilter) {
      _positionFilter = newFilter;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      notifyListeners();
    }
  }

  void setSalaryRange(RangeValues newRange) {
    _salaryRange = newRange;
    notifyListeners();
  }

  /// 모든 필터 초기화
  void resetFilters() {
    _careerFilter = '전체';
    _regionFilter = '전체';
    _positionFilter = '전체';
    _searchQuery = '';
    _salaryRange = const RangeValues(0, 10000);
    notifyListeners();
  }
}
