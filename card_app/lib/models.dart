// lib/models.dart
class CardModel {
  final int? id;
  String title;
  String content;
  String? imageUrl; // 新增：图片的 URL
  bool isMarked;
  
  String groupName;
  String tags;
  DateTime createdAt;

  String reminderType; 
  String reminderValue; 
  DateTime? lastReviewed;

  CardModel({
    this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    this.isMarked = false,
    this.groupName = '默认清单',
    this.tags = '',
    required this.createdAt,
    this.reminderType = 'none',
    this.reminderValue = '',
    this.lastReviewed,
  });

  DateTime? get nextReminderTime {
    if (reminderType == 'none') return null;
    if (reminderType == 'specific' && reminderValue.isNotEmpty) {
      try { return DateTime.parse(reminderValue); } catch (e) { return null; }
    }
    if (reminderType == 'periodic' && reminderValue.isNotEmpty && lastReviewed != null) {
      final days = int.tryParse(reminderValue) ?? 0;
      return lastReviewed!.add(Duration(days: days));
    }
    return null;
  }

  bool get isDue {
    final next = nextReminderTime;
    if (next == null) return false;
    return DateTime.now().isAfter(next);
  }

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'],
      title: json['title'],
      content: json['content'] ?? '',
      imageUrl: json['image_url'], // 后端返回的是完整 URL
      isMarked: json['is_marked'] ?? false,
      groupName: json['group_name'] ?? '默认清单',
      tags: json['tags'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      reminderType: json['reminder_type'] ?? 'none',
      reminderValue: json['reminder_value'] ?? '',
      lastReviewed: json['last_reviewed'] != null ? DateTime.parse(json['last_reviewed']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      // 注意：这里不传 imageUrl，因为图片上传逻辑是分离的，只传 image_path (文件名)
      // 这个逻辑在 api_service 或 main.dart 里处理
      'is_marked': isMarked,
      'group_name': groupName,
      'tags': tags,
      'reminder_type': reminderType,
      'reminder_value': reminderValue,
    };
  }
}