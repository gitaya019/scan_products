import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/venta_detalle.dart';
import '../models/venta_model.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Historial de ventas con detalle y opcion de anular (repone el stock).
class HistorialVentasScreen extends StatefulWidget {
  const HistorialVentasScreen({super.key});

  @override
  State<HistorialVentasScreen> createState() => _HistorialVentasScreenState();
}

class _HistorialVentasScreenState extends State<HistorialVentasScreen> {
  List<Venta> _ventas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => _cargando = true);
    final ventas = await DatabaseHelper.instance.getVentas();
    if (!mounted) return;
    setState(() {
      _ventas = ventas;
      _cargando = false;
    });
  }

  Future<void> _verDetalle(Venta venta) async {
    final detalles = await DatabaseHelper.instance.getVentaDetalles(venta.id!);
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => _DialogoDetalle(venta: venta, detalles: detalles),
    );
  }

  Future<void> _anular(Venta venta) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular venta'),
        content: Text(
          'Se devolvera al inventario el stock de la venta del '
          '${formatFecha(venta.fecha)} y quedara marcada como anulada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Anular'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      await DatabaseHelper.instance.anularVenta(venta.id!);
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AuroraBackground(
      dark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Historial de ventas')),
        body: SafeArea(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _ventas.isEmpty
                  ? const _HistorialVacio()
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.sm,
                          AppSpacing.md,
                          AppSpacing.xl,
                        ),
                        itemCount: _ventas.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final venta = _ventas[index];
                          return _TarjetaVenta(
                            venta: venta,
                            onTap: () => _verDetalle(venta),
                            onAnular: venta.estado == 'anulada'
                                ? null
                                : () => _anular(venta),
                          )
                              .animate()
                              .fadeIn(
                                duration: 260.ms,
                                delay: Duration(
                                  milliseconds: (index * 45).clamp(0, 300),
                                ),
                              )
                              .slideY(begin: 0.05, curve: Curves.easeOutCubic);
                        },
                      ),
                    ),
        ),
      ),
    );
  }
}

class _TarjetaVenta extends StatelessWidget {
  final Venta venta;
  final VoidCallback onTap;
  final VoidCallback? onAnular;

  const _TarjetaVenta({
    required this.venta,
    required this.onTap,
    this.onAnular,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final anulada = venta.estado == 'anulada';

    return Opacity(
      opacity: anulada ? 0.55 : 1,
      child: GlassSurface(
        onTap: onTap,
        blur: false,
        radius: AppShape.md,
        padding: const EdgeInsets.all(AppSpacing.sm),
        tint: anulada ? Colors.black.withValues(alpha: 0.08) : null,
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: (anulada
                        ? Colors.grey
                        : (isDark ? AppColors.neonCyan : AppColors.neonViolet))
                    .withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppShape.md),
              ),
              child: Icon(
                anulada ? Icons.block_rounded : Icons.receipt_long_rounded,
                color: anulada
                    ? Colors.grey
                    : (isDark ? AppColors.neonCyan : AppColors.neonViolet),
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatFecha(venta.fecha),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      decoration: anulada ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      NeonText(
                        text: '${formatCurrency(venta.total)} COP',
                        style: theme.textTheme.titleMedium,
                        colors: anulada ? [Colors.grey, Colors.grey] : null,
                      ),
                      if (anulada) ...[
                        const SizedBox(width: AppSpacing.xs),
                        const GlassChip(
                          icon: Icons.block_rounded,
                          label: 'Anulada',
                          color: AppColors.danger,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (onAnular != null)
              GlassIconButton(
                icon: Icons.undo_rounded,
                tooltip: 'Anular venta',
                size: 38,
                color: AppColors.danger,
                onPressed: onAnular,
              ),
          ],
        ),
      ),
    );
  }
}

class _FilaDesglose extends StatelessWidget {
  final String etiqueta;
  final double valor;

  const _FilaDesglose({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(formatCurrency(valor), style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _DialogoDetalle extends StatelessWidget {
  final Venta venta;
  final List<VentaDetalle> detalles;

  const _DialogoDetalle({required this.venta, required this.detalles});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final anulada = venta.estado == 'anulada';

    final base = detalles.fold<double>(
      0,
      (suma, d) => suma + d.baseSinIVA,
    );
    final iva = detalles.fold<double>(
      0,
      (suma, d) => suma + d.ivaIncluido,
    );

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Detalle de venta', style: theme.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  formatFecha(venta.fecha),
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (anulada)
            const GlassChip(
              icon: Icons.block_rounded,
              label: 'Anulada',
              color: AppColors.danger,
            ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: detalles.length,
                separatorBuilder: (_, __) => const Divider(height: 18),
                itemBuilder: (context, index) {
                  final d = detalles[index];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(d.nombre, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              '${formatCantidad(d.cantidad, porPeso: d.ventaPorPeso)} x '
                              '${formatCurrency(d.precioUnitario)}'
                              // Se muestra la unidad en la que se capturo la
                              // cantidad (la de la balanza), que puede no ser la
                              // del precio: "0,26 lb x 5.000" frente a
                              // "120 g x 11".
                              '${d.ventaPorPeso && (d.unidadVenta ?? d.unidadMedida) != null ? ' ${d.unidadVenta ?? d.unidadMedida}' : ''}',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        formatCurrency(d.subtotal),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 26),
            // El IVA de cada linea se guarda con la venta, asi que este desglose
            // es historico y no depende de como este el producto hoy. El precio
            // ya lo incluia, por eso el total no cambia.
            if (iva > 0) ...[
              _FilaDesglose(etiqueta: 'Base gravable', valor: base),
              _FilaDesglose(etiqueta: 'IVA incluido', valor: iva),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Total', style: theme.textTheme.titleMedium),
                const SizedBox(width: AppSpacing.sm),
                // `Flexible` + `FittedBox`: un total largo con `headlineSmall`
                // desborda la fila en un dialogo angosto.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: NeonText(
                      text: formatCurrency(venta.total),
                      style: theme.textTheme.headlineSmall,
                      colors: anulada
                          ? [Colors.grey, Colors.grey]
                          : accentGradient(theme.colorScheme),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'COP',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      actions: [
        NeonButton(
          label: 'Cerrar',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class _HistorialVacio extends StatelessWidget {
  const _HistorialVacio();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 92,
              width: 92,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.neonViolet
                        .withValues(alpha: isDark ? 0.26 : 0.15),
                    AppColors.neonCyan.withValues(alpha: isDark ? 0.18 : 0.11),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppShape.xl),
              ),
              child: Icon(Icons.receipt_long_outlined,
                  size: 42, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Sin ventas todavía', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Cuando cobres tu primera venta aparecera aqui con todo su detalle.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
