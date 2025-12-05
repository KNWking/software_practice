class CardModel {
  final int? id;
  String title;
  String content;
  bool isMarked;
  
  // 提醒类型: 'none', 'periodic', 'specific'
  String reminderType; 
  String reminderValue; 
  DateTime? lastReviewed;

  CardModel({
    this.id,
    required this.title,
    required this.content,
    this.isMarked = false,
    this.reminderType = 'none',
    this.reminderValue = '',
    this.lastReviewed,
  });

  // 判断是否过期
  bool get isDue {
    if (reminderType == 'none') return false;
    final now = DateTime.now();

    // 定点提醒逻辑
    if (reminderType == 'specific' && reminderValue.isNotEmpty) {
      try {
        final targetDate = DateTime.parse(reminderValue);
        return now.isAfter(targetDate);
      } catch (e) {
        return false;
      }
    }

    // 周期提醒逻辑
    if (reminderType == 'periodic' && reminderValue.isNotEmpty && lastReviewed != null) {
      final days = int.tryParse(reminderValue) ?? 0;
      return lastReviewed!.add(Duration(days: days)).isBefore(now);
    }
    return false;
  }

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      isMarked: json['is_marked'] ?? false,
      reminderType: json['reminder_type'] ?? 'none',
      reminderValue: json['reminder_value'] ?? '',
      lastReviewed: json['last_reviewed'] != null 
          ? DateTime.parse(json['last_reviewed']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'is_marked': isMarked,
      'reminder_type': reminderType,
      'reminder_value': reminderValue,
    };
  }
}

