import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// 공고 카드/상세에 쓰는 이미지 위젯.
///
/// `Job.images` 안에는 두 가지 종류의 경로가 섞여 들어온다:
///   1) Firebase Storage 등에서 받아온 절대 URL  (예: `https://…`)
///   2) 모킹된 샘플 공고의 로컬 자산 경로        (예: `assets/clinic_pictures/…`)
///
/// 모두 [Image.network] 로 호출해 버리면 자산 경로는 404 가 떨어져
/// errorBuilder 의 회색 placeholder 만 보이게 된다(웹에서 자주 발생하는 함정).
/// 이 헬퍼는 prefix 를 보고 안전하게 분기한 뒤 동일한 placeholder 로 폴백한다.
class JobThumbImage extends StatelessWidget {
  const JobThumbImage({
    super.key,
    required this.src,
    this.iconSize = 44,
    this.fit = BoxFit.cover,
  });

  final String src;
  final double iconSize;
  final BoxFit fit;

  bool get _isNetwork =>
      src.startsWith('http://') || src.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final placeholderBuilder = (BuildContext _, Object __, StackTrace? ___) =>
        _placeholder(iconSize);
    if (_isNetwork) {
      return Image.network(src, fit: fit, errorBuilder: placeholderBuilder);
    }
    return Image.asset(src, fit: fit, errorBuilder: placeholderBuilder);
  }

  static Widget _placeholder(double iconSize) {
    return Container(
      color: AppColors.surfaceMuted,
      alignment: Alignment.center,
      child: Icon(
        Icons.business_rounded,
        size: iconSize,
        color: AppColors.textDisabled,
      ),
    );
  }

  /// 이미지를 그릴 src 가 없을 때 같은 placeholder 만 그릴 수 있게 노출.
  static Widget placeholder({double iconSize = 44}) =>
      _placeholder(iconSize);
}
