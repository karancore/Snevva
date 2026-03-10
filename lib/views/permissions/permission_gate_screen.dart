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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Permission Required'),
          content: Text(
            '$permissionName is required for step and sleep tracking. '
            'Please enable it in Settings.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: mediumGrey,
                  height: 1.35,
                ),
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
              child: Text(
                'Open Settings',
                style: TextStyle(color: AppColors.primaryColor),
              ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
    final Color cardColor =
        isDarkMode ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final Color cardBorder =
        isDarkMode ? Colors.white.withValues(alpha: 0.12) : Colors.black12;

    Widget permissionTile(
      PermissionRequirement req,
      PermissionStatus status,
    ) {
      final granted = _isGranted(status);
      final Color accent = granted ? Colors.green : AppColors.primaryColor;
      final Color badgeBg = granted
          ? Colors.green.withValues(alpha: 0.12)
          : AppColors.primaryColor.withValues(alpha: 0.12);

      String badgeText = 'Required';
      if (granted) {
        badgeText = 'Granted';
      } else if (!req.requestable) {
        badgeText = 'Enable in Settings';
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: badgeBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                granted ? Icons.check_rounded : Icons.lock_outline_rounded,
                size: 18,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    req.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    req.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: mediumGrey,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeText,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      );
    }

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
          elevation: 0,
          backgroundColor: backgroundColor,
          foregroundColor: isDarkMode ? Colors.white : Colors.black,
          title: const Text('Enable Tracking'),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 48,
                                width: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.health_and_safety_rounded,
                                  color: AppColors.primaryColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Keep Tracking Active',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'This app tracks your steps and sleep even when the app is closed.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                            color: mediumGrey,
                                            height: 1.4,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            children: [
                              for (int i = 0;
                                  i < widget.requirements.length;
                                  i++) ...[
                                if (i > 0)
                                  Divider(
                                    height: 1,
                                    color: cardBorder,
                                  ),
                                permissionTile(
                                  widget.requirements[i],
                                  _statuses[widget.requirements[i].id] ??
                                      PermissionStatus.denied,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                _requesting
                                    ? null
                                    : (_allGranted
                                        ? () =>
                                            Navigator.of(context).pop(true)
                                        : _requestSequentially),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _requesting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _allGranted
                                        ? 'Continue'
                                        : 'Grant Permissions',
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _requesting
                                ? null
                                : () async {
                                    final skip = await _confirmSkip();
                                    if (skip && mounted) {
                                      Navigator.of(context).pop(false);
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              foregroundColor: AppColors.primaryColor,
                              side: BorderSide(color: AppColors.primaryColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Skip for Now'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (!_allGranted)
                          Text(
                            'You can update permissions later in Settings.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: mediumGrey),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
