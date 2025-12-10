import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'models.dart';

class ApiService {
  // === 注意：真机调试时请将 IP 改为电脑的局域网 IP ===
  static const String baseUrl = 'http://127.0.0.1:5000/api'; 
  
  // 内存中存储 Token
  static String? _authToken;

  static bool get isLoggedIn => _authToken != null;

  static void logout() {
    _authToken = null;
  }

  // 构造 Header，如果有 Token 则带上
  static Map<String, String> get _headers {
    final Map<String, String> headers = {'Content-Type': 'application/json'};
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // === 认证接口 ===
  
  static Future<bool> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      _authToken = body['access_token'];
      return true;
    }
    return false;
  }

  static Future<String?> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 201) {
      return null; // Success
    } else {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      return body['error'] ?? '注册失败';
    }
  }

  // === 业务接口 (现在会自动带 Header) ===

  static Future<List<CardModel>> fetchCards() async {
    final response = await http.get(Uri.parse('$baseUrl/cards'), headers: _headers);
    if (response.statusCode == 200) {
      final List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((item) => CardModel.fromJson(item)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('AuthError'); // 抛出认证错误供 UI 捕获
    } else {
      throw Exception('Load Failed');
    }
  }

  static Future<void> createCard(CardModel card, List<String> imageFilenames) async {
    final Map<String, dynamic> data = card.toJson();
    data['image_paths'] = imageFilenames;
    await http.post(Uri.parse('$baseUrl/cards'), headers: _headers, body: jsonEncode(data));
  }

  static Future<void> updateCard(int id, CardModel card, List<String>? imageFilenames) async {
    final Map<String, dynamic> data = card.toJson();
    if (imageFilenames != null) {
      data['image_paths'] = imageFilenames;
    }
    await http.put(
      Uri.parse('$baseUrl/cards/$id'),
      headers: _headers,
      body: jsonEncode(data),
    );
  }

  static Future<void> deleteCard(int id) async {
    await http.delete(Uri.parse('$baseUrl/cards/$id'), headers: _headers);
  }

  static Future<String?> uploadImage(XFile imageFile) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
    // 图片上传也可以带上 token（取决于后端是否严格校验，这里带上更保险）
    if (_authToken != null) {
      request.headers['Authorization'] = 'Bearer $_authToken';
    }
    
    final bytes = await imageFile.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: imageFile.name));
    try {
      var res = await request.send();
      if (res.statusCode == 200) {
        final respStr = await res.stream.bytesToString();
        final json = jsonDecode(respStr);
        return json['filename'];
      }
    } catch (e) { print("上传失败: $e"); }
    return null;
  }

  static Future<Map<String, dynamic>> fetchMeta() async {
    final response = await http.get(Uri.parse('$baseUrl/meta'), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    return {'groups': [], 'tags': []};
  }

  static Future<void> updateMeta(List<String> groups, List<String> tags) async {
    await http.post(Uri.parse('$baseUrl/meta'), headers: _headers, body: jsonEncode({'groups': groups, 'tags': tags}));
  }

  static Future<void> deleteGroup(String groupName) async {
    await http.post(Uri.parse('$baseUrl/meta/delete_group'), headers: _headers, body: jsonEncode({'name': groupName}));
  }

  static Future<void> deleteTag(String tagName) async {
    await http.post(Uri.parse('$baseUrl/meta/delete_tag'), headers: _headers, body: jsonEncode({'name': tagName}));
  }
}