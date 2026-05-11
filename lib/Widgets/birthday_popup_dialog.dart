import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BirthdayPopupHelper {
  BirthdayPopupHelper._();

  static Future<void> showIfBirthday(
    BuildContext context,

    Map<String, dynamic> userMap,
  ) async {
    // ── Parse separate DOB fields ──────────────────────────────────────────

    final dobDay = _parseInt(userMap['DayOfBirth']);

    final dobMonth = _parseInt(userMap['MonthOfBirth']);

    final dobYear = _parseInt(userMap['YearOfBirth']);

    if (dobDay == null || dobMonth == null) {
      debugPrint(
        '🎂 BirthdayPopup: DayOfBirth or MonthOfBirth missing/invalid — skipping',
      );

      return;
    }

    final now = DateTime.now();

    debugPrint(
      '🎂 BirthdayPopup: today=${now.day}/${now.month}, dob=$dobDay/$dobMonth',
    );

    if (now.day != dobDay || now.month != dobMonth) {
      debugPrint('🎂 BirthdayPopup: not birthday today — skipping');

      return;
    }

    // ── Derive display info ────────────────────────────────────────────────

    final name = userMap['Name']?.toString() ?? 'You';

    final profileUrl = userMap['ProfilePicture']?.toString();

    final age = dobYear != null ? now.year - dobYear : null;

    final gender = userMap['Gender']?.toString();

    final address = userMap['AddressByUser']?.toString() ?? '';

    final city = address.isNotEmpty ? address : null;

    debugPrint(
      "🎂 BirthdayPopup: It's $name\'s birthday! age=$age Showing popup…",
    );

    if (!context.mounted) return;

    // In BirthdayPopupHelper.showIfBirthday — change ONE line:
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      // ✅ force user to tap a button
      barrierLabel: 'Birthday',
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder:
          (_, __, ___) => BirthdayDialog(
            name: name,
            age: age,
            profileUrl: profileUrl,
            gender: gender,
            city: city,
          ),
      transitionBuilder:
          (_, anim, __, child) => ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
            child: FadeTransition(opacity: anim, child: child),
          ),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;

    return int.tryParse(value.toString().trim());
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// Dialog shell

// ─────────────────────────────────────────────────────────────────────────────
const String birthdayMusic = "sounds/birthday-sound.mp3";

class BirthdayDialog extends StatefulWidget {
  const BirthdayDialog({
    required this.name,

    required this.age,

    required this.profileUrl,

    required this.gender,

    required this.city,
  });

  final String name;

  final int? age;

  final String? profileUrl;

  final String? gender;

  final String? city;

  @override
  State<BirthdayDialog> createState() => _BirthdayDialogState();
}

class _BirthdayDialogState extends State<BirthdayDialog>
    with TickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey();

  bool _isCapturing = false;

  late final AnimationController _cardController;

  late final Animation<double> _cardAnim;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    _cardController = AnimationController(
      vsync: this,

      duration: const Duration(milliseconds: 700),
    );

    _cardAnim = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutBack,
    );

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _cardController.forward();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _playBirthdayMusic();
    });
  }

  Future<void> _playBirthdayMusic() async {
    try {
      debugPrint('🎵 Trying to play: $birthdayMusic');
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(0.7);
      final source = AssetSource(birthdayMusic);
      debugPrint('🎵 Source created: ${source.path}');
      await _audioPlayer.play(source);
      debugPrint('🎵 Playing!');
    } catch (e, stack) {
      debugPrint('🎵 Birthday music error: $e');
      debugPrint('🎵 Stack: $stack'); // ✅ full error
    }
  }

  @override
  void dispose() {
    _cardController.dispose();
    _audioPlayer.stop(); // ✅ stop music when dialog closes
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _shareCard() async {
    if (_isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);

      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (data == null) return;

      final tempDir = await getTemporaryDirectory();

      final file = File('${tempDir.path}/birthday_card.png');

      await file.writeAsBytes(data.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],

        text: '🎂 Happy Birthday ${widget.name}! Wishing you a wonderful day!',
      );
    } catch (e) {
      debugPrint('Share error: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  // _BirthdayDialogState.build — fix overflow
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = MediaQuery.of(context).size.height;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: size.width * 0.88,

          child: SingleChildScrollView(
            // ✅ prevents overflow
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ Reduced height so it fits smaller screens
                    ScaleTransition(
                      scale: _cardAnim,
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: _BirthdayCard(
                          name: widget.name,
                          age: widget.age,
                          profileUrl: widget.profileUrl,
                          gender: widget.gender,
                          city: widget.city,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.share_rounded,
                            label: _isCapturing ? 'Preparing…' : 'Share Card',
                            isPrimary: true,
                            onTap: _isCapturing ? null : _shareCard,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.celebration_rounded,
                            label: 'Thank you!',
                            isPrimary: false,
                            onTap:
                                () =>
                                    Navigator.of(
                                      context,
                                    ).pop(), // ✅ only way to close
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: SizedBox(
                      width: double.infinity, // ✅ was 180
                      child: Lottie.asset(
                        'assets/animations/Birthday_Confetti_Ballon.json',
                        repeat: true,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// 1:1 birthday card

// ─────────────────────────────────────────────────────────────────────────────

class _BirthdayCard extends StatelessWidget {
  const _BirthdayCard({
    required this.name,

    required this.age,

    required this.profileUrl,

    required this.gender,

    required this.city,
  });

  final String name;

  final int? age;

  final String? profileUrl;

  final String? gender;

  final String? city;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = constraints.maxWidth;

        return Container(
          width: s,
          height: s + 80,

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),

            gradient: const LinearGradient(
              begin: Alignment.topLeft,

              end: Alignment.bottomRight,

              colors: [Color(0xFF6A0DAD), Color(0xFFB44FD1), Color(0xFFFF6B9D)],
            ),

            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB44FD1).withOpacity(0.5),

                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),

          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -30,
                child: _Circle(size: 120, opacity: 0.12),
              ),

              Positioned(
                bottom: -20,
                left: -20,
                child: _Circle(size: 100, opacity: 0.10),
              ),

              Positioned(
                top: s * 0.35,
                right: -15,
                child: _Circle(size: 70, opacity: 0.08),
              ),

              Padding(
                padding: EdgeInsets.all(s * 0.07),

                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    Text('🎂', style: TextStyle(fontSize: s * 0.10)),

                    SizedBox(height: s * 0.025),

                    Text(
                      'Happy Birthday!',

                      style: TextStyle(
                        fontSize: s * 0.090,

                        fontWeight: FontWeight.w800,

                        color: Colors.white,

                        letterSpacing: 0.5,

                        shadows: const [
                          Shadow(
                            color: Color(0x55000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),

                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: s * 0.035),

                    _ProfileAvatar(
                      profileUrl: profileUrl,
                      name: name,
                      size: s * 0.25,
                    ),

                    SizedBox(height: s * 0.030),

                    Text(
                      name,

                      style: TextStyle(
                        fontSize: s * 0.070,

                        fontWeight: FontWeight.bold,

                        color: Colors.white,
                      ),

                      textAlign: TextAlign.center,

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,
                    ),

                    if (age != null) ...[
                      SizedBox(height: s * 0.012),

                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: s * 0.04,
                          vertical: s * 0.010,
                        ),

                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),

                          borderRadius: BorderRadius.circular(50),

                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),

                        child: Text(
                          'Turning $age today 🎉',

                          style: TextStyle(
                            fontSize: s * 0.038,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    if (gender != null || city != null) ...[
                      SizedBox(height: s * 0.016),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          if (gender != null) ...[
                            Icon(
                              gender!.toLowerCase().contains('female')
                                  ? Icons.female_rounded
                                  : Icons.male_rounded,

                              color: Colors.white70,
                              size: s * 0.034,
                            ),

                            const SizedBox(width: 3),

                            Text(
                              gender!,
                              style: TextStyle(
                                fontSize: s * 0.034,
                                color: Colors.white70,
                              ),
                            ),
                          ],

                          if (gender != null && city != null)
                            Text(
                              '  •  ',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: s * 0.034,
                              ),
                            ),

                          if (city != null) ...[
                            Icon(
                              Icons.location_on_outlined,
                              color: Colors.white70,
                              size: s * 0.034,
                            ),

                            const SizedBox(width: 2),

                            Flexible(
                              child: Text(
                                city!,
                                style: TextStyle(
                                  fontSize: s * 0.034,
                                  color: Colors.white70,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],

                    SizedBox(height: s * 0.026),

                    Text(
                      'May this year bring you good health,\nhappiness & amazing moments! 🌟',

                      style: TextStyle(
                        fontSize: s * 0.036,

                        color: Colors.white.withOpacity(0.88),

                        height: 1.5,
                      ),

                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: s * 0.020),

                    Text(
                      '— from Snevva Health 💙',

                      style: TextStyle(
                        fontSize: s * 0.028,

                        color: Colors.white.withOpacity(0.55),

                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// Sub-widgets

// ─────────────────────────────────────────────────────────────────────────────

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.profileUrl,
    required this.name,
    required this.size,
  });

  final String? profileUrl;

  final String name;

  final double size;

  @override
  Widget build(BuildContext context) {
    final initials =
        name
            .trim()
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase();

    ImageProvider? provider;

    if (profileUrl != null && profileUrl!.isNotEmpty && profileUrl != 'null') {
      provider =
          profileUrl!.startsWith('http')
              ? NetworkImage(profileUrl!) as ImageProvider
              : FileImage(File(profileUrl!));
    }

    return Container(
      width: size,
      height: size,

      decoration: BoxDecoration(
        shape: BoxShape.circle,

        border: Border.all(color: Colors.white, width: 3),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: ClipOval(
        child:
            provider != null
                ? Image(
                  image: provider,

                  fit: BoxFit.cover,

                  errorBuilder:
                      (_, __, ___) => _Initials(initials: initials, size: size),
                )
                : _Initials(initials: initials, size: size),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials, required this.size});

  final String initials;

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white.withOpacity(0.25),

    alignment: Alignment.center,

    child: Text(
      initials,

      style: TextStyle(
        fontSize: size * 0.35,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  );
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.opacity});

  final double size, opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,

    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,

    required this.label,

    required this.isPrimary,

    this.onTap,
  });

  final IconData icon;

  final String label;

  final bool isPrimary;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,

    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),

      decoration: BoxDecoration(
        gradient:
            isPrimary
                ? const LinearGradient(
                  colors: [Color(0xFF6A0DAD), Color(0xFFB44FD1)],
                )
                : null,

        color: isPrimary ? null : Colors.white.withOpacity(0.18),

        borderRadius: BorderRadius.circular(14),

        border: Border.all(
          color: Colors.white.withOpacity(isPrimary ? 0 : 0.4),
        ),

        boxShadow:
            isPrimary
                ? [
                  BoxShadow(
                    color: const Color(0xFF6A0DAD).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
                : [],
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(icon, color: Colors.white, size: 18),

          const SizedBox(width: 6),

          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  );
}
