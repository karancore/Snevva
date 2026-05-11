import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../consts/consts.dart';

class DebugPeriodSyncScreen extends StatefulWidget {
  const DebugPeriodSyncScreen({super.key});

  @override
  State<DebugPeriodSyncScreen> createState() => _DebugPeriodSyncScreenState();
}

class _DebugPeriodSyncScreenState extends State<DebugPeriodSyncScreen> {
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? logsJson = prefs.getString('period_sync_debug_logs');
    if (logsJson != null) {
      try {
        final List<dynamic> parsed = jsonDecode(logsJson);
        setState(() {
          _logs = parsed.map((e) => e.toString()).toList();
          _logs = _logs.reversed.toList(); // newest first
        });
      } catch (e) {
        setState(() {
          _logs = ['Error parsing logs: $e'];
        });
      }
    }
  }

  Future<void> _clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('period_sync_debug_logs');
    setState(() {
      _logs = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Period Sync Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: _logs.isEmpty
          ? const Center(child: Text('No logs found.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final log = _logs[index];
                final isError = log.contains('❌') || log.contains('⚠️') || log.contains('Failed') || log.contains('Error');
                final isSuccess = log.contains('✅') || log.contains('200');
                
                Color? color;
                if (isError) color = Colors.red.shade100;
                if (isSuccess) color = Colors.green.shade100;

                return Container(
                  color: color,
                  padding: const EdgeInsets.all(8.0),
                  child: SelectableText(
                    log,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
    );
  }
}
