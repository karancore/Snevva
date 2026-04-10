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
  Map<String, Map<String, dynamic>> dailyJsonContents = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final sleepBuf = File('${appDir.path}/fs/buffer/sleep_buf.tmp');
      final syncQueue = File('${appDir.path}/fs/sync_queue.json');
      final dailyDir = Directory('${appDir.path}/fs/daily');
      final apiLogsFile = File('${appDir.path}/fs/api_sync_logs.json');

      String bufContent = "File not found or empty.";
      if (sleepBuf.existsSync()) {
        bufContent = await sleepBuf.readAsString();
      }

      List<String> queueList = [];
      if (syncQueue.existsSync()) {
        final queueContent = await syncQueue.readAsString();
        try {
          final decodedQueue = jsonDecode(queueContent) as List;
          queueList = decodedQueue.map((e) => e.toString()).toList();
        } catch (_) {}
      }

      List<dynamic> apiLogs = [];
      if (apiLogsFile.existsSync()) {
        try {
          apiLogs = jsonDecode(await apiLogsFile.readAsString());
        } catch (_) {}
      }

      Map<String, Map<String, dynamic>> dailyData = {};
      if (dailyDir.existsSync()) {
        final files = dailyDir.listSync();
        for (var file in files) {
          if (file is File && file.path.endsWith('.json')) {
            final fileName = file.path.split(Platform.pathSeparator).last;
            final dateKey = fileName.replaceAll('.json', '');

            final content = await file.readAsString();
            final json = jsonDecode(content);
            
            // Extract just the sleep part beautifully
            if (json.containsKey('sleep')) {
              final isPending = queueList.contains(dateKey);

              // Filter API logs strictly for this dateKey and SLEEP type
              final relatedLogs = apiLogs.where((l) => 
                  l['dateKeyDate'] == dateKey && l['type'] == 'SLEEP'
              ).toList();

              dailyData[fileName] = {
                'isPending': isPending,
                'sleep': const JsonEncoder.withIndent('  ').convert(json['sleep']),
                'logs': relatedLogs,
              };
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
        rawSleepBuf = "Error loading data: $e";
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
                final bool isPending = value['isPending'] as bool;
                final String sleepStr = value['sleep'] as String;
                final List<dynamic> logs = value['logs'] as List<dynamic>;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ExpansionTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
                         Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPending ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isPending ? "IN QUEUE PENDING" : "SYNCED",
                            style: TextStyle(
                              fontSize: 10,
                              color: isPending ? Colors.orange[800] : Colors.green[800],
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
                        child: SelectableText(sleepStr, style: const TextStyle(fontFamily: 'monospace')),
                      ),
                      if (logs.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text("API Sync Activity:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              ...logs.reversed.map((log) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                child: Text(
                                  "[${log['timestamp']}] HTTP ${log['responseCode']}\n${log['message']}",
                                  style: TextStyle(fontSize: 12, color: Colors.blueGrey[800], fontFamily: 'monospace'),
                                ),
                              ))
                            ],
                          ),
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

