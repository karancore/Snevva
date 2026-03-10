import 'package:permission_handler/permission_handler.dart';

import '../../consts/consts.dart';
import '../../services/permission_manager.dart';

class PermissionGateScreen extends StatefulWidget {
  const PermissionGateScreen({
    super.key,
    required this.permissionManager,
    required this.requirements,
  });

  final PermissionManager permissionManager;
  final List<PermissionRequirement> requirements;

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen>
    with WidgetsBindingObserver {
  final Map<String, PermissionStatus> _statuses = {};
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatuses();
    }
  }

  Future<void> _refreshStatuses() async {
    final updated = await widget.permissionManager.checkStatuses(
      widget.requirements,
    );
    if (!mounted) return;
    setState(() {
      _statuses
        ..clear()
        ..addAll(updated);
    });
  }

  bool _isGranted(PermissionStatus status) {
    return widget.permissionManager.isGranted(status);
  }

  bool get _allGranted {
    if (_statuses.isEmpty) return false;
    return widget.requirements.every((req) {
      final status = _statuses[req.id] ?? PermissionStatus.denied;
      return _isGranted(status);
    });
  }

  Future<void> _showSettingsDialog(String permissionName) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: Text(
            '$permissionName is required for step and sleep tracking. '
            'Please enable it in Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Not Now'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestSequentially() async {
    if (_requesting) return;
    setState(() => _requesting = true);

    for (final req in widget.requirements) {
      final currentStatus = _statuses[req.id] ?? await req.checkStatus();
      _statuses[req.id] = currentStatus;

      if (_isGranted(currentStatus)) {
        continue;
      }

      if (!req.requestable) {
        continue;
      }

      final result = await req.request();
      _statuses[req.id] = result;
      if (mounted) setState(() {});

      if (!_isGranted(result)) {
        await _showSettingsDialog(req.title);
      }
    }

    await _refreshStatuses();
    if (!mounted) return;

    setState(() => _requesting = false);

    if (_allGranted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<bool> _confirmSkip() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Skip Permissions?'),
          content: const Text(
            'Step and sleep tracking will not work until permissions are granted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Skip'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor =
        isDarkMode ? scaffoldColorDark : scaffoldColorLight;

    return WillPopScope(
      onWillPop: () async {
        if (_requesting) return false;
        final skip = await _confirmSkip();
        if (skip && mounted) {
          Navigator.of(context).pop(false);
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Enable Tracking'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'This app tracks your steps and sleep even when the app is closed.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: widget.requirements.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final req = widget.requirements[index];
                      final status =
                          _statuses[req.id] ?? PermissionStatus.denied;
                      final granted = _isGranted(status);

                      return ListTile(
                        leading: Icon(
                          granted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color:
                              granted
                                  ? Colors.green
                                  : (isDarkMode
                                      ? Colors.white38
                                      : Colors.black38),
                        ),
                        title: Text(req.title),
                        subtitle: Text(req.description),
                        trailing:
                            granted
                                ? const Icon(Icons.check, color: Colors.green)
                                : (req.requestable
                                    ? const Icon(Icons.chevron_right)
                                    : const SizedBox.shrink()),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _requesting
                            ? null
                            : (_allGranted
                                ? () => Navigator.of(context).pop(true)
                                : _requestSequentially),
                    child:
                        _requesting
                            ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : Text(
                              _allGranted ? 'Continue' : 'Grant Permissions',
                            ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: AppColors.primaryColor),
                    ),
                    child: Text('Skip for Now'),
                  ),
                ),

                const SizedBox(height: 8),
                if (!_allGranted)
                  Text(
                    'You can update permissions later in Settings.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: mediumGrey),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
