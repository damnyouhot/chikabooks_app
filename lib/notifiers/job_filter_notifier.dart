import 'package:flutter/material.dart';

/// 공고 목록/지도 필터 상태 관리
///
/// ## 필터 항목
/// - `positionFilter`  직종 (전체/치위생사/간호조무사/치과의사/기타)
/// - `careerFilter`    경력 (전체/신입/경력)
/// - `regionFilter`    지역 (드롭다운)
/// - `employmentType`  근무형태 (전체/풀타임/파트타임/계약직)
/// - `salaryRange`     급여 범위 (RangeSlider)
/// - `sortBy`          정렬 기준 (최신순/매칭높은순/마감임박순/급여높은순/거리순)
/// - `conditions`      기타 조건 칩 (신입가능/야간없음/주4일/파트타임/역세권/즉시지원/4대보험)
/// - `radiusKm`        지도 반경 (km)
/// - `searchQuery`     검색어
class JobFilterNotifier extends ChangeNotifier {
  // ── 목록 필터 ──────────────────────────────────────────────────
  String _positionFilter = '전체';
  String _careerFilter = '전체';
  String _regionFilter = '전체';
  String _employmentType = '전체'; // 근무형태 (신규)
  RangeValues _salaryRange = const RangeValues(0, 10000);

  // ── 정렬 ────────────────────────────────────────────────────────
  /// 정렬 옵션: 최신순 | 매칭높은순 | 마감임박순 | 급여높은순 | 거리순
  String _sortBy = '최신순';

  // ── 기타 조건 칩 ────────────────────────────────────────────────
  Set<String> _conditions = {};

  // ── 신규 필터 (1차 확장) ─────────────────────────────────────────
  String _hospitalType = '전체';
  Set<String> _selectedWorkDays = {};
  Set<String> _selectedSubwayLines = {};

  // ── 지도 전용 ────────────────────────────────────────────────────
  double _radiusKm = 3.0;

  // ── 검색어 ───────────────────────────────────────────────────────
  String _searchQuery = '';

  // ── Getters ──────────────────────────────────────────────────────
  String get positionFilter => _positionFilter;
  String get careerFilter => _careerFilter;
  String get regionFilter => _regionFilter;
  String get employmentType => _employmentType;
  RangeValues get salaryRange => _salaryRange;
  String get sortBy => _sortBy;
  Set<String> get conditions => _conditions;
  String get hospitalType => _hospitalType;
  Set<String> get selectedWorkDays => _selectedWorkDays;
  Set<String> get selectedSubwayLines => _selectedSubwayLines;
  double get radiusKm => _radiusKm;
  String get searchQuery => _searchQuery;

  /// 현재 적용된 필터 수 (검색어·반경 제외)
  int get activeCount {
    int count = 0;
    if (_positionFilter != '전체') count++;
    if (_careerFilter != '전체') count++;
    if (_regionFilter != '전체') count++;
    if (_employmentType != '전체') count++;
    if (_salaryRange.start > 0 || _salaryRange.end < 10000) count++;
    if (_sortBy != '최신순') count++;
    count += _conditions.length;
    if (_hospitalType != '전체') count++;
    count += _selectedWorkDays.length;
    count += _selectedSubwayLines.length;
    return count;
  }

  // ── Setters ──────────────────────────────────────────────────────

  void setPositionFilter(String v) {
    if (_positionFilter != v) {
      _positionFilter = v;
      notifyListeners();
    }
  }

  void setCareerFilter(String v) {
    if (_careerFilter != v) {
      _careerFilter = v;
      notifyListeners();
    }
  }

  void setRegionFilter(String v) {
    if (_regionFilter != v) {
      _regionFilter = v;
      notifyListeners();
    }
  }

  void setEmploymentType(String v) {
    if (_employmentType != v) {
      _employmentType = v;
      notifyListeners();
    }
  }

  void setSalaryRange(RangeValues v) {
    _salaryRange = v;
    notifyListeners();
  }

  void setSortBy(String v) {
    if (_sortBy != v) {
      _sortBy = v;
      notifyListeners();
    }
  }

  void setHospitalType(String v) {
    if (_hospitalType != v) {
      _hospitalType = v;
      notifyListeners();
    }
  }

  void setSelectedWorkDays(Set<String> v) {
    _selectedWorkDays = Set.from(v);
    notifyListeners();
  }

  void setSelectedSubwayLines(Set<String> v) {
    _selectedSubwayLines = Set.from(v);
    notifyListeners();
  }

  /// 기타 조건 칩 Set 전체 교체 (바텀시트 적용 시)
  void setConditions(Set<String> v) {
    _conditions = Set.from(v);
    notifyListeners();
  }

  /// 단일 조건 토글 (지도 뷰 반경 칩 등)
  void toggleCondition(String condition) {
    if (_conditions.contains(condition)) {
      _conditions.remove(condition);
    } else {
      _conditions.add(condition);
    }
    notifyListeners();
  }

  void setSearchQuery(String v) {
    if (_searchQuery != v) {
      _searchQuery = v;
      notifyListeners();
    }
  }

  void setRadiusKm(double v) {
    if (_radiusKm != v) {
      _radiusKm = v;
      notifyListeners();
    }
  }

  // ── 초기화 ──────────────────────────────────────────────────────

  void resetFilters() {
    _positionFilter = '전체';
    _careerFilter = '전체';
    _regionFilter = '전체';
    _employmentType = '전체';
    _salaryRange = const RangeValues(0, 10000);
    _sortBy = '최신순';
    _conditions.clear();
    _hospitalType = '전체';
    _selectedWorkDays.clear();
    _selectedSubwayLines.clear();
    _radiusKm = 3.0;
    notifyListeners();
  }

  void resetListFilters() {
    _positionFilter = '전체';
    _careerFilter = '전체';
    _regionFilter = '전체';
    _employmentType = '전체';
    _salaryRange = const RangeValues(0, 10000);
    _sortBy = '최신순';
    _conditions.clear();
    _hospitalType = '전체';
    _selectedWorkDays.clear();
    _selectedSubwayLines.clear();
    notifyListeners();
  }

  void resetMapFilters() {
    _radiusKm = 3.0;
    _sortBy = '최신순';
    _conditions.clear();
    notifyListeners();
  }
}









