import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Reporte con agregados de ventas del dia, semana y mes, mas el producto
/// mas vendido.
class ReporteVentasScreen extends StatefulWidget {
  const ReporteVentasScreen({super.key});

  @override
  State<ReporteVentasScreen> createState() => _ReporteVentasScreenState();
}

class _ReporteVentasScreenState extends State<ReporteVentasScreen> {
  Map<String, dynamic>? _resumen;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => _cargando = true);
    final resumen = await DatabaseHelper.instance.getResumenVentas();
    if (!mounted) return;
    setState(() {
      _resumen = resumen;
      _cargando = false;
    });
  }

  double _doble(String clave) => (_resumen?[clave] ?? 0).toDouble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AuroraBackground(
      dark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Reporte de ventas')),
        body: SafeArea(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
                    children: [
                      _TarjetaHero(
                        totalMes: _doble('total_mes'),
                        cantidadMes: _doble('cantidad_mes'),
                        ivaMes: _doble('iva_mes'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _Rotulo('Periodos'),
                      const SizedBox(height: AppSpacing.xs),
                      _FilaMetrica(
                        icono: Icons.today_rounded,
                        titulo: 'Hoy',
                        total: _doble('total_hoy'),
                        cantidad: _doble('cantidad_hoy'),
                        iva: _doble('iva_hoy'),
                        ivaIncluido: true,
                        color: AppColors.neonCyan,
                        indice: 0,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _FilaMetrica(
                        icono: Icons.date_range_rounded,
                        titulo: 'Esta semana',
                        total: _doble('total_semana'),
                        cantidad: _doble('cantidad_semana'),
                        iva: _doble('iva_semana'),
                        ivaIncluido: true,
                        color: AppColors.neonLime,
                        indice: 1,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _FilaMetrica(
                        icono: Icons.calendar_month_rounded,
                        titulo: 'Este mes',
                        total: _doble('total_mes'),
                        cantidad: _doble('cantidad_mes'),
                        iva: _doble('iva_mes'),
                        ivaIncluido: true,
                        color: AppColors.neonViolet,
                        indice: 2,
                      ),
                      if (_resumen?['producto_top'] != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _Rotulo('Destacado'),
                        const SizedBox(height: AppSpacing.xs),
                        _TarjetaTop(
                          nombre: '${_resumen!['producto_top']}',
                          cantidad: _doble('producto_top_cantidad'),
                        ),
                      ],
                    ],
                  )
                      .animate()
                      .fadeIn(duration: AppDuration.medium),
                ),
        ),
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  final String texto;

  const _Rotulo(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xxs),
      child: Text(texto.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _TarjetaHero extends StatelessWidget {
  final double totalMes;
  final double cantidadMes;
  final double ivaMes;

  const _TarjetaHero({
    required this.totalMes,
    required this.cantidadMes,
    required this.ivaMes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassSurface(
      glow: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('INGRESOS DEL MES',
                  style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          NeonText(
            text: '${formatCurrency(totalMes)} COP',
            style: theme.textTheme.displaySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              GlassChip(
                icon: Icons.shopping_bag_rounded,
                label: '${cantidadMes.toInt()} producto(s) vendidos',
                color: AppColors.neonCyan,
              ),
              // El total ya viene con el IVA dentro, asi que esto es solo el
              // dato de cuanto de ese dinero fue a impuestos. Se oculta cuando
              // todo el mes estuvo exento: una pastilla de cero no informa nada.
              if (ivaMes > 0)
                GlassChip(
                  icon: Icons.receipt_long_rounded,
                  label: 'IVA ${formatCurrency(ivaMes)} incluido',
                  color: AppColors.neonAmber,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilaMetrica extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final double total;
  final double cantidad;
  final double iva;

  /// Si el IVA ya venia incluido en el total, que es el caso de siempre.
  final bool ivaIncluido;
  final Color color;
  final int indice;

  const _FilaMetrica({
    required this.icono,
    required this.titulo,
    required this.total,
    required this.cantidad,
    required this.iva,
    required this.ivaIncluido,
    required this.color,
    required this.indice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = total - iva;

    return GlassSurface(
      blur: false,
      radius: AppShape.md,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(AppShape.md),
            ),
            child: Icon(icono, color: color, size: 21),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(titulo, style: theme.textTheme.titleMedium),
                Text(
                  '${cantidad.toInt()} producto(s)',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                ),
                // El desglose solo aparece cuando hay algo que desglosar: con
                // todos los productos exentos (tasa 0) seria una fila de ceros.
                if (iva > 0) ...[
                  Text(
                    'Base ${formatCurrency(base)} + IVA ${formatCurrency(iva)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: AppColors.neonAmber,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              NeonText(
                text: formatCurrency(total),
                style: theme.textTheme.titleLarge,
              ),
              Text(
                ivaIncluido ? 'COP c/IVA' : 'COP',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10.5),
              ),
            ],
          ),
        ],
      ),
    )
        .animate(delay: (indice * 80).ms)
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.05, curve: Curves.easeOutCubic);
  }
}

class _TarjetaTop extends StatelessWidget {
  final String nombre;
  final double cantidad;

  const _TarjetaTop({required this.nombre, required this.cantidad});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.neonAmber;

    return GlassSurface(
      blur: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0.12)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppShape.md),
            ),
            child: Icon(Icons.emoji_events_rounded, color: color, size: 24),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Producto mas vendido', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
          ),
          GlassChip(
            icon: Icons.trending_up_rounded,
            label: '${cantidad.toInt()} vendidos',
            color: color,
          ),
        ],
      ),
    );
  }
}
