class UploadedFile {
  final String id; // unique id, e.g. UUID or file path
  final String name;
  final String url; // can be empty if not available
  final DateTime uploadedAt;

  UploadedFile({
    required this.id,
    required this.name,
    required this.url,
    required this.uploadedAt,
  });

  factory UploadedFile.fromJson(Map<String,dynamic> j) => UploadedFile(
    id: j['id'] ?? j['name'],
    name: j['name'],
    url: j['url'] ?? '',
    uploadedAt: DateTime.parse(j['uploadedAt'] ?? DateTime.now().toIso8601String()),
  );

  Map<String,dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'uploadedAt': uploadedAt.toIso8601String(),
  };
}
