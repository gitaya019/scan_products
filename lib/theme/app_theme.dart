import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tokens de diseño compartidos por toda la app.
///
/// La paleta es "neón sobre cristal": un fondo profundo con manchas de
/// aurora (cian / violeta / magenta) y superficies translúcidas encima.
class AppColors {
  const AppColors._();

  // Base oscura
  static const Color inkDeep = Color(0xFF07060F);
  static const Color inkMid = Color(0xFF0F0D1C);
  static const Color inkSoft = Color(0xFF191533);

  // Base clara
  static const Color paper = Color(0xFFF5F3FF);
  static const Color paperAlt = Color(0xFFEFF3FF);

  // Acentos neón
  static const Color neonCyan = Color(0xFF22D3EE);
  static const Color neonViolet = Color(0xFF8B5CF6);
  static const Color neonMagenta = Color(0xFFF0ABFC);
  static const Color neonAmber = Color(0xFFFBBF24);
  static const Color neonLime = Color(0xFFA3E635);

  // Contrapartes oscuras de los acentos. Los neones anteriores son ilegibles
  // sobre una superficie clara, asi que el tema claro usa estos.
  // Nota: `ColorScheme.primary`/`secondary` ya resuelven a estos valores, por
  // eso las pantallas deben leerlos del `ColorScheme` y no repetir el hex.
  static const Color violetDeep = Color(0xFF6D28D9);
  static const Color cyanDeep = Color(0xFF0891B2);
  static const Color amberDeep = Color(0xFFB45309);

  // Texto principal sobre superficie clara (`ColorScheme.onSurface`).
  static const Color inkText = Color(0xFF14112B);

  // Semánticos
  static const Color success = Color(0xFF34D399);
  static const Color danger = Color(0xFFF87171);
  static const Color warning = Color(0xFFFBBF24);
}

/// Par de acentos del tema activo, listo para degradados.
///
/// Cursa neón sobre fondo oscuro, cian/violeta profundos sobre fondo claro.
List<Color> accentGradient(ColorScheme scheme) =>
    [scheme.primary, scheme.secondary];

/// Radios, espaciados y duraciones. Centralizados para mantener coherencia.
class AppShape {
  const AppShape._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius fieldRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheetRadius =
      BorderRadius.vertical(top: Radius.circular(xl));
}

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppDuration {
  const AppDuration._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 620);
}

/// Fondo animado de aurora: manchas de color que se desplazan lentamente.
///
/// Se usa como fondo de todas las pantallas para dar profundidad sin apilar
/// capas opacas. Es barato: un solo `CustomPaint` con 3 gradientes radiales.
class AuroraBackground extends StatefulWidget {
  final Widget child;
  final bool dark;
  final double intensity;

  /// Cuando es `false` el fondo queda estatico. Util en listas largas, donde
  /// repintar la pantalla completa en cada frame compite con el scroll.
  final bool animate;

  const AuroraBackground({
    super.key,
    required this.child,
    required this.dark,
    this.intensity = 1,
    this.animate = true,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sincronizarAnimacion();
  }

  @override
  void didUpdateWidget(covariant AuroraBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _sincronizarAnimacion();
  }

  /// Respeta la preferencia del sistema de reducir animaciones.
  void _sincronizarAnimacion() {
    final reducir = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.animate && !reducir) {
      _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0.35;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base solida
        ColoredBox(
          color: widget.dark ? AppColors.inkDeep : AppColors.paper,
        ),
        // Manchas de aurora
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _AuroraPainter(
                t: _controller.value,
                dark: widget.dark,
                intensity: widget.intensity,
              ),
            ),
          ),
        ),
        // Contenido
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final bool dark;
  final double intensity;

  _AuroraPainter({
    required this.t,
    required this.dark,
    this.intensity = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide;

    // Tres manchas que orbitan con fases distintas
    final blobs = <({Color color, double phase, double scale, Offset anchor})>[
      (
        color: AppColors.neonViolet,
        phase: 0.0,
        scale: 0.95,
        anchor: const Offset(0.15, 0.05),
      ),
      (
        color: AppColors.neonCyan,
        phase: 0.33,
        scale: 0.8,
        anchor: const Offset(0.9, 0.35),
      ),
      (
        color: AppColors.neonMagenta,
        phase: 0.66,
        scale: 0.7,
        anchor: const Offset(0.35, 1.0),
      ),
    ];

    for (final blob in blobs) {
      final angle = (t + blob.phase) * 2 * 3.14159265;
      final drift = Offset(
        0.10 * _sin(angle),
        0.07 * _sin(angle * 1.7),
      );

      final center = Offset(
        size.width * (blob.anchor.dx + drift.dx),
        size.height * (blob.anchor.dy + drift.dy),
      );

      final r = radius * blob.scale * 0.9;
      final alpha = dark ? 0.30 : 0.22;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            blob.color.withValues(alpha: alpha * intensity),
            blob.color.withValues(alpha: 0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r));

      canvas.drawCircle(center, r, paint);
    }
  }

  double _sin(double x) {
    // Aproximacion de Taylor para evitar importar dart:math en el painter.
    var term = x;
    var sum = x;
    for (var k = 1; k < 5; k++) {
      term *= -x * x / ((2 * k) * (2 * k + 1));
      sum += term;
    }
    return sum;
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t != t || old.dark != dark || old.intensity != intensity;
}

/// Superficie de cristal: desenfoque de fondo + borde luminoso + sombra suave.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;
  final Color? tint;
  final bool glow;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  /// Aplica `BackdropFilter` para el efecto de cristal esmerilado.
  ///
  /// Ponlo en `false` dentro de listas largas: cada `BackdropFilter` es una
  /// capa de render propia y con scroll dozens son caros en gama media. Sin
  /// blur la superficie sigue viéndose translucida, solo pierde el difuminado
  /// del fondo.
  final bool blur;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius = AppShape.lg,
    this.opacity = 1,
    this.tint,
    this.glow = false,
    this.onTap,
    this.borderRadius,
    this.blur = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    final radiusValue = radius;
    final shape = BorderRadius.circular(radiusValue);

    final k = opacity.clamp(0.0, 1.0);
    final surfaceColor = tint ??
        (isDark
            ? const Color(0x14FFFFFF).withValues(alpha: 0.08 * k)
            : Colors.white.withValues(alpha: 0.74 * k));

    final borderColor =
        isDark ? const Color(0x24FFFFFF) : accent.withValues(alpha: 0.18);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: borderRadius ?? shape,
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : accent).withValues(
              alpha: isDark ? 0.42 : 0.12,
            ),
            blurRadius: isDark ? 26 : 22,
            offset: const Offset(0, 12),
          ),
          if (glow)
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.34 : 0.20),
              blurRadius: 30,
              spreadRadius: -6,
            ),
        ],
      ),
      child: child,
    );

    // Blur de fondo. Opcional porque en listas largas encarece el scroll.
    if (blur) {
      content = ClipRRect(
        borderRadius: borderRadius ?? shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: content,
        ),
      );
    } else {
      content = ClipRRect(
        borderRadius: borderRadius ?? shape,
        child: content,
      );
    }

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? shape,
          splashColor: accent.withValues(alpha: 0.12),
          highlightColor: accent.withValues(alpha: 0.06),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// Texto con degradado neón (para cifras destacadas y títulos de marca).
///
/// Si no se pasan `colors`, usa los acentos del tema activo, de modo que el
/// mismo widget sirve en claro y en oscuro sin condicionales en la pantalla.
class NeonText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final List<Color>? colors;

  const NeonText({
    super.key,
    required this.text,
    this.style,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final degradado = colors ?? accentGradient(Theme.of(context).colorScheme);

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: degradado,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Text(
        text,
        style: (style ?? Theme.of(context).textTheme.titleLarge)?.copyWith(
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Chip compacto con icono + etiqueta, para metadatos (marca, categoría, IVA).
class GlassChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;

  /// Convierte el chip en un boton.
  ///
  /// Antes de existir esto, un chip seleccionable se armaba con un `GlassChip`
  /// metido en un `GestureDetector`, y el ripple se comia el padding del chip.
  /// Aqui se resuelve con un `Material` transparente, que es lo que `InkWell`
  /// necesita para pintar.
  final VoidCallback? onTap;

  const GlassChip({
    super.key,
    this.icon,
    required this.label,
    this.color = AppColors.neonCyan,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final contenido = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(AppShape.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: isDark ? Colors.white.withValues(alpha: 0.9) : color,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return contenido;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppShape.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppShape.pill),
        child: contenido,
      ),
    );
  }
}

/// Botón principal con degradado neón y brillo.
class NeonButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;
  final bool compact;

  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expand = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final enabled = onPressed != null && !loading;
    final radius = BorderRadius.circular(AppShape.pill);

    final gradient = LinearGradient(
      colors: enabled
          ? [
              theme.colorScheme.primary,
              theme.colorScheme.secondary,
            ]
          : [
              theme.colorScheme.primary.withValues(alpha: 0.35),
              theme.colorScheme.secondary.withValues(alpha: 0.35),
            ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    final height = compact ? 44.0 : 56.0;

    Widget content = Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: radius,
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(
                    alpha: isDark ? 0.45 : 0.32,
                  ),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.24),
                  blurRadius: 34,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: compact ? 18 : 21, color: Colors.white),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    );

    if (expand) {
      content = SizedBox(width: double.infinity, child: content);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: content,
      ),
    );
  }
}

/// Botón secundario de cristal para acciones terciarias.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tint = color ?? theme.colorScheme.onSurface;

    final button = Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0x14FFFFFF) : const Color(0xA8FFFFFF),
        borderRadius: BorderRadius.circular(AppShape.md),
        border: Border.all(
          color: color?.withValues(alpha: 0.4) ??
              (isDark ? const Color(0x24FFFFFF) : const Color(0x1A000000)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.46, color: tint),
    );

    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child:
            tooltip == null ? button : Tooltip(message: tooltip, child: button),
      ),
    );
  }
}

/// Constructor de temas. Un solo lugar donde vive todo el sistema visual.
class AppTheme {
  const AppTheme._();

  static const Color _seed = AppColors.neonViolet;

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? AppColors.neonViolet : AppColors.violetDeep,
      secondary: isDark ? AppColors.neonCyan : AppColors.cyanDeep,
      tertiary: AppColors.neonMagenta,
      error: AppColors.danger,
      surface: isDark ? AppColors.inkMid : Colors.white,
      onSurface: isDark ? Colors.white : AppColors.inkText,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      splashFactory: InkSparkle.splashFactory,
    );

    final textColor = scheme.onSurface;
    final muted = textColor.withValues(alpha: isDark ? 0.62 : 0.58);

    final textTheme = base.textTheme
        .apply(
          bodyColor: textColor,
          displayColor: textColor,
        )
        .copyWith(
          displaySmall: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
            height: 1.1,
            color: textColor,
          ),
          headlineMedium: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: textColor,
          ),
          headlineSmall: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: textColor,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: textColor,
          ),
          titleMedium: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            color: textColor,
          ),
          bodyLarge: TextStyle(fontSize: 15.5, height: 1.4, color: textColor),
          bodyMedium: TextStyle(fontSize: 13.5, height: 1.4, color: muted),
          labelLarge: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: textColor,
          ),
          labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: muted,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: textColor,
        iconTheme: IconThemeData(color: textColor, size: 22),
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF15122A) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.lg),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        width: 312,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.horizontal(right: Radius.circular(AppShape.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? const Color(0xFF221C42) : const Color(0xFF1B1733),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.md),
        ),
        insetPadding: const EdgeInsets.all(AppSpacing.md),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0x0FFFFFFF) : const Color(0x8CFFFFFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 17,
        ),
        hintStyle: textTheme.bodyMedium,
        labelStyle: TextStyle(color: muted, fontWeight: FontWeight.w500),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: _fieldBorder(scheme.primary.withValues(alpha: 0.22)),
        enabledBorder: _fieldBorder(
          isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
        ),
        focusedBorder: _fieldBorder(scheme.primary, width: 1.6),
        errorBorder: _fieldBorder(AppColors.danger.withValues(alpha: 0.6)),
        focusedErrorBorder: _fieldBorder(AppColors.danger, width: 1.6),
        errorStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.danger,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0x1FFFFFFF) : const Color(0x12000000),
        thickness: 1,
        space: 1,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        thumbColor: scheme.primary,
        inactiveTrackColor: scheme.primary.withValues(alpha: 0.2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : (isDark ? const Color(0x1FFFFFFF) : const Color(0x14000000)),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2450) : const Color(0xFF241F45),
          borderRadius: BorderRadius.circular(AppShape.xs),
        ),
        textStyle: const TextStyle(fontSize: 12, color: Colors.white),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          // Transicion con desvanecido + deslizamiento suave, coherente con
          // el estilo "cristal" del resto de la app.
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppShape.fieldRadius,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
