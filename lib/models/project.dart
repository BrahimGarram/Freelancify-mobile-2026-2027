class Project {
  final int id;
  final int candidatureId;
  final int postId;
  final int clientId;
  final int freelancerId;
  final String title;
  final String description;
  final String? deadline;
  final String status;
  final int totalTasks;
  final int validatedTasks;
  final String? clientUsername;
  final String? freelancerUsername;

  const Project({
    required this.id,
    required this.candidatureId,
    required this.postId,
    required this.clientId,
    required this.freelancerId,
    required this.title,
    required this.description,
    this.deadline,
    required this.status,
    this.totalTasks = 0,
    this.validatedTasks = 0,
    this.clientUsername,
    this.freelancerUsername,
  });

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as int,
      candidatureId: map['candidature_id'] as int,
      postId: map['post_id'] as int,
      clientId: map['client_id'] as int,
      freelancerId: map['freelancer_id'] as int,
      title: map['title'] as String,
      description: map['description'] as String,
      deadline: map['deadline'] as String?,
      status: map['status'] as String,
      totalTasks: (map['total_tasks'] as num?)?.toInt() ?? 0,
      validatedTasks: (map['validated_tasks'] as num?)?.toInt() ?? 0,
      clientUsername: map['client_username'] as String?,
      freelancerUsername: map['freelancer_username'] as String?,
    );
  }

  int get progress =>
      totalTasks == 0 ? 0 : ((validatedTasks / totalTasks) * 100).round();
}
