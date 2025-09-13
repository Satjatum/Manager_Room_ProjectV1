import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart' as crypto;

enum HashAlgo { sha256, sha1, md5 }

enum HashMode { generate, verify }

class HashGeneratorCard extends StatefulWidget {
  const HashGeneratorCard({super.key});

  @override
  State<HashGeneratorCard> createState() => _HashGeneratorCardState();
}

class _HashGeneratorCardState extends State<HashGeneratorCard> {
  final _inputController = TextEditingController();
  final _targetHashController = TextEditingController();

  HashAlgo _algo = HashAlgo.sha256;
  HashMode _mode = HashMode.generate;

  String _hashResult = '';
  String? _verifyMessage; // null = ยังไม่ตรวจ, true/false = ผลลัพธ์ข้อความ

  @override
  void dispose() {
    _inputController.dispose();
    _targetHashController.dispose();
    super.dispose();
  }

  String _hashText(String text) {
    switch (_algo) {
      case HashAlgo.sha256:
        return crypto.sha256.convert(utf8.encode(text)).toString();
      case HashAlgo.sha1:
        return crypto.sha1.convert(utf8.encode(text)).toString();
      case HashAlgo.md5:
        return crypto.md5.convert(utf8.encode(text)).toString();
    }
  }

  void _onGenerate() {
    final input = _inputController.text;
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อความ')),
      );
      return;
    }
    setState(() {
      _hashResult = _hashText(input);
      _verifyMessage = null;
    });
  }

  void _onVerify() {
    final input = _inputController.text;
    final target = _targetHashController.text.trim();
    if (input.isEmpty || target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อความและแฮชเป้าหมาย')),
      );
      return;
    }
    final computed = _hashText(input);
    // เปรียบเทียบแบบไม่สนตัวพิมพ์ (ส่วนใหญ่เป็น hex ล้วน)
    final isMatch = _constantTimeEquals(
      computed.toLowerCase(),
      target.toLowerCase(),
    );
    setState(() {
      _hashResult = computed;
      _verifyMessage =
          isMatch ? '✅ ตรงกับแฮชเป้าหมาย' : '❌ ไม่ตรงกับแฮชเป้าหมาย';
    });
  }

  // เปรียบเทียบแบบเวลาคงที่อย่างง่าย (ลด timing leak เบื้องต้น)
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int res = 0;
    for (int i = 0; i < a.length; i++) {
      res |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return res == 0;
  }

  Future<void> _copy() async {
    if (_hashResult.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _hashResult));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คัดลอกแล้ว')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // หัวข้อ + โหมด
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hash Tool',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                DropdownButton<HashMode>(
                  value: _mode,
                  underline: const SizedBox.shrink(),
                  onChanged: (v) =>
                      setState(() => _mode = v ?? HashMode.generate),
                  items: const [
                    DropdownMenuItem(
                      value: HashMode.generate,
                      child: Text('สร้าง Hash'),
                    ),
                    DropdownMenuItem(
                      value: HashMode.verify,
                      child: Text('ตรวจสอบกับ Hash'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ช่องกรอกข้อความ
            TextField(
              controller: _inputController,
              decoration: const InputDecoration(
                labelText: 'ข้อความ',
                hintText: 'พิมพ์ข้อความต้นฉบับ...',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            // เลือกอัลกอริทึม
            DropdownButtonFormField<HashAlgo>(
              value: _algo,
              decoration: const InputDecoration(
                labelText: 'อัลกอริทึม',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: HashAlgo.sha256, child: Text('SHA-256')),
                DropdownMenuItem(value: HashAlgo.sha1, child: Text('SHA-1')),
                DropdownMenuItem(value: HashAlgo.md5, child: Text('MD5')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _algo = v);
              },
            ),
            const SizedBox(height: 12),

            // ช่องแฮชเป้าหมาย (เฉพาะโหมด verify)
            if (_mode == HashMode.verify) ...[
              TextField(
                controller: _targetHashController,
                decoration: const InputDecoration(
                  labelText: 'แฮชเป้าหมาย',
                  hintText: 'เช่น 5e884898da28047151d0e56f8dc62927...',
                  border: OutlineInputBorder(),
                ),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
            ],

            // ปุ่มกดทำงาน
            SizedBox(
              height: 48,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _mode == HashMode.generate ? _onGenerate : _onVerify,
                icon: Icon(
                    _mode == HashMode.generate ? Icons.lock : Icons.verified),
                label:
                    Text(_mode == HashMode.generate ? 'สร้าง Hash' : 'ตรวจสอบ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // แสดงผลลัพธ์ (ข้อความ + คัดลอก)
            if (_hashResult.isNotEmpty) ...[
              Text(
                _mode == HashMode.generate
                    ? 'ผลลัพธ์ (Hash):'
                    : 'คำนวณได้ (Hash):',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outline),
                  borderRadius: BorderRadius.circular(8),
                  color: cs.surfaceVariant.withOpacity(0.3),
                ),
                child: SelectableText(
                  _hashResult,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy),
                  label: const Text('คัดลอก'),
                ),
              ),
            ],

            // สถานะตรวจสอบ (ตรง/ไม่ตรง)
            if (_verifyMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _verifyMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _verifyMessage!.startsWith('✅')
                          ? Colors.green
                          : Colors.red,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
