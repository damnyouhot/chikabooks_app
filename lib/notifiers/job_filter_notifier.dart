import 'package:flutter/material.dart';

class JobFilterNotifier extends ChangeNotifier {
  String _careerFilter = '전체';
  String _regionFilter = '전체';
  String _positionFilter = '전체'; // 직종 필터
  String _searchQuery = ''; // 검색어
  RangeValues _salaryRange = const RangeValues(0, 10000);

  // ★ 새로 추가: 지도 전용 필터
  double _radiusKm = 3.0; // 반경 (기본 3km)
  String _sortBy = '거리순'; // 정렬: 거리순/최신순/급여순
  Set<String> _conditions = {}; // 조건칩: 신입가능, 야간없음, 주4일, 파트타임

  String get careerFilter => _careerFilter;
  String get regionFilter => _regionFilter;
  String get positionFilter => _positionFilter;
  String get searchQuery => _searchQuery;
  RangeValues get salaryRange => _salaryRange;
  double get radiusKm => _radiusKm;
  String get sortBy => _sortBy;
  Set<String> get conditions => _conditions;

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

  // ★ 새 필터 setter들
  void setRadiusKm(double radius) {
    if (_radiusKm != radius) {
      _radiusKm = radius;
      notifyListeners();
    }
  }

  void setSortBy(String sortType) {
    if (_sortBy != sortType) {
      _sortBy = sortType;
      notifyListeners();
    }
  }

  void toggleCondition(String condition) {
    if (_conditions.contains(condition)) {
      _conditions.remove(condition);
    } else {
      _conditions.add(condition);
    }
    notifyListeners();
  }

  /// 모든 필터 초기화
  void resetFilters() {
    _careerFilter = '전체';
    _regionFilter = '전체';
    _positionFilter = '전체';
    _searchQuery = '';
    _salaryRange = const RangeValues(0, 10000);
    _radiusKm = 3.0;
    _sortBy = '거리순';
    _conditions.clear();
    notifyListeners();
  }

  /// 지도 전용 필터만 초기화
  void resetMapFilters() {
    _radiusKm = 3.0;
    _sortBy = '거리순';
    _conditions.clear();
    notifyListeners();
  }

  /// 목록 전용 필터만 초기화
  void resetListFilters() {
    _careerFilter = '전체';
    _regionFilter = '전체';
    _positionFilter = '전체';
    _searchQuery = '';
    _salaryRange = const RangeValues(0, 10000);
    notifyListeners();
  }
}
