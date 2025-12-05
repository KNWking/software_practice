import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
      title: '卡片记忆助手',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const CardListPage(),
    );
  }
}

// === 首页：卡片列表 ===
class CardListPage extends StatefulWidget {
  const CardListPage({super.key});
  @override
  State<CardListPage> createState() => _CardListPageState();
}

class _CardListPageState extends State<CardListPage> {
  late Future<List<CardModel>> _cardsFuture;

  @override
  void initState() {
    super.initState();
    _refreshCards();
  }

  void _refreshCards() {
    setState(() {
      _cardsFuture = ApiService.fetchCards();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的记忆卡片'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshCards)
        ],
      ),
      body: FutureBuilder<List<CardModel>>(
        future: _cardsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('连接后端失败 (正常现象，因为还没写后端)', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _refreshCards, child: const Text('重试')),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('没有卡片，去新建一个吧'));
          }

          final cards = snapshot.data!;
          cards.sort((a, b) {
            if (a.isDue && !b.isDue) return -1;
            if (!a.isDue && b.isDue) return 1;
            return (b.id ?? 0).compareTo(a.id ?? 0);
          });

          return ListView.builder(
            itemCount: cards.length,
            itemBuilder: (context, index) => _buildCardItem(cards[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CardEditPage()));
          _refreshCards();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCardItem(CardModel card) {
    final isDue = card.isDue;
    return Card(
      color: isDue ? Colors.red.shade50 : Colors.white,
      shape: isDue ? RoundedRectangleBorder(side: const BorderSide(color: Colors.red), borderRadius: BorderRadius.circular(12)) : null,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        leading: IconButton(
          icon: Icon(card.isMarked ? Icons.star : Icons.star_border, color: card.isMarked ? Colors.orange : Colors.grey),
          onPressed: () async {
            card.isMarked = !card.isMarked;
            try {
              await ApiService.updateCard(card.id!, card);
              _refreshCards();
            } catch (e) { /*忽略*/ }
          },
        ),
        title: Text(card.title, style: TextStyle(color: isDue ? Colors.red : Colors.black, fontWeight: FontWeight.bold)),
        subtitle: Text(card.content, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => CardEditPage(card: card)));
          _refreshCards();
        },
      ),
    );
  }
}

// === 编辑页面 ===
class CardEditPage extends StatefulWidget {
  final CardModel? card;
  const CardEditPage({super.key, this.card});
  @override
  State<CardEditPage> createState() => _CardEditPageState();
}

class _CardEditPageState extends State<CardEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController _periodicCtrl;
  String _reminderType = 'none';
  String _reminderValue = '';

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.card?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.card?.content ?? '');
    _reminderType = widget.card?.reminderType ?? 'none';
    _periodicCtrl = TextEditingController(text: _reminderType == 'periodic' ? widget.card?.reminderValue : '');
    if (_reminderType == 'specific') _reminderValue = widget.card?.reminderValue ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    String val = _reminderType == 'periodic' ? _periodicCtrl.text : (_reminderType == 'specific' ? _reminderValue : '');
    
    final newCard = CardModel(
      id: widget.card?.id,
      title: _titleCtrl.text,
      content: _contentCtrl.text,
      isMarked: widget.card?.isMarked ?? false,
      reminderType: _reminderType,
      reminderValue: val,
      lastReviewed: widget.card?.lastReviewed,
    );

    try {
      if (widget.card == null) {
        await ApiService.createCard(newCard);
      } else {
        await ApiService.updateCard(widget.card!.id!, newCard);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('错误: $e')));
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
              onPressed: () async {
                await ApiService.deleteCard(widget.card!.id!);
                if (mounted) Navigator.pop(context);
              },
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: '标题'), validator: (v) => v!.isEmpty ? '必填' : null),
              const SizedBox(height: 10),
              TextFormField(controller: _contentCtrl, decoration: const InputDecoration(labelText: '内容'), maxLines: 5, validator: (v) => v!.isEmpty ? '必填' : null),
              const SizedBox(height: 20),
              DropdownButton<String>(
                value: _reminderType,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('无提醒')),
                  DropdownMenuItem(value: 'periodic', child: Text('周期提醒 (每隔 X 天)')),
                  DropdownMenuItem(value: 'specific', child: Text('定点提醒 (指定日期)')),
                ],
                onChanged: (v) => setState(() => _reminderType = v!),
              ),
              if (_reminderType == 'periodic')
                TextFormField(controller: _periodicCtrl, decoration: const InputDecoration(labelText: '天数 (例如 3)'), keyboardType: TextInputType.number),
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
              ElevatedButton(onPressed: _save, child: const Text('保存卡片')),
            ],
          ),
        ),
      ),
    );
  }
}

