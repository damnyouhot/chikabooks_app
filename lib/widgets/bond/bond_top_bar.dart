import 'package:flutter/material.dart';
import '../../pages/settings/communion_profile_page.dart';
import 'bond_colors.dart';

/// 결 탭 상단 타이틀 바
class BondTopBar extends StatelessWidget {
  final VoidCallback onSettingsLongPress;

  const BondTopBar({
    super.key,
    required this.onSettingsLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const Text(
            '결',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: BondColors.kText,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CommunionProfilePage(),
              ),
            ),
            onLongPress: onSettingsLongPress,
            child: Icon(
              Icons.settings_outlined,
              color: BondColors.kText.withOpacity(0.4),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

