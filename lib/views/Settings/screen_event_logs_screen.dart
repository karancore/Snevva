import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:snevva/services/sleep/sleep_noticing_service.dart';

class ScreenEventLogsScreen extends StatefulWidget {
  const ScreenEventLogsScreen({super.key});

  @override
  State<ScreenEventLogsScreen> createState() => _ScreenEventLogsScreenState();
}

class _ScreenEventLogsScreenState extends State<ScreenEventLogsScreen> {
  final SleepNoticingService _sleepNoticingService = SleepNoticingService();
  final Duration _refreshInterval = Duration(seconds: 2);

  Timer? _refreshTimer;
  bool _isLoading = true;
  bool _isClearing = false;
  List<ScreenEventLogEntry> _events = const <ScreenEventLogEntry>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadEvents());
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      unawaited(_loadEvents(showLoader: false));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEvents({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final events = await _sleepNoticingService.readLoggedEvents();
    print("Events : ${events.join('\n')}");
    final eventFiles = File('event_logs.txt');
    final sink = eventFiles.openWrite(mode: FileMode.append);
    sink.writeAll(events, '\n');
    await sink.flush();
    await sink.close();

    if (!mounted) return;

    setState(() {
      _events = events;
      _isLoading = false;
    });
  }

  Future<void> _clearEvents() async {
    final shouldClear =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Clear screen event logs?'),
              content: const Text(
                'This removes the stored SCREEN_ON and SCREEN_OFF event history from local files.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Clear'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldClear || !mounted) return;

    setState(() {
      _isClearing = true;
    });

    await _sleepNoticingService.clearLoggedEvents();
    await _loadEvents(showLoader: false);

    if (!mounted) return;
    setState(() {
      _isClearing = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Screen event logs cleared')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Event Logs'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _loadEvents(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Clear logs',
            onPressed: _isClearing ? null : _clearEvents,
            icon:
                _isClearing
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live local history of SCREEN_ON and SCREEN_OFF events.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '${_events.length} events stored',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                      onRefresh: _loadEvents,
                      child:
                          _events.isEmpty
                              ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 140),
                                  Center(
                                    child: Text('No screen events logged yet'),
                                  ),
                                ],
                              )
                              : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(16),
                                itemCount: _events.length,
                                separatorBuilder:
                                    (_, _) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final event = _events[index];
                                  final isOn = event.type == 'SCREEN_ON';
                                  final chipColor =
                                      isOn ? Colors.green : Colors.indigo;

                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: theme.dividerColor.withOpacity(
                                          0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: chipColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            event.type,
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                                  color: chipColor,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _formatTimestamp(
                                                  event.timestamp,
                                                ),
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Stored in ${event.dateKey}.jsonl',
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                              if (event.synthetic) ...[
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Synthetic seed event created when an active sleep window was restored.',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color:
                                                            theme
                                                                .colorScheme
                                                                .secondary,
                                                      ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                    ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final month = _twoDigits(local.month);
    final day = _twoDigits(local.day);
    final hour = _twoDigits(local.hour);
    final minute = _twoDigits(local.minute);
    final second = _twoDigits(local.second);
    return '${local.year}-$month-$day  $hour:$minute:$second';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
