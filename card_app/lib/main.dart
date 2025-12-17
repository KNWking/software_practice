import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'models.dart';
import 'api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 尝试恢复登录状态
  bool hasToken = await ApiService.init();

  runApp(MyApp(isLoggedIn: hasToken));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '卡片记忆助手 Pro',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      home: isLoggedIn ? const CardListPage() : const LoginPage(),
    );
  }
}

// ==========================================
// 0. 登录页 (LoginPage)
// ==========================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isRegistering = false;
  String _message = '';

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _message = '请输入用户名和密码');
      return;
    }

    setState(() => _message = '正在处理...');

    if (_isRegistering) {
      final error = await ApiService.register(username, password);
      if (error == null) {
        setState(() {
          _isRegistering = false;
          _message = '注册成功，请登录';
          _passwordCtrl.clear();
        });
      } else {
        setState(() => _message = error);
      }
    } else {
      final success = await ApiService.login(username, password);
      if (success) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CardListPage()),
        );
      } else {
        setState(() => _message = '登录失败，用户名或密码错误');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              Text(
                _isRegistering ? '注册账号' : '用户登录',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: '用户名',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '密码',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _message,
                style: TextStyle(
                  color: _message.contains('成功') ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: Text(_isRegistering ? '立即注册' : '登 录'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isRegistering = !_isRegistering;
                    _message = '';
                  });
                },
                child: Text(_isRegistering ? '已有账号？去登录' : '没有账号？去注册'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 1. 列表页 (CardListPage)
// ==========================================
class CardListPage extends StatefulWidget {
  const CardListPage({super.key});
  @override
  State<CardListPage> createState() => _CardListPageState();
}

class _CardListPageState extends State<CardListPage> {
  List<CardModel> _allCards = [];
  List<String> _availableGroups = [];
  List<String> _availableTags = [];
  bool _isLoading = true;
  String _currentGroup = 'ALL';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _startTimer();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchData(silent: true);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _fetchData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final cards = await ApiService.fetchCards();
      final meta = await ApiService.fetchMeta();
      if (mounted) {
        setState(() {
          _allCards = cards;
          _availableGroups = List<String>.from(meta['groups']);
          _availableTags = List<String>.from(meta['tags']);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('AuthError')) {
        _stopTimer();
        if (mounted) {
          ApiService.logout();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      } else {
        if (mounted && !silent) setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认删除', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showManageDialog(String type) {
    _stopTimer();
    final isGroup = type == 'group';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final textCtrl = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentList = isGroup ? _availableGroups : _availableTags;
            return AlertDialog(
              title: Text('管理${isGroup ? "分组" : "标签"}'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isGroup)
                      const Text(
                        "⚠️ 删除分组将删除其下所有卡片！",
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textCtrl,
                            decoration: InputDecoration(
                              hintText: '新${isGroup ? "分组" : "标签"}名',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.blue,
                          ),
                          onPressed: () async {
                            final targetList = isGroup
                                ? _availableGroups
                                : _availableTags;
                            if (textCtrl.text.isNotEmpty &&
                                !targetList.contains(textCtrl.text)) {
                              targetList.add(textCtrl.text);
                              await ApiService.updateMeta(
                                _availableGroups,
                                _availableTags,
                              );
                              textCtrl.clear();
                              setDialogState(() {});
                              _fetchData(silent: true);
                            }
                          },
                        ),
                      ],
                    ),
                    const Divider(),
                    Wrap(
                      spacing: 8,
                      children: currentList
                          .map(
                            (item) => Chip(
                              label: Text(item),
                              onDeleted: () async {
                                final confirm = await _showConfirmDialog(
                                  '确认删除？',
                                  '确定要删除 "$item" 吗？',
                                );
                                if (confirm) {
                                  if (isGroup) {
                                    await ApiService.deleteGroup(item);
                                    if (_currentGroup == item)
                                      setState(() => _currentGroup = 'ALL');
                                  } else {
                                    await ApiService.deleteTag(item);
                                  }
                                  await _fetchData(silent: true);
                                  setDialogState(() {});
                                }
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _startTimer();
                  },
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleCompletion(CardModel card) async {
    card.isCompleted = !card.isCompleted;
    await ApiService.updateCard(card.id!, card, null);
    _fetchData(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    List<CardModel> filtered;
    if (_currentGroup == 'ALL') {
      filtered = List.from(_allCards);
    } else {
      filtered = _allCards.where((c) => c.groupName == _currentGroup).toList();
    }

    final incompleteCards = filtered.where((c) => !c.isCompleted).toList();
    final completedCards = filtered.where((c) => c.isCompleted).toList();

    incompleteCards.sort((a, b) {
      final aTime = a.nextReminderTime;
      final bTime = b.nextReminderTime;
      if (aTime != null && bTime == null) return -1;
      if (aTime == null && bTime != null) return 1;
      if (aTime != null && bTime != null) return aTime.compareTo(bTime);
      return b.createdAt.compareTo(a.createdAt);
    });
    completedCards.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: const Center(
                child: Text(
                  '分组视图',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('退出登录', style: TextStyle(color: Colors.red)),
              onTap: () {
                _stopTimer();
                ApiService.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.all_inbox),
                    title: const Text('全部卡片'),
                    selected: _currentGroup == 'ALL',
                    onTap: () {
                      setState(() => _currentGroup = 'ALL');
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  ..._availableGroups.map(
                    (group) => ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(group),
                      selected: _currentGroup == group,
                      onTap: () {
                        setState(() => _currentGroup = group);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('管理分组'),
              onTap: () => _showManageDialog('group'),
            ),
            ListTile(
              leading: const Icon(Icons.label),
              title: const Text('管理标签'),
              onTap: () => _showManageDialog('tag'),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(_currentGroup == 'ALL' ? '全部卡片' : _currentGroup),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: CardSearchDelegate(
                  allCards: _allCards,
                  availableGroups: _availableGroups,
                  availableTags: _availableTags,
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                children: [
                  ExpansionTile(
                    initiallyExpanded: true,
                    title: const Text(
                      "待办事项",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    children: incompleteCards.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                "没有待办任务，真棒！",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ]
                        : incompleteCards
                              .map((c) => _buildCardItem(c))
                              .toList(),
                  ),
                  const Divider(thickness: 5, color: Colors.grey),
                  ExpansionTile(
                    initiallyExpanded: false,
                    title: const Text(
                      "已完成",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    children: completedCards.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                "还没有完成的任务",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ]
                        : completedCards.map((c) => _buildCardItem(c)).toList(),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          _stopTimer();
          String defaultGroup =
              (_currentGroup == 'ALL' && _availableGroups.isNotEmpty)
              ? _availableGroups.first
              : (_currentGroup == 'ALL' ? '默认清单' : _currentGroup);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CardEditPage(
                availableGroups: _availableGroups,
                availableTags: _availableTags,
                initialGroup: defaultGroup,
              ),
            ),
          );
          _fetchData();
          _startTimer();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // === 这里已经补全了完整的方法内容 ===
  Widget _buildCardItem(CardModel card) {
    final isDue = card.isDue;
    final isDone = card.isCompleted;

    String timeStr = '';
    Color timeColor = Colors.black54;

    if (card.nextReminderTime != null) {
      timeStr = DateFormat('MM-dd HH:mm').format(card.nextReminderTime!);
      if (isDone) {
        timeColor = Colors.grey;
      } else if (isDue) {
        timeColor = Colors.red;
      }
    }

    Widget buildTags() {
      if (card.tags.isEmpty) return const SizedBox();
      final tags = card.tags.split(',').where((e) => e.isNotEmpty).toList();
      return Wrap(
        spacing: 4,
        children: tags.map((t) {
          Color bg = isDone
              ? Colors.grey.shade200
              : (t.contains('高') ? Colors.red.shade100 : Colors.blue.shade50);
          Color text = isDone ? Colors.grey : Colors.black87;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(t, style: TextStyle(fontSize: 10, color: text)),
          );
        }).toList(),
      );
    }

    final coverImage = card.imageUrls.isNotEmpty ? card.imageUrls.first : null;

    final titleStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
      color: isDone ? Colors.grey : (isDue ? Colors.red : Colors.black),
      decoration: isDone ? TextDecoration.lineThrough : null,
    );

    return Card(
      elevation: isDone ? 0 : 2,
      color: isDone
          ? Colors.grey.shade50
          : (isDue ? Colors.red.shade50 : Colors.white),
      shape: isDue
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Colors.red),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: InkWell(
        onTap: () async {
          _stopTimer();
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CardDetailPage(
                card: card,
                availableGroups: _availableGroups,
                availableTags: _availableTags,
              ),
            ),
          );
          _fetchData();
          _startTimer();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coverImage != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: ColorFiltered(
                  colorFilter: isDone
                      ? const ColorFilter.mode(
                          Colors.grey,
                          BlendMode.saturation,
                        )
                      : const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.multiply,
                        ),
                  child: Image.network(
                    coverImage,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      height: 150,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0, top: 4.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isDone,
                        onChanged: (val) => _toggleCompletion(card),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(card.title, style: titleStyle),
                            ),
                            if (isDue && !isDone)
                              const Icon(
                                Icons.alarm,
                                color: Colors.red,
                                size: 16,
                              ),
                          ],
                        ),

                        if (card.content.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _stripMarkdown(card.content),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDone ? Colors.grey : Colors.black54,
                              fontSize: 14,
                              height: 1.4,
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],

                        const SizedBox(height: 8),
                        Row(
                          children: [
                            buildTags(),
                            const SizedBox(width: 8),
                            if (timeStr.isNotEmpty)
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: timeColor,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: timeColor,
                                      fontWeight: (isDue && !isDone)
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            const Spacer(),
                            Text(
                              card.groupName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. 详情页 (CardDetailPage)
// ==========================================
class CardDetailPage extends StatefulWidget {
  final CardModel card;
  final List<String> availableGroups;
  final List<String> availableTags;

  const CardDetailPage({
    super.key,
    required this.card,
    required this.availableGroups,
    required this.availableTags,
  });

  @override
  State<CardDetailPage> createState() => _CardDetailPageState();
}

class _CardDetailPageState extends State<CardDetailPage> {
  late CardModel _card;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _card = widget.card;
  }

  Future<void> _refreshCard() async {
    final cards = await ApiService.fetchCards();
    try {
      final updated = cards.firstWhere((c) => c.id == _card.id);
      setState(() => _card = updated);
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              // 接收编辑页返回的结果
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CardEditPage(
                    card: _card,
                    availableGroups: widget.availableGroups,
                    availableTags: widget.availableTags,
                  ),
                ),
              );
              // 检查结果。如果是 deleted，说明卡片没了，详情页也该退出了
              if (result == 'deleted') {
                if (!mounted) return;
                Navigator.pop(context); // 退出详情页，回到列表页
                return;
              }

              // 只有没删除且页面还存活时，才刷新
              if (mounted) {
                _refreshCard();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_card.imageUrls.isNotEmpty)
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  SizedBox(
                    height: 300,
                    child: PageView.builder(
                      itemCount: _card.imageUrls.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullScreenImageViewer(
                                  imageUrls: _card.imageUrls,
                                  initialIndex: index,
                                ),
                              ),
                            );
                          },
                          child: Image.network(
                            _card.imageUrls[index],
                            fit: BoxFit.contain,
                            loadingBuilder: (ctx, child, loading) {
                              if (loading == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${_currentImageIndex + 1} / ${_card.imageUrls.length}",
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _card.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _card.groupName,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_card.tags.isNotEmpty)
                        ..._card.tags
                            .split(',')
                            .map(
                              (t) => Padding(
                                padding: const EdgeInsets.only(right: 4.0),
                                child: Chip(
                                  label: Text(
                                    t,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                    ],
                  ),
                  const Divider(height: 32),

                  MarkdownBody(
                    data: _card.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      h1: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      h2: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      p: const TextStyle(fontSize: 16),
                      blockquote: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. 编辑页 (CardEditPage)
// ==========================================
class CardEditPage extends StatefulWidget {
  final CardModel? card;
  final List<String> availableGroups;
  final List<String> availableTags;
  final String? initialGroup;
  const CardEditPage({
    super.key,
    this.card,
    required this.availableGroups,
    required this.availableTags,
    this.initialGroup,
  });
  @override
  State<CardEditPage> createState() => _CardEditPageState();
}

class _CardEditPageState extends State<CardEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  String? _selectedGroup;
  List<String> _selectedTags = [];
  String _reminderType = 'none';
  String _reminderValue = '';
  final TextEditingController _periodicCtrl = TextEditingController();
  List<String> _existingImages = [];
  List<XFile> _newImages = [];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.card?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.card?.content ?? '');
    String rawGroup = widget.card?.groupName ?? widget.initialGroup ?? '';
    if (widget.availableGroups.contains(rawGroup))
      _selectedGroup = rawGroup;
    else if (widget.availableGroups.isNotEmpty)
      _selectedGroup = widget.availableGroups.first;
    if (widget.card != null && widget.card!.tags.isNotEmpty)
      _selectedTags = widget.card!.tags
          .split(',')
          .where((t) => widget.availableTags.contains(t))
          .toList();
    _existingImages = List.from(widget.card?.imageUrls ?? []);
    _reminderType = widget.card?.reminderType ?? 'none';
    if (_reminderType == 'periodic')
      _periodicCtrl.text = widget.card?.reminderValue ?? '';
    if (_reminderType == 'specific')
      _reminderValue = widget.card?.reminderValue ?? '';
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) setState(() => _newImages.addAll(images));
  }

  Future<void> _confirmAndDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除卡片'),
        content: const Text('确认要删除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.deleteCard(widget.card!.id!);
      if (mounted) {
        // 这里的 'deleted' 是关键，告诉上一页（详情页）我把它删了
        Navigator.pop(context, 'deleted');
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // === 修复：分组兜底逻辑 ===
    String finalGroup = _selectedGroup ?? '默认清单';

    List<String> finalImageFilenames = [];
    for (var url in _existingImages) {
      final uri = Uri.parse(url);
      finalImageFilenames.add(uri.pathSegments.last);
    }
    for (var xfile in _newImages) {
      String? filename = await ApiService.uploadImage(xfile);
      if (filename != null) finalImageFilenames.add(filename);
    }
    String val = _reminderType == 'periodic'
        ? _periodicCtrl.text
        : (_reminderType == 'specific' ? _reminderValue : '');
    final newCard = CardModel(
      id: widget.card?.id,
      title: _titleCtrl.text,
      content: _contentCtrl.text,
      isMarked: widget.card?.isMarked ?? false,
      isCompleted: widget.card?.isCompleted ?? false,
      groupName: finalGroup, // 使用确保非空的 finalGroup
      tags: _selectedTags.join(','),
      createdAt: widget.card?.createdAt ?? DateTime.now(),
      reminderType: _reminderType,
      reminderValue: val,
      lastReviewed: widget.card?.lastReviewed,
    );
    try {
      if (widget.card == null)
        await ApiService.createCard(newCard, finalImageFilenames);
      else
        await ApiService.updateCard(
          widget.card!.id!,
          newCard,
          finalImageFilenames,
        );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.card == null ? '新建卡片' : '编辑卡片'),
        actions: [
          if (widget.card != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _confirmAndDelete,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: '标题'),
                validator: (v) => v!.isEmpty ? '必填' : null,
              ),
              const SizedBox(height: 10),

              const Row(
                children: [
                  Icon(Icons.description, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    '支持 Markdown: # 标题, **加粗**, ~~删除线~~',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _contentCtrl,
                decoration: const InputDecoration(
                  labelText: '内容 (Markdown)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: 8,
              ),
              const SizedBox(height: 16),

              const Text("图片", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._existingImages.map(
                    (url) => Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Image.network(url, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _existingImages.remove(url)),
                            child: Container(
                              color: Colors.black54,
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._newImages.map(
                    (file) => Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Image.network(file.path, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _newImages.remove(file)),
                            child: Container(
                              color: Colors.black54,
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.add_a_photo, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // === 修复：下拉菜单增加兜底项 ===
              DropdownButtonFormField<String>(
                value: _selectedGroup,
                decoration: const InputDecoration(
                  labelText: '分组',
                  border: OutlineInputBorder(),
                ),
                items: widget.availableGroups.isEmpty
                    ? [
                        const DropdownMenuItem(
                          value: '默认清单',
                          child: Text('默认清单 (自动创建)'),
                        ),
                      ]
                    : widget.availableGroups
                          .map(
                            (g) => DropdownMenuItem(value: g, child: Text(g)),
                          )
                          .toList(),
                onChanged: (v) => setState(() => _selectedGroup = v),
              ),

              const SizedBox(height: 16),
              const Text("标签", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: widget.availableTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const Text("提醒设置", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _reminderType,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('无提醒')),
                  DropdownMenuItem(value: 'periodic', child: Text('周期提醒 (天数)')),
                  DropdownMenuItem(value: 'specific', child: Text('定点提醒 (日期)')),
                ],
                onChanged: (v) => setState(() => _reminderType = v!),
              ),
              if (_reminderType == 'periodic')
                TextFormField(
                  controller: _periodicCtrl,
                  decoration: const InputDecoration(labelText: '每隔几天?'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.isEmpty) return '请输入天数';
                    if (int.tryParse(v) == 0) return '天数不能为0';
                    return null;
                  },
                ),
              if (_reminderType == 'specific')
                ListTile(
                  title: Text(_reminderValue.isEmpty ? '选择时间' : _reminderValue),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (t != null) {
                        setState(
                          () => _reminderValue = DateFormat('yyyy-MM-dd HH:mm')
                              .format(
                                DateTime(
                                  d.year,
                                  d.month,
                                  d.day,
                                  t.hour,
                                  t.minute,
                                ),
                              ),
                        );
                      }
                    }
                  },
                ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. 全屏图片查看器
// ==========================================
class FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    widget.imageUrls[index],
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${_currentIndex + 1} / ${widget.imageUrls.length}",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Search Delegate
class CardSearchDelegate extends SearchDelegate {
  final List<CardModel> allCards;
  final List<String> availableGroups;
  final List<String> availableTags;
  CardSearchDelegate({
    required this.allCards,
    required this.availableGroups,
    required this.availableTags,
  });
  @override
  String get searchFieldLabel => '搜索...';
  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );
  @override
  Widget buildResults(BuildContext context) => _buildList(context);
  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final q = query.toLowerCase();
    final results = allCards.where((card) {
      return card.title.toLowerCase().contains(q) ||
          card.content.toLowerCase().contains(q) ||
          card.tags.toLowerCase().contains(q);
    }).toList();
    if (results.isEmpty) return const Center(child: Text('没有找到相关卡片'));
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final card = results[index];
        return ListTile(
          leading: Icon(
            card.isCompleted ? Icons.check_circle : Icons.circle_outlined,
            color: card.isCompleted ? Colors.green : Colors.grey,
          ),
          title: Text(
            card.title,
            style: TextStyle(
              decoration: card.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Text(
            card.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            close(context, null);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CardDetailPage(
                  card: card,
                  availableGroups: availableGroups,
                  availableTags: availableTags,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// 辅助函数：去除 Markdown 符号，仅保留纯文本用于预览
String _stripMarkdown(String markdown) {
  var text = markdown;

  // 1. 替换标题 (# 标题 -> 标题)
  text = text.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');

  // 2. 替换加粗/斜体 (**text**, *text*, __text__, _text_)
  // 使用 replaceAllMapped 避免 $2 被当做普通字符输出
  text = text.replaceAllMapped(
    RegExp(r'(\*\*|__|[*_])(.+?)\1'),
    (match) => match.group(2) ?? '',
  );

  // 3. 替换删除线 (~~text~~ -> text)
  text = text.replaceAllMapped(
    RegExp(r'~~(.+?)~~'),
    (match) => match.group(1) ?? '',
  );

  // 4. 替换行内代码 (`text` -> text)
  text = text.replaceAllMapped(
    RegExp(r'`([^`]+)`'),
    (match) => match.group(1) ?? '',
  );

  // 5. 替换链接 ([text](url) -> text)
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^\)]+\)'),
    (match) => match.group(1) ?? '',
  );

  // 6. 去除列表符号 (- item, 1. item)
  text = text.replaceAll(RegExp(r'^\s*[\-\*]\s+', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');

  // 7. 去除引用符号 (> quote)
  text = text.replaceAll(RegExp(r'^\s*>\s+', multiLine: true), '');

  // 8. 去除图片 (![alt](url) -> [图片])
  text = text.replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '[图片]');

  // 9. 去除多余空行并修剪
  return text.trim();
}
