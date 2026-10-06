import 'package:flutter/material.dart';

import '../screens/categorias_screen.dart';
import '../screens/historial_ventas_screen.dart';
import '../screens/marcas_screen.dart';
import '../screens/opciones_cobro_screen.dart';
import '../screens/reporte_ventas_screen.dart';
import '../services/cobro_controller.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../utils/precios.dart';

/// Menu lateral con navegacion principal y el interruptor de tema.
class Sidebar extends StatelessWidget {
  final VoidCallback? onVenta;
  final ThemeController themeController;

  const Sidebar({
    super.key,
    required this.themeController,
    this.onVenta,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: Colors.transparent,
      child: AuroraBackground(
        dark: isDark,
        intensity: 0.7,
        child: SafeArea(
          child: Column(
            children: [
              _Encabezado(isDark: isDark),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  children: [
                    _SeccionLabel('Operacion'),
                    _MenuItem(
                      icon: Icons.point_of_sale_rounded,
                      label: 'Nueva Venta',
                      gradient: const [
                        AppColors.neonCyan,
                        AppColors.neonViolet
                      ],
                      onTap: () {
                        Navigator.pop(context);
                        onVenta?.call();
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _MenuItem(
                      icon: Icons.receipt_long_rounded,
                      label: 'Historial de Ventas',
                      onTap: () => _ir(context, const HistorialVentasScreen()),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _MenuItem(
                      icon: Icons.insights_rounded,
                      label: 'Reporte de Ventas',
                      onTap: () => _ir(context, const ReporteVentasScreen()),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SeccionLabel('Catalogo'),
                    _MenuItem(
                      icon: Icons.category_rounded,
                      label: 'Categorias',
                      onTap: () => _ir(context, const CategoriasScreen()),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _MenuItem(
                      icon: Icons.label_rounded,
                      label: 'Marcas',
                      onTap: () => _ir(context, const MarcasScreen()),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SeccionLabel('Cobro'),
                    // `CobroScope` solo notifica cuando cambia el controller, no
                    // cuando el controller cambia de valor, asi que el texto del
                    // detalle necesita su propio `ListenableBuilder`.
                    ValueListenableBuilder<RedondeoCobro>(
                      valueListenable: CobroScope.of(context),
                      builder: (context, modo, _) => _MenuItem(
                        icon: Icons.tune_rounded,
                        label: 'Opciones de cobro',
                        detalle: modo.etiqueta,
                        onTap: () => _ir(context, const OpcionesCobroScreen()),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SeccionLabel('Apariencia'),
                    _ToggleTema(controller: themeController),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: GlassChip(
                        icon: Icons.code_rounded,
                        label: 'JACSOFT · v2.2.0',
                        color:
                            isDark ? AppColors.neonCyan : AppColors.neonViolet,
                      ),
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

  void _ir(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _Encabezado extends StatelessWidget {
  final bool isDark;

  const _Encabezado({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.neonCyan, AppColors.neonViolet],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppShape.md),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonViolet.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.qr_code_scanner_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan Products',
                  style: theme.textTheme.titleLarge?.copyWith(color: textColor),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Image.network(
                      'https://flagcdn.com/w80/co.png',
                      width: 18,
                      height: 12,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 6),
                    Text('Colombia · COP', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeccionLabel extends StatelessWidget {
  final String texto;

  const _SeccionLabel(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        texto.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final List<Color>? gradient;

  /// Texto pequeno bajo la etiqueta, para mostrar el valor vigente de un ajuste.
  ///
  /// Sin esto, "Opciones de cobro" no dice si el redondeo esta activo o no: el
  /// usuario tiene que entrar a verlo y acordarse de lo que vio.
  final String? detalle;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.gradient,
    this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = gradient?.first ?? theme.colorScheme.primary;

    return GlassSurface(
      onTap: onTap,
      radius: AppShape.md,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              gradient:
                  gradient == null ? null : LinearGradient(colors: gradient!),
              color: gradient == null
                  ? accent.withValues(alpha: isDark ? 0.16 : 0.12)
                  : null,
              borderRadius: BorderRadius.circular(AppShape.sm),
            ),
            child: Icon(
              icon,
              size: 19,
              color: gradient != null
                  ? Colors.white
                  : (isDark ? Colors.white : accent),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              // `min` para que la fila no estire cuando hay detalle y no lo hay
              // a la vez: el alto de la fila no puede depender de que dato se
              // muestre hoy.
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                if (detalle != null)
                  Text(
                    detalle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      fontSize: 11.5,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

class _ToggleTema extends StatelessWidget {
  final ThemeController controller;

  const _ToggleTema({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: controller,
      builder: (context, mode, _) {
        final dark = mode == ThemeMode.dark;
        return GlassSurface(
          radius: AppShape.md,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          onTap: controller.toggle,
          child: Row(
            children: [
              Icon(
                dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                size: 19,
                color: dark ? AppColors.neonViolet : AppColors.neonAmber,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dark ? 'Modo oscuro' : 'Modo claro',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      dark ? 'Toque para cambiar' : 'Toque para cambiar',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: dark,
                onChanged: (_) => controller.toggle(),
              ),
            ],
          ),
        );
      },
    );
  }
}
