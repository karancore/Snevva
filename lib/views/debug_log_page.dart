import 'package:flutter/material.dart';
import 'package:snevva/common/debug_logger.dart';

class DebugLogPage extends StatelessWidget {
  const DebugLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🛠 Debug Logs"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => DebugLogger().clear(),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: DebugLogger(),
        builder: (_, __) {
          final logs = DebugLogger().logs;

          if (logs.isEmpty) {
            return const Center(child: Text("No logs yet"));
          }

          return ListView.builder(
            reverse: true,
            itemCount: logs.length,
            itemBuilder: (_, i) {
              final log = logs[i];
              return ListTile(
                dense: true,
                title: Text(
                  "[${log.type}] ${log.message}",
                  style: TextStyle(
                    color: log.type == "ERROR"
                        ? Colors.red
                        : log.type == "API"
                            ? Colors.blue
                            : Colors.black,
                  ),
                ),
                subtitle: Text(log.time.toString()),
              );
            },
          );
        },
      ),
    );
  }
}
