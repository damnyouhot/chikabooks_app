import 'package:flutter/material.dart';

/// [RouteAware] 구독용 — 예: `/post-job/input`에서 상위 라우트 pop 시 폼 리셋
final appRouteObserver = RouteObserver<ModalRoute<void>>();
