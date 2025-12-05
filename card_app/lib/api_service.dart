// lib/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'models.dart';

class ApiService {
  // Edge 浏览器调试用本机 IP
  static const String baseUrl = 'http://127.0.0.1:5000/api'; 

  // === 卡片相关 ===
  static Future<List<CardModel>> fetchCards() async {
    final response = await http.get(Uri.parse('$baseUrl/cards'));
    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((item) => CardModel.fromJson(item)).toList();
    } else {
      throw Exception('Load Failed');
    }
  }

  static Future<void> createCard(CardModel card, String? imageFilename) async {
    final Map<String, dynamic> data = card.toJson();
    if (imageFilename != null) {
      data['image_path'] = imageFilename; // 把上传后得到的文件名传给后端
    }
    await http.post(
      Uri.parse('$baseUrl/cards'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
  }

  static Future<void> updateCard(int id, CardModel card, String? imageFilename) async {
    final Map<String, dynamic> data = card.toJson();
    if (imageFilename != null) {
      data['image_path'] = imageFilename;
    }
    await http.put(
      Uri.parse('$baseUrl/cards/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
  }

  static Future<void> deleteCard(int id) async {
    await http.delete(Uri.parse('$baseUrl/cards/$id'));
  }

  // === 图片上传 ===
  // 返回上传成功后的文件名 (filename)
  static Future<String?> uploadImage(XFile imageFile) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
    // 兼容 Web 和 本地
    final bytes = await imageFile.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes(
      'file', 
      bytes, 
      filename: imageFile.name
    ));

    try {
      var res = await request.send();
      if (res.statusCode == 200) {
        final respStr = await res.stream.bytesToString();
        final json = jsonDecode(respStr);
        return json['filename']; // 返回后端生成的文件名
      }
    } catch (e) {
      print("上传失败: $e");
    }
    return null;
  }

  // === 元数据 (分组/标签) ===
  static Future<Map<String, dynamic>> fetchMeta() async {
    final response = await http.get(Uri.parse('$baseUrl/meta'));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    return {'groups': [], 'tags': []};
  }

  static Future<void> updateMeta(List<String> groups, List<String> tags) async {
    await http.post(
      Uri.parse('$baseUrl/meta'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'groups': groups, 'tags': tags}),
    );
  }
}