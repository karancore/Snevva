import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class DebugSleepBufferScreen extends StatefulWidget {
  const DebugSleepBufferScreen({super.key});

  @override
  State<DebugSleepBufferScreen> createState() => _DebugSleepBufferScreenState();
}

class _DebugSleepBufferScreenState extends State<DebugSleepBufferScreen> {
  String rawSleepBuf = "Loading...";
  Map<String, String> dailyJsonContents = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final sleepBuf = File('${appDir.path}/fs/buffer/sleep_buf.tmp');
      final dailyDir = Directory('${appDir.path}/fs/daily');

      String bufContent = "File not found or empty.";
      if (sleepBuf.existsSync()) {
        bufContent = await sleepBuf.readAsString();
      }

      Map<String, String> dailyData = {};
      if (dailyDir.existsSync()) {
        final files = dailyDir.listSync();
        for (var file in files) {
          if (file is File && file.path.endsWith('.json')) {
            final content = await file.readAsString();
            final json = jsonDecode(content);
            // Extract just the sleep part beautifully
            if (json.containsKey('sleep')) {
              dailyData[file.path.split(Platform.pathSeparator).last] =
                  const JsonEncoder.withIndent('  ').convert(json['sleep']);
            }
          }
        }
      }

      setState(() {
        rawSleepBuf = bufContent;
        dailyJsonContents = dailyData;
      });
    } catch (e) {
      setState(() {
        rawSleepBuf = "Error loading data: \$e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sleep Buffer Logs")),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("fs/buffer/sleep_buf.tmp",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey.withOpacity(0.1),
                    child: SelectableText(rawSleepBuf, style: const TextStyle(fontFamily: 'monospace')),
                  ),
                  const SizedBox(height: 24),
                  const Text("Daily JSON Sleep Calculations",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final key = dailyJsonContents.keys.elementAt(index);
                final value = dailyJsonContents[key]!;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ExpansionTile(
                    title: Text(key),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        color: Colors.grey.withOpacity(0.1),
                        child: SelectableText(value, style: const TextStyle(fontFamily: 'monospace')),
                      )
                    ],
                  ),
                );
              },
              childCount: dailyJsonContents.length,
            ),
          ),
        ],
      ),
    );
  }
}
