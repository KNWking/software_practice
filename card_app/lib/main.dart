import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'models.dart';
import 'api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '卡片记忆助手 Pro',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const CardListPage(),
    );
  }
}

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
  
  // 当前分组：'ALL' 代表全部卡片
  String _currentGroup = 'ALL'; 

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final cards = await ApiService.fetchCards();
      final meta = await ApiService.fetchMeta();
      setState(() {
        _allCards = cards;
        _availableGroups = List<String>.from(meta['groups']);
        _availableTags = List<String>.from(meta['tags']);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // 管理分组/标签的弹窗
  void _showManageDialog(String type) {
    final isGroup = type == 'group';
    final List<String> currentList = isGroup ? _availableGroups : _availableTags;
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('管理${isGroup ? "分组" : "标签"}'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 添加输入框
                    Row(
                      children: [
                        Expanded(child: TextField(controller: textCtrl, decoration: InputDecoration(hintText: '新${isGroup ? "分组" : "标签"}名'))),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.blue),
                          onPressed: () async {
                            if (textCtrl.text.isNotEmpty && !currentList.contains(textCtrl.text)) {
                              currentList.add(textCtrl.text);
                              await ApiService.updateMeta(_availableGroups, _availableTags);
                              textCtrl.clear();
                              setDialogState(() {}); // 刷新弹窗
                              _fetchData(); // 刷新主页
                            }
                          },
                        )
                      ],
                    ),
                    const Divider(),
                    // 列表展示
                    Wrap(
                      spacing: 8,
                      children: currentList.map((item) => Chip(
                        label: Text(item),
                        onDeleted: () async {
                          currentList.remove(item);
                          await ApiService.updateMeta(_availableGroups, _availableTags);
                          setDialogState(() {});
                          _fetchData();
                        },
                      )).toList(),
                    )
                  ],
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
            );
          },
        );
      },
    );
  }

  List<CardModel> get _displayCards {
    // 1. 筛选
    List<CardModel> filtered;
    if (_currentGroup == 'ALL') {
      filtered = List.from(_allCards);
    } else {
      filtered = _allCards.where((c) => c.groupName == _currentGroup).toList();
    }

    // 2. 排序 (有提醒在前 -> 提醒时间近在前 -> 创建时间新在前)
    filtered.sort((a, b) {
      final aTime = a.nextReminderTime;
      final bTime = b.nextReminderTime;

      if (aTime != null && bTime == null) return -1;
      if (aTime == null && bTime != null) return 1;
      if (aTime != null && bTime != null) return aTime.compareTo(bTime);
      return b.createdAt.compareTo(a.createdAt); // 最新创建的在前
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: const Center(child: Text('分组视图', style: TextStyle(color: Colors.white, fontSize: 24))),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.all_inbox),
                    title: const Text('全部卡片'),
                    selected: _currentGroup == 'ALL',
                    onTap: () { setState(() => _currentGroup = 'ALL'); Navigator.pop(context); },
                  ),
                  const Divider(),
                  ..._availableGroups.map((group) => ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(group),
                    selected: _currentGroup == group,
                    onTap: () { setState(() => _currentGroup = group); Navigator.pop(context); },
                  )),
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
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData)],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : ListView.builder(
              itemCount: _displayCards.length,
              itemBuilder: (context, index) => _buildCardItem(_displayCards[index]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 新建时，如果当前在某个特定分组，就默认选那个
          String defaultGroup = (_currentGroup == 'ALL' && _availableGroups.isNotEmpty) 
              ? _availableGroups.first 
              : (_currentGroup == 'ALL' ? '默认清单' : _currentGroup);
              
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => CardEditPage(
              availableGroups: _availableGroups,
              availableTags: _availableTags,
              initialGroup: defaultGroup,
            ),
          ));
          _fetchData();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCardItem(CardModel card) {
    final isDue = card.isDue;
    
    // 显示标签 Chip
    Widget buildTags() {
      if (card.tags.isEmpty) return const SizedBox();
      final tags = card.tags.split(',').where((e) => e.isNotEmpty).toList();
      return Wrap(
        spacing: 4,
        children: tags.map((t) {
          // 高优先级标红，其他蓝色
          Color color = t.contains('高') ? Colors.red.shade100 : Colors.blue.shade50;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            child: Text(t, style: const TextStyle(fontSize: 10)),
          );
        }).toList(),
      );
    }

    return Card(
      elevation: 2,
      color: isDue ? Colors.red.shade50 : Colors.white,
      shape: isDue ? RoundedRectangleBorder(side: const BorderSide(color: Colors.red), borderRadius: BorderRadius.circular(12)) : null,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: InkWell(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => CardEditPage(
              card: card,
              availableGroups: _availableGroups,
              availableTags: _availableTags,
            ),
          ));
          _fetchData();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 如果有图片，显示在顶部
            if (card.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  card.imageUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(height: 150, color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(card.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDue ? Colors.red : Colors.black))),
                    if (isDue) const Icon(Icons.alarm, color: Colors.red, size: 16),
                  ]),
                  if (card.content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(card.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      buildTags(),
                      const Spacer(),
                      Text(card.groupName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// === 编辑页面 ===
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

  XFile? _pickedImage; // 新选的图
  String? _networkImageUrl; // 原有的图 URL

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.card?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.card?.content ?? '');
    
    // 初始化分组 (如果在可用列表中找不到，就默认选第一个)
    String rawGroup = widget.card?.groupName ?? widget.initialGroup ?? '';
    if (widget.availableGroups.contains(rawGroup)) {
      _selectedGroup = rawGroup;
    } else if (widget.availableGroups.isNotEmpty) {
      _selectedGroup = widget.availableGroups.first;
    }

    // 初始化标签
    if (widget.card != null && widget.card!.tags.isNotEmpty) {
      _selectedTags = widget.card!.tags.split(',').where((t) => widget.availableTags.contains(t)).toList();
    }

    _networkImageUrl = widget.card?.imageUrl;
    
    _reminderType = widget.card?.reminderType ?? 'none';
    if (_reminderType == 'periodic') _periodicCtrl.text = widget.card?.reminderValue ?? '';
    if (_reminderType == 'specific') _reminderValue = widget.card?.reminderValue ?? '';
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGroup == null) return;

    // 1. 如果有新图片，先上传
    String? newImageFilename;
    if (_pickedImage != null) {
      newImageFilename = await ApiService.uploadImage(_pickedImage!);
    }

    String val = _reminderType == 'periodic' ? _periodicCtrl.text : (_reminderType == 'specific' ? _reminderValue : '');
    
    final newCard = CardModel(
      id: widget.card?.id,
      title: _titleCtrl.text,
      content: _contentCtrl.text,
      isMarked: widget.card?.isMarked ?? false,
      groupName: _selectedGroup!,
      tags: _selectedTags.join(','),
      createdAt: widget.card?.createdAt ?? DateTime.now(),
      reminderType: _reminderType,
      reminderValue: val,
      lastReviewed: widget.card?.lastReviewed,
      // imageUrl 不在这里传，而是通过 updateCard 的 filename 参数传给后端去拼 URL
    );

    try {
      if (widget.card == null) {
        await ApiService.createCard(newCard, newImageFilename);
      } else {
        // 如果没有新图片，传 null，后端会保持原样
        await ApiService.updateCard(widget.card!.id!, newCard, newImageFilename);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.card == null ? '新建卡片' : '编辑卡片'),
        actions: [
          if (widget.card != null)
             IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                await ApiService.deleteCard(widget.card!.id!);
                if (mounted) Navigator.pop(context);
              }),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // === 图片区域 ===
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                  child: _pickedImage != null 
                    ? Image.network(_pickedImage!.path, fit: BoxFit.cover) // Web 上 XFile.path 可以直接显示
                    : (_networkImageUrl != null 
                        ? Image.network(_networkImageUrl!, fit: BoxFit.cover)
                        : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 40, color: Colors.grey), Text("添加图片")])),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: '标题'), validator: (v) => v!.isEmpty ? '必填' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _contentCtrl, decoration: const InputDecoration(labelText: '内容'), maxLines: 3),
              const SizedBox(height: 16),

              // === 分组选择 (Dropdown) ===
              DropdownButtonFormField<String>(
                value: _selectedGroup,
                decoration: const InputDecoration(labelText: '分组', border: OutlineInputBorder()),
                items: widget.availableGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => _selectedGroup = v),
              ),
              const SizedBox(height: 16),

              // === 标签选择 (Wrap ChoiceChip) ===
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
                TextFormField(controller: _periodicCtrl, decoration: const InputDecoration(labelText: '每隔几天?'), keyboardType: TextInputType.number),
              if (_reminderType == 'specific')
                ListTile(
                  title: Text(_reminderValue.isEmpty ? '选择时间' : _reminderValue),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
                    if (d != null) {
                      final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (t != null) {
                        setState(() => _reminderValue = DateFormat('yyyy-MM-dd HH:mm').format(DateTime(d.year, d.month, d.day, t.hour, t.minute)));
                      }
                    }
                  },
                ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}