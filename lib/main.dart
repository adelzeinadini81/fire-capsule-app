import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() => runApp(const FireApp());

class FireApp extends StatelessWidget {
  const FireApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'پایش کپسول آتش‌نشانی',
      theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DBHelper {
  static final DBHelper instance = DBHelper._();
  DBHelper._();
  Database? _db;

  Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'capsules.db');
    return openDatabase(path, version: 1, onCreate: (db, v) {
      db.execute('''
        CREATE TABLE capsules(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code TEXT, type TEXT, volume TEXT,
          chargeDate TEXT, expireDate TEXT,
          company TEXT, location TEXT, visitDate TEXT
        )''');
    });
  }

  Future<int> insert(Map<String, dynamic> row) async {
    final d = await db;
    return d.insert('capsules', row);
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    final d = await db;
    return d.query('capsules', orderBy: 'expireDate ASC');
  }

  Future<int> delete(int id) async {
    final d = await db;
    return d.delete('capsules', where: 'id = ?', whereArgs: [id]);
  }
}

String statusOf(String expireDate) {
  try {
    final parts = expireDate.split('/');
    final j = Jalali(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final exp = j.toDateTime();
    final now = DateTime.now();
    final diff = exp.difference(now).inDays;
    if (diff < 0) return 'منقضی';
    if (diff <= 30) return 'نزدیک انقضا';
    return 'سالم';
  } catch (e) {
    return 'نامشخص';
  }
}

Color statusColor(String s) {
  if (s == 'منقضی') return Colors.red;
  if (s == 'نزدیک انقضا') return Colors.orange;
  if (s == 'سالم') return Colors.green;
  return Colors.grey;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    items = await DBHelper.instance.getAll();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('کپسول‌های آتش‌نشانی'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: items.isEmpty
            ? const Center(child: Text('کپسولی ثبت نشده است'))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (c, i) {
                  final item = items[i];
                  final st = statusOf(item['expireDate'] ?? '');
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: statusColor(st),
                        child: const Icon(Icons.fire_extinguisher,
                            color: Colors.white),
                      ),
                      title: Text('کد: ${item['code']} - ${item['type']}'),
                      subtitle: Text(
                          'انقضا: ${item['expireDate']}\nمحل: ${item['location']}\nوضعیت: $st'),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.qr_code),
                            onPressed: () => _showQr(item['code'] ?? ''),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await DBHelper.instance.delete(item['id']);
                              _load();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.red,
          child: const Icon(Icons.add),
          onPressed: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AddPage()));
            _load();
          },
        ),
      ),
    );
  }

  void _showQr(String code) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: SizedBox(
          width: 200,
          height: 200,
          child: QrImageView(data: code, size: 200),
        ),
      ),
    );
  }
}

class AddPage extends StatefulWidget {
  const AddPage({super.key});
  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final code = TextEditingController();
  final volume = TextEditingController();
  final chargeDate = TextEditingController();
  final expireDate = TextEditingController();
  final company = TextEditingController();
  final location = TextEditingController();
  final visitDate = TextEditingController();
  String type = 'پودر و گاز';

  @override
  void initState() {
    super.initState();
    final now = Jalali.now();
    visitDate.text = '${now.year}/${now.month}/${now.day}';
  }

  Future<void> _scan() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ScanPage()));
    if (result != null) setState(() => code.text = result.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ثبت کپسول جدید'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: code,
                      decoration: const InputDecoration(labelText: 'کد کپسول'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scan,
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'نوع کپسول'),
                items: const [
                  DropdownMenuItem(value: 'پودر و گاز', child: Text('پودر و گاز')),
                  DropdownMenuItem(value: 'آب', child: Text('آب')),
                  DropdownMenuItem(value: 'CO2', child: Text('CO2')),
                ],
                onChanged: (v) => setState(() => type = v!),
              ),
              TextField(
                controller: volume,
                decoration: const InputDecoration(labelText: 'حجم'),
              ),
              TextField(
                controller: chargeDate,
                decoration:
                    const InputDecoration(labelText: 'تاریخ شارژ (مثال: 1405/03/23)'),
              ),
              TextField(
                controller: expireDate,
                decoration:
                    const InputDecoration(labelText: 'تاریخ انقضا (مثال: 1406/03/23)'),
              ),
              TextField(
                controller: company,
                decoration: const InputDecoration(labelText: 'شرکت شارژ کننده'),
              ),
              TextField(
                controller: location,
                decoration: const InputDecoration(labelText: 'محل قرارگیری'),
              ),
              TextField(
                controller: visitDate,
                decoration: const InputDecoration(labelText: 'تاریخ بازدید'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  await DBHelper.instance.insert({
                    'code': code.text,
                    'type': type,
                    'volume': volume.text,
                    'chargeDate': chargeDate.text,
                    'expireDate': expireDate.text,
                    'company': company.text,
                    'location': location.text,
                    'visitDate': visitDate.text,
                  });
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('ذخیره'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScanPage extends StatelessWidget {
  const ScanPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اسکن QR')),
      body: MobileScanner(
        onDetect: (capture) {
          final code = capture.barcodes.first.rawValue;
          if (code != null) Navigator.pop(context, code);
        },
      ),
    );
  }
}
