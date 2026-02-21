import 'package:flutter/material.dart';
import '../../models/partner_preferences.dart';
import '../../services/user_profile_service.dart';

/// 파트너 선정 기준 설정 페이지
class PartnerPreferencesPage extends StatefulWidget {
  const PartnerPreferencesPage({super.key});

  @override
  State<PartnerPreferencesPage> createState() => _PartnerPreferencesPageState();
}

class _PartnerPreferencesPageState extends State<PartnerPreferencesPage> {
  bool _loading = true;
  
  PreferenceType _priority1Type = PreferenceType.career;
  String _priority1Value = 'similar';
  
  PreferenceType _priority2Type = PreferenceType.tags;
  String _priority2Value = 'similar';
  
  PreferenceType _priority3Type = PreferenceType.region;
  String _priority3Value = 'any';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await UserProfileService.getPartnerPreferences();
      if (mounted) {
        setState(() {
          _priority1Type = prefs.priority1.type;
          _priority1Value = prefs.priority1.value;
          _priority2Type = prefs.priority2.type;
          _priority2Value = prefs.priority2.value;
          _priority3Type = prefs.priority3.type;
          _priority3Value = prefs.priority3.value;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _applyPreset(PartnerPreferences preset) async {
    setState(() {
      _priority1Type = preset.priority1.type;
      _priority1Value = preset.priority1.value;
      _priority2Type = preset.priority2.type;
      _priority2Value = preset.priority2.value;
      _priority3Type = preset.priority3.type;
      _priority3Value = preset.priority3.value;
    });
    
    await _savePreferences();
  }

  Future<void> _savePreferences() async {
    try {
      final newPrefs = PartnerPreferences(
        priority1: PreferenceItem(type: _priority1Type, value: _priority1Value),
        priority2: PreferenceItem(type: _priority2Type, value: _priority2Value),
        priority3: PreferenceItem(type: _priority3Type, value: _priority3Value),
      );
      
      await UserProfileService.updatePartnerPreferences(newPrefs);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('설정이 저장되었어요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장에 실패했어요'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('파트너 선정 기준'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  
                  // 섹션 1: 프리셋
                  _buildPresetSection(),
                  
                  const Divider(height: 32),
                  
                  // 섹션 2: 우선순위
                  _buildPrioritySection(),
                  
                  const Divider(height: 32),
                  
                  // 섹션 3: 안전 안내
                  _buildSafetyNotice(),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildPresetSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '빠른 설정',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF424242),
            ),
          ),
          const SizedBox(height: 12),
          
          _buildPresetButton(
            icon: '💛',
            title: '편한 공감형',
            subtitle: '연차 가깝게 → 태그 비슷하게 → 지역 상관없음',
            onTap: () => _applyPreset(PartnerPreferences.comfortPreset()),
          ),
          
          const SizedBox(height: 8),
          
          _buildPresetButton(
            icon: '✨',
            title: '현실 조언형',
            subtitle: '높은 연차 우선 → 태그 비슷하게 → 지역 상관없음',
            onTap: () => _applyPreset(PartnerPreferences.advicePreset()),
          ),
          
          const SizedBox(height: 8),
          
          _buildPresetButton(
            icon: '🏘️',
            title: '동네 동행형',
            subtitle: '지역 가깝게 → 연차 상관없음 → 태그 상관없음',
            onTap: () => _applyPreset(PartnerPreferences.localPreset()),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF424242),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildPrioritySection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '직접 설정',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF424242),
            ),
          ),
          const SizedBox(height: 12),
          
          _buildPriorityDropdown(
            label: '우선순위 1',
            currentType: _priority1Type,
            currentValue: _priority1Value,
            onChanged: (type, value) {
              setState(() {
                _priority1Type = type;
                _priority1Value = value;
              });
            },
          ),
          
          const SizedBox(height: 12),
          
          _buildPriorityDropdown(
            label: '우선순위 2',
            currentType: _priority2Type,
            currentValue: _priority2Value,
            onChanged: (type, value) {
              setState(() {
                _priority2Type = type;
                _priority2Value = value;
              });
            },
          ),
          
          const SizedBox(height: 12),
          
          _buildPriorityDropdown(
            label: '우선순위 3',
            currentType: _priority3Type,
            currentValue: _priority3Value,
            onChanged: (type, value) {
              setState(() {
                _priority3Type = type;
                _priority3Value = value;
              });
            },
          ),
          
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savePreferences,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF1E88E5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '저장하기',
                style: TextStyle(fontSize: 15, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityDropdown({
    required String label,
    required PreferenceType currentType,
    required String currentValue,
    required Function(PreferenceType, String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<PreferenceType>(
                value: currentType,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: PreferenceType.region, child: Text('지역')),
                  DropdownMenuItem(value: PreferenceType.career, child: Text('연차')),
                  DropdownMenuItem(value: PreferenceType.tags, child: Text('태그')),
                ],
                onChanged: (type) {
                  if (type != null) {
                    String defaultValue = type == PreferenceType.tags ? 'similar' : 'any';
                    onChanged(type, defaultValue);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: currentValue,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _getValueOptions(currentType),
                onChanged: (value) {
                  if (value != null) {
                    onChanged(currentType, value);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _getValueOptions(PreferenceType type) {
    switch (type) {
      case PreferenceType.region:
        return const [
          DropdownMenuItem(value: 'nearby', child: Text('가깝게')),
          DropdownMenuItem(value: 'far', child: Text('멀게')),
          DropdownMenuItem(value: 'any', child: Text('상관없음')),
        ];
      case PreferenceType.career:
        return const [
          DropdownMenuItem(value: 'similar', child: Text('가깝게')),
          DropdownMenuItem(value: 'senior', child: Text('높은 연차 우선')),
          DropdownMenuItem(value: 'any', child: Text('상관없음')),
        ];
      case PreferenceType.tags:
        return const [
          DropdownMenuItem(value: 'similar', child: Text('비슷하게')),
          DropdownMenuItem(value: 'any', child: Text('상관없음')),
        ];
    }
  }

  Widget _buildSafetyNotice() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 20,
            color: Color(0xFF1E88E5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '지역은 크게만 참고해요.\n서로 안전한 거리가 더 중요해요.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

