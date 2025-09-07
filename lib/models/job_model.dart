// lib/models/job_model.dart
class Job {
  final String id;
  final String title;
  final String company;
  final String location;

  Job({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
  });

  factory Job.fromMap(String id, Map<String, dynamic> data) {
    return Job(
      id: id,
      title: data['title'] ?? '',
      company: data['company'] ?? '',
      location: data['location'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'title': title, 'company': company, 'location': location};
  }
}
