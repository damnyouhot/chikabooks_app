import 'package:flutter_test/flutter_test.dart';
import 'package:chikabooks_app/features/jobs/utils/job_post_field_sync.dart';

void main() {
  group('JobPostFieldSync', () {
    test('matchCareerToDropdown maps common phrases', () {
      expect(JobPostFieldSync.matchCareerToDropdown('신입 및 경력 (0~5년)'), '신입');
      expect(JobPostFieldSync.matchCareerToDropdown('경력 무관'), '경력 무관');
      expect(JobPostFieldSync.matchCareerToDropdown('3년 이상'), '3년 이상');
    });

    test('pickEducationForStorage prefers valid primary', () {
      expect(
        JobPostFieldSync.pickEducationForStorage('전문대 졸업', ''),
        '전문대 졸업 이상',
      );
    });

    test('hireRolesFromExtract prefers hireRoles list', () {
      final m = <String, dynamic>{
        'hireRoles': ['치과위생사', '상담'],
        'role': 'ignored',
      };
      expect(JobPostFieldSync.hireRolesFromExtract(m), ['치과위생사', '상담']);
    });

    test('hireRolesFromExtract splits role when list absent', () {
      final m = <String, dynamic>{
        'role': '상담, 보험청구 담당',
      };
      expect(
        JobPostFieldSync.hireRolesFromExtract(m),
        ['상담', '보험청구 담당'],
      );
    });

    test('patchFieldStatusForFilledValues sets confirmed', () {
      final fs = {'career': 'missing', 'salary': 'inferred'};
      final out = JobPostFieldSync.patchFieldStatusForFilledValues(fs, {
        'career': true,
        'education': false,
        'salary': true,
      });
      expect(out!['career'], 'confirmed');
      expect(out['salary'], 'confirmed');
    });
  });
}
