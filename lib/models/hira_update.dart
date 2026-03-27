import 'package:cloud_firestore/cloud_firestore.dart';

/// HIRA 수가/급여 변경 업데이트
class HiraUpdate {
  final String id;
  final String title;
  final String link;
  final DateTime publishedAt;
  final DateTime? effectiveDate; // 시행일 (null이면 미확정)
  final String topic; // 'act' or 'notice'
  final int impactScore;
  final String impactLevel; // 'HIGH', 'MID', 'LOW' (deprecated, 시행일 기준으로 변경)
  final List<String> keywords;
  final List<String> actionHints;
  final DateTime fetchedAt;
  final int commentCount;
  final String body;

  HiraUpdate({
    required this.id,
    required this.title,
    required this.link,
    required this.publishedAt,
    this.effectiveDate,
    required this.topic,
    required this.impactScore,
    required this.impactLevel,
    required this.keywords,
    required this.actionHints,
    required this.fetchedAt,
    this.commentCount = 0,
    this.body = '',
  });

  factory HiraUpdate.fromMap(String id, Map<String, dynamic> map) {
    return HiraUpdate(
      id: id,
      title: map['title'] as String? ?? '',
      link: map['link'] as String? ?? '',
      publishedAt: (map['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      effectiveDate: (map['effectiveDate'] as Timestamp?)?.toDate(),
      topic: map['topic'] as String? ?? 'notice',
      impactScore: map['impactScore'] as int? ?? 0,
      impactLevel: map['impactLevel'] as String? ?? 'LOW',
      keywords: List<String>.from(map['keywords'] ?? []),
      actionHints: List<String>.from(map['actionHints'] ?? []),
      fetchedAt: (map['fetchedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      commentCount: map['commentCount'] as int? ?? 0,
      body: map['body'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'link': link,
      'publishedAt': Timestamp.fromDate(publishedAt),
      'effectiveDate': effectiveDate != null ? Timestamp.fromDate(effectiveDate!) : null,
      'topic': topic,
      'impactScore': impactScore,
      'impactLevel': impactLevel,
      'keywords': keywords,
      'actionHints': actionHints,
      'fetchedAt': Timestamp.fromDate(fetchedAt),
      'commentCount': commentCount,
      'body': body,
    };
  }

  /// 시행일 기준 배지 레벨 계산
  String getBadgeLevel() {
    if (effectiveDate == null) return 'NOTICE'; // 사전공지
    
    final today = DateTime.now();
    final effectiveDay = DateTime(effectiveDate!.year, effectiveDate!.month, effectiveDate!.day);
    final daysUntil = effectiveDay.difference(DateTime(today.year, today.month, today.day)).inDays;
    
    if (daysUntil <= 0) return 'ACTIVE'; // 시행 중
    if (daysUntil <= 30) return 'SOON'; // 30일 이내
    if (daysUntil <= 90) return 'UPCOMING'; // 90일 이내
    return 'NOTICE'; // 사전공지
  }

  /// 배지 텍스트 계산
  String getBadgeText() {
    final level = getBadgeLevel();
    if (level == 'ACTIVE') return '시행 중';
    if (level == 'NOTICE') return '사전공지';
    
    final today = DateTime.now();
    final effectiveDay = DateTime(effectiveDate!.year, effectiveDate!.month, effectiveDate!.day);
    final daysUntil = effectiveDay.difference(DateTime(today.year, today.month, today.day)).inDays;
    return 'D-${daysUntil.toString().padLeft(2, '0')}';
  }
}

/// 심평원 보험인정기준 검색 결과 (Cloud Function 프록시)
class HiraSearchResult {
  final String category;
  final String reference;
  final String title;
  final String link;
  final String date;
  final int views;

  HiraSearchResult({
    required this.category,
    required this.reference,
    required this.title,
    required this.link,
    required this.date,
    required this.views,
  });

  factory HiraSearchResult.fromMap(Map<String, dynamic> map) {
    return HiraSearchResult(
      category: map['category'] as String? ?? '',
      reference: map['reference'] as String? ?? '',
      title: map['title'] as String? ?? '',
      link: map['link'] as String? ?? '',
      date: map['date'] as String? ?? '',
      views: (map['views'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 심평원 검색 탭 (분류 칩용: id = tabGbn)
class HiraSearchTabInfo {
  final String id;
  final String label;
  final int count;

  HiraSearchTabInfo({
    required this.id,
    required this.label,
    required this.count,
  });

  factory HiraSearchTabInfo.fromMap(Map<String, dynamic> map) {
    return HiraSearchTabInfo(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      count: (map['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class HiraSearchResponse {
  /// 현재 필터(전체 또는 단일 탭) 기준 총건수·페이지 계산용
  final int totalCount;
  /// 전 탭 합산 (분류 칩 「전체 N건」 표시용)
  final int totalAllCount;
  final int page;
  final int perPage;
  final List<HiraSearchResult> results;
  final Map<String, int> tabCounts;
  final List<HiraSearchTabInfo> tabs;
  /// 탭id → 결과 목록 (로컬 필터링용)
  final Map<String, List<HiraSearchResult>> tabResults;

  HiraSearchResponse({
    required this.totalCount,
    int? totalAllCount,
    required this.page,
    this.perPage = 30,
    required this.results,
    required this.tabCounts,
    this.tabs = const [],
    this.tabResults = const {},
  }) : totalAllCount = totalAllCount ?? totalCount;

  factory HiraSearchResponse.fromMap(Map<String, dynamic> map) {
    final resultsList = (map['results'] as List<dynamic>?)
            ?.map((e) => HiraSearchResult.fromMap(
                Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
    final rawTabs = map['tabCounts'] as Map?;
    final tabCounts = <String, int>{};
    if (rawTabs != null) {
      for (final e in rawTabs.entries) {
        tabCounts[e.key.toString()] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    List<HiraSearchTabInfo> tabs = [];
    final rawTabList = map['tabs'] as List<dynamic>?;
    if (rawTabList != null) {
      tabs = rawTabList
          .map((e) => HiraSearchTabInfo.fromMap(
              Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    // tabResults 파싱
    final tabResults = <String, List<HiraSearchResult>>{};
    final rawTabResults = map['tabResults'] as Map?;
    if (rawTabResults != null) {
      for (final e in rawTabResults.entries) {
        final list = (e.value as List<dynamic>?)
                ?.map((item) => HiraSearchResult.fromMap(
                    Map<String, dynamic>.from(item as Map)))
                .toList() ??
            [];
        tabResults[e.key.toString()] = list;
      }
    }
    final tc = (map['totalCount'] as num?)?.toInt() ?? 0;
    final tac = (map['totalAllCount'] as num?)?.toInt();
    return HiraSearchResponse(
      totalCount: tc,
      totalAllCount: tac,
      page: (map['page'] as num?)?.toInt() ?? 1,
      perPage: (map['perPage'] as num?)?.toInt() ?? 30,
      results: resultsList,
      tabCounts: tabCounts,
      tabs: tabs,
      tabResults: tabResults,
    );
  }
}

/// 수가 조회 결과 (data.go.kr API)
class FeeScheduleItem {
  final String code;           // 수가코드 (예: U2221)
  final String codeName;       // 행위명칭
  final String category;       // 분류번호
  final double relativeValue;  // 상대가치점수
  final int unitPrice;         // 대표 단가 (원)
  final int priceClinic;       // 의원 단가
  final int priceHospital;     // 병원 단가
  final int priceGeneral;      // 종합병원 단가
  final int priceAdvanced;     // 상급종합 단가
  final String payType;        // 급여구분 (급여/비급여)
  final String startDate;      // 적용시작일
  final String note;           // 비고 (소분류)

  FeeScheduleItem({
    required this.code,
    required this.codeName,
    required this.category,
    required this.relativeValue,
    required this.unitPrice,
    this.priceClinic = 0,
    this.priceHospital = 0,
    this.priceGeneral = 0,
    this.priceAdvanced = 0,
    this.payType = '',
    required this.startDate,
    this.note = '',
  });

  factory FeeScheduleItem.fromMap(Map<String, dynamic> map) {
    return FeeScheduleItem(
      code: map['code']?.toString() ?? '',
      codeName: map['codeName']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      relativeValue: (map['relativeValue'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (map['unitPrice'] as num?)?.toInt() ?? 0,
      priceClinic: (map['priceClinic'] as num?)?.toInt() ?? 0,
      priceHospital: (map['priceHospital'] as num?)?.toInt() ?? 0,
      priceGeneral: (map['priceGeneral'] as num?)?.toInt() ?? 0,
      priceAdvanced: (map['priceAdvanced'] as num?)?.toInt() ?? 0,
      payType: map['payType']?.toString() ?? '',
      startDate: map['startDate']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
    );
  }
}

class FeeSearchResponse {
  final int totalCount;
  final int page;
  final int perPage;
  final List<FeeScheduleItem> items;

  FeeSearchResponse({
    required this.totalCount,
    required this.page,
    required this.perPage,
    required this.items,
  });

  factory FeeSearchResponse.fromMap(Map<String, dynamic> map) {
    final list = (map['items'] as List<dynamic>?)
            ?.map((e) =>
                FeeScheduleItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];
    return FeeSearchResponse(
      totalCount: map['totalCount'] as int? ?? 0,
      page: map['page'] as int? ?? 1,
      perPage: map['perPage'] as int? ?? 20,
      items: list,
    );
  }
}

/// HIRA Digest (오늘의 상위 3건)
class HiraDigest {
  final String dateKey; // YYYY-MM-DD
  final List<String> topIds;
  final DateTime generatedAt;

  HiraDigest({
    required this.dateKey,
    required this.topIds,
    required this.generatedAt,
  });

  factory HiraDigest.fromMap(String dateKey, Map<String, dynamic> map) {
    return HiraDigest(
      dateKey: dateKey,
      topIds: List<String>.from(map['topIds'] ?? []),
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'topIds': topIds,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }
}

/// HIRA 댓글
class HiraComment {
  final String id;
  final String uid;
  final String userName;
  final String text;
  final DateTime createdAt;

  HiraComment({
    required this.id,
    required this.uid,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  factory HiraComment.fromMap(String id, Map<String, dynamic> map) {
    return HiraComment(
      id: id,
      uid: map['uid'] as String? ?? '',
      userName: map['userName'] as String? ?? '익명',
      text: map['text'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'userName': userName,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'isDeleted': false,
    };
  }
}

