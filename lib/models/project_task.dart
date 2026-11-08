class ProjectTask {
  final int id;
  final int projectId;
  final String title;
  final String description;
  final String priority;
  final String status;
  final String? dueDate;
  final String? driveUrl;
  final String? githubUrl;
  final String? attachmentName;
  final String? attachmentMime;
  final List<int>? attachmentBytes;
  final String? workDescription;
  final String? workLink;
  final String? workAttachmentName;
  final String? workAttachmentMime;
  final List<int>? workAttachmentBytes;
  final String? reviewNote;

  const ProjectTask({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    this.dueDate,
    this.driveUrl,
    this.githubUrl,
    this.attachmentName,
    this.attachmentMime,
    this.attachmentBytes,
    this.workDescription,
    this.workLink,
    this.workAttachmentName,
    this.workAttachmentMime,
    this.workAttachmentBytes,
    this.reviewNote,
  });

  factory ProjectTask.fromMap(Map<String, dynamic> map) => ProjectTask(
    id: map['id'] as int,
    projectId: map['project_id'] as int,
    title: map['title'] as String,
    description: map['description'] as String? ?? '',
    priority: map['priority'] as String,
    status: map['status'] as String,
    dueDate: map['due_date'] as String?,
    driveUrl: map['drive_url'] as String?,
    githubUrl: map['github_url'] as String?,
    attachmentName: map['attachment_name'] as String?,
    attachmentMime: map['attachment_mime'] as String?,
    attachmentBytes: (map['attachment_bytes'] as List?)?.cast<int>(),
    workDescription: map['work_description'] as String?,
    workLink: map['work_link'] as String?,
    workAttachmentName: map['work_attachment_name'] as String?,
    workAttachmentMime: map['work_attachment_mime'] as String?,
    workAttachmentBytes: (map['work_attachment_bytes'] as List?)?.cast<int>(),
    reviewNote: map['review_note'] as String?,
  );
}
