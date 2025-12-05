import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  // Android 模拟器访问本机请用 10.0.2.2
  // static const String baseUrl = 'http://10.0.2.2:5000/api';
  // 如果你需要用真机调试，请把这里改成电脑局域网 IP (如 192.168.x.x)
  // 使用本机 windows 运行 app。
  static const String baseUrl = 'http://127.0.0.1:5000/api';

  // 获取列表
  static Future<List<CardModel>> fetchCards() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/cards'));
      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
        return body.map((item) => CardModel.fromJson(item)).toList();
      } else {
        throw Exception('错误码: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('连接服务器失败: $e');
    }
  }

  // 新建
  static Future<void> createCard(CardModel card) async {
    await http.post(
      Uri.parse('$baseUrl/cards'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(card.toJson()),
    );
  }

  // 更新
  static Future<void> updateCard(int id, CardModel card) async {
    await http.put(
      Uri.parse('$baseUrl/cards/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(card.toJson()),
    );
  }

  // 删除
  static Future<void> deleteCard(int id) async {
    await http.delete(Uri.parse('$baseUrl/cards/$id'));
  }
}

