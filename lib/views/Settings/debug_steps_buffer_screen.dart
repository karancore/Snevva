import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class DebugStepsBufferScreen extends StatefulWidget {
  const DebugStepsBufferScreen({super.key});

  @override
  State<DebugStepsBufferScreen> createState() => _DebugStepsBufferScreenState();
}

class _DebugStepsBufferScreenState extends State<DebugStepsBufferScreen> {
  String rawStepsBuf = "Loading...";
  String syncQueueContent = "Loading...";
  Map<String, Map<String, dynamic>> dailyJsonContents = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final stepsBuf = File('${appDir.path}/fs/buffer/steps_buf.tmp');
      final syncQueue = File('${appDir.path}/fs/sync_queue.json');
      final dailyDir = Directory('${appDir.path}/fs/daily');

      String bufContent = "File not found or empty.";
      if (stepsBuf.existsSync()) {
        bufContent = await stepsBuf.readAsString();
      }

      String queueContent = "File not found or empty.";
      if (syncQueue.existsSync()) {
        queueContent = await syncQueue.readAsString();
      }

      Map<String, Map<String, dynamic>> dailyData = {};
      if (dailyDir.existsSync()) {
        final files = dailyDir.listSync();
        for (var file in files) {
          if (file is File && file.path.endsWith('.json')) {
            final content = await file.readAsString();
            final json = jsonDecode(content);
            
            final sentStatus = json['sent'] ?? false;
            final stepsObj = json['steps'] ?? {};

            dailyData[file.path.split(Platform.pathSeparator).last] = {
              'sent': sentStatus,
              'steps': const JsonEncoder.withIndent('  ').convert(stepsObj)
            };
          }
        }
      }

      setState(() {
        rawStepsBuf = bufContent;
        syncQueueContent = queueContent;
        dailyJsonContents = dailyData;
      });
    } catch (e) {
      setState(() {
        rawStepsBuf = "Error loading data: \$e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Steps Buffer & Sync Queue logs")),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("fs/sync_queue.json (Sync Queue)",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey.withOpacity(0.1),
                    child: SelectableText(syncQueueContent, style: const TextStyle(fontFamily: 'monospace')),
                  ),
                  const SizedBox(height: 24),
                  const Text("fs/buffer/steps_buf.tmp",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Container(
                    height: 200, // Fixed height for steps buffer as it might be large
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey.withOpacity(0.1),
                    child: SingleChildScrollView(
                      child: SelectableText(rawStepsBuf, style: const TextStyle(fontFamily: 'monospace')),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text("Daily JSON Steps & Sync Flags",
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
                final bool isSent = value['sent'] as bool;
                final String stepsStr = value['steps'] as String;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ExpansionTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(key),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSent ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isSent ? "PUSHED TO API" : "PENDING",
                            style: TextStyle(
                              fontSize: 12,
                              color: isSent ? Colors.green[800] : Colors.orange[800],
                              fontWeight: FontWeight.bold,
                            )
                          ),
                        )
                      ],
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        color: Colors.grey.withOpacity(0.1),
                        child: SelectableText(stepsStr, style: const TextStyle(fontFamily: 'monospace')),
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
