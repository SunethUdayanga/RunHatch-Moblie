import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:runhutch/functions/bl_functions.dart';
import 'package:runhutch/services/background_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _urlController = TextEditingController();
  final _intervalController = TextEditingController();
  final _backgroundService = BackgroundService.instance;

  bool _isLoading = true;
  bool _isServiceRunning = false;
  bool _isTransitioning = false;
  int _requestCount = 0;
  String? _lastStatus;
  StreamSubscription<ServiceStatus>? _statusSubscription;

  late final AnimationController _idlePulseController;
  late final AnimationController _ringController;
  late final AnimationController _stateController;
  late final Animation<double> _idleScale;
  late final Animation<double> _stateProgress;

  static const _orange = Color(0xFFFF6B35);
  static const _surface = Color(0xFF1E1E2C);
  static const _surfaceLight = Color(0xFF2A2A3D);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _idlePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _stateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _idleScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _idlePulseController, curve: Curves.easeInOut),
    );

    _stateProgress = CurvedAnimation(
      parent: _stateController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _idlePulseController.repeat(reverse: true);
    _statusSubscription = _backgroundService.statusStream.listen(_applyStatus);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _backgroundService.initialize();
    await _backgroundService.refreshStatus();
    await _loadSettings();
    if (!mounted) return;

    setState(() {
      _isServiceRunning = _backgroundService.isRunning;
      _requestCount = _backgroundService.requestCount;
      _lastStatus = _backgroundService.lastStatus;
    });
    _syncAnimations(_backgroundService.isRunning);
  }

  void _applyStatus(ServiceStatus status) {
    if (!mounted) return;
    setState(() {
      _isServiceRunning = status.isActive;
      _requestCount = status.requestCount;
      _lastStatus = status.lastStatus;
    });
    _syncAnimations(status.isActive);
  }

  void _syncAnimations(bool isRunning) {
    if (isRunning) {
      if (_stateController.value != 1) {
        _stateController.value = 1;
      }
      if (!_ringController.isAnimating) {
        _ringController.repeat();
      }
      _idlePulseController.stop();
    } else {
      if (_stateController.value != 0) {
        _stateController.value = 0;
      }
      _ringController.stop();
      if (!_idlePulseController.isAnimating) {
        _idlePulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _backgroundService.refreshStatus();
    }
  }

  Future<void> _loadSettings() async {
    final settings = await BlFunctions.loadSettings();
    if (!mounted) return;

    setState(() {
      _urlController.text = settings.url;
      _intervalController.text = settings.intervalSeconds.toString();
      _isLoading = false;
    });
  }

  Future<void> _toggleService() async {
    if (_isTransitioning) return;

    setState(() => _isTransitioning = true);

    if (_backgroundService.isRunning) {
      _idlePulseController.stop();
      await _stateController.reverse();
      _ringController.stop();
      _backgroundService.stop();
      _idlePulseController.repeat(reverse: true);

      if (!mounted) return;
      setState(() {
        _isServiceRunning = false;
        _isTransitioning = false;
      });
      return;
    }

    _idlePulseController.stop();
    await _stateController.forward();
    _ringController.repeat();
    await _backgroundService.start();

    if (!mounted) return;
    setState(() {
      _isServiceRunning = true;
      _isTransitioning = false;
    });
  }

  void _openConfigureSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ConfigureSheet(
        urlController: _urlController,
        intervalController: _intervalController,
        onSaved: () {
          Navigator.pop(sheetContext);
          _showMessage('Settings saved.');
        },
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _surfaceLight,
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusSubscription?.cancel();
    _idlePulseController.dispose();
    _ringController.dispose();
    _stateController.dispose();
    _urlController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _orange),
            )
          : Stack(
              children: [
                const _AmbientBackground(),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        _Header(onConfigure: _openConfigureSheet),
                        const Spacer(flex: 2),
                        _BoosterHero(
                          isRunning: _isServiceRunning,
                          isTransitioning: _isTransitioning,
                          idleScale: _idleScale,
                          stateProgress: _stateProgress,
                          ringAnimation: _ringController,
                          onTap: _toggleService,
                        ),
                        const SizedBox(height: 28),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.15),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _isServiceRunning
                              ? _LiveStatusPanel(
                                  key: const ValueKey('running'),
                                  requestCount: _requestCount,
                                  lastStatus: _lastStatus,
                                )
                              : _IdleHint(key: const ValueKey('idle')),
                        ),
                        const Spacer(flex: 3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF14141F),
                Color(0xFF1E1E2C),
                Color(0xFF2D1F1A),
              ],
            ),
          ),
        ),
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFF6B35).withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFE85D04).withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onConfigure});

  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RunHutch',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            Text(
              'Network Booster',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
            ),
          ],
        ),
        const Spacer(),
        _GlassIconButton(
          icon: Icons.tune_rounded,
          label: 'Configure',
          onTap: onConfigure,
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoosterHero extends StatelessWidget {
  const _BoosterHero({
    required this.isRunning,
    required this.isTransitioning,
    required this.idleScale,
    required this.stateProgress,
    required this.ringAnimation,
    required this.onTap,
  });

  final bool isRunning;
  final bool isTransitioning;
  final Animation<double> idleScale;
  final Animation<double> stateProgress;
  final Animation<double> ringAnimation;
  final VoidCallback onTap;

  static const _size = 220.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([idleScale, stateProgress, ringAnimation]),
      builder: (context, child) {
        final runningT = stateProgress.value;
        final idleT = 1 - runningT;
        final scale = idleT * idleScale.value + runningT * 1.02;
        final glowStrength = 0.25 + runningT * 0.45;

        return GestureDetector(
          onTap: isTransitioning ? null : onTap,
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: _size + 60,
              height: _size + 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (runningT > 0.01)
                    ...List.generate(3, (i) {
                      final phase = (ringAnimation.value + i * 0.33) % 1.0;
                      final expand = 1 + phase * 0.35;
                      final opacity = (1 - phase) * 0.35 * runningT;
                      return Transform.scale(
                        scale: expand,
                        child: Container(
                          width: _size,
                          height: _size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFFF6B35)
                                  .withValues(alpha: opacity),
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }),
                  if (runningT > 0.01)
                    Transform.rotate(
                      angle: ringAnimation.value * 2 * math.pi,
                      child: Container(
                        width: _size + 24,
                        height: _size + 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF8A50)
                                .withValues(alpha: 0.5 * runningT),
                            width: 2.5,
                          ),
                        ),
                        child: CustomPaint(
                          painter: _DashedRingPainter(
                            color: const Color(0xFFFF6B35)
                                .withValues(alpha: 0.8 * runningT),
                          ),
                        ),
                      ),
                    ),
                  Container(
                    width: _size,
                    height: _size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(
                            const Color(0xFFFF8A50),
                            const Color(0xFFFF6B35),
                            runningT,
                          )!,
                          Color.lerp(
                            const Color(0xFFFF6B35),
                            const Color(0xFFE85D04),
                            runningT,
                          )!,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B35)
                              .withValues(alpha: glowStrength),
                          blurRadius: 40 + runningT * 30,
                          spreadRadius: 4 + runningT * 8,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: isRunning ? 1 : 0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, t, child) {
              return Transform.scale(
                scale: 1 + t * 0.15,
                child: Icon(
                  isRunning ? Icons.bolt_rounded : Icons.pets_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 400),
            style: TextStyle(
              color: Colors.white,
              fontSize: isRunning ? 17 : 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
            child: Text(isRunning ? 'Boosting...' : 'Network Booster'),
          ),
          const SizedBox(height: 4),
          Text(
            isRunning ? 'Tap to stop' : 'Tap to start',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final radius = size.width / 2 - 2;
    const dashCount = 12;
    const sweep = 2 * math.pi / dashCount * 0.45;

    for (var i = 0; i < dashCount; i++) {
      final start = i * 2 * math.pi / dashCount;
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: radius,
        ),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _IdleHint extends StatelessWidget {
  const _IdleHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Ready when you are',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.45),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _LiveStatusPanel extends StatelessWidget {
  const _LiveStatusPanel({
    super.key,
    required this.requestCount,
    this.lastStatus,
  });

  final int requestCount;
  final String? lastStatus;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x664ADE80),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Service Active',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$requestCount requests'
                      '${lastStatus != null ? ' · $lastStatus' : ''}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfigureSheet extends StatefulWidget {
  const _ConfigureSheet({
    required this.urlController,
    required this.intervalController,
    required this.onSaved,
  });

  final TextEditingController urlController;
  final TextEditingController intervalController;
  final VoidCallback onSaved;

  @override
  State<_ConfigureSheet> createState() => _ConfigureSheetState();
}

class _ConfigureSheetState extends State<_ConfigureSheet> {
  bool _isSaving = false;

  static const _orange = Color(0xFFFF6B35);

  Future<void> _save() async {
    final url = widget.urlController.text.trim();
    final interval = int.tryParse(widget.intervalController.text.trim());

    if (interval == null || interval < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid countdown of at least 1 second.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    await BlFunctions.saveSettings(
      url: url.isEmpty ? BlFunctions.defaultUrl : url,
      intervalSeconds: interval,
    );

    if (!mounted) return;

    if (url.isEmpty) {
      widget.urlController.text = BlFunctions.defaultUrl;
    }

    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF252536),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Configure',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Set your target URL and request interval.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              _SheetField(
                controller: widget.urlController,
                label: 'Request URL',
                hint: BlFunctions.defaultUrl,
                icon: Icons.link_rounded,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              _SheetField(
                controller: widget.intervalController,
                label: 'Countdown interval',
                hint: '30',
                icon: Icons.timer_outlined,
                suffix: 'sec',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.suffix,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? suffix;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
            prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.5)),
            suffixText: suffix,
            suffixStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFFFF6B35),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
