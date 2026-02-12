import 'package:flutter/material.dart';
import '../models/job.dart';
import '../screen/jobs/job_detail_screen.dart';

// ── 디자인 팔레트 (2탭과 통일) ──
const _kAccent = Color(0xFFF7CBCA);
const _kText = Color(0xFF5D6B6B);
const _kShadow2 = Color(0xFFD5E5E5);
const _kCardBg = Colors.white;

class JobCard extends StatelessWidget {
  final Job job;
  const JobCard({super.key, required this.job});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: _kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _kShadow2, width: 0.5),
        ),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JobDetailScreen(jobId: job.id),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (job.images.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      job.images.first,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.business,
                          size: 48, color: _kText.withOpacity(0.3)),
                    ),
                  )
                else
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _kShadow2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.business,
                        size: 48, color: _kText.withOpacity(0.3)),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.clinicName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _kText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job.address,
                        style: TextStyle(
                          fontSize: 12,
                          color: _kText.withOpacity(0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${job.salaryRange[0]}~${job.salaryRange[1]}만원',
                        style: TextStyle(
                          fontSize: 13,
                          color: _kText.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: _kText,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '바로 지원',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            JobDetailScreen(jobId: job.id, autoOpenApply: true),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
}
