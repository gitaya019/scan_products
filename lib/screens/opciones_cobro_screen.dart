import 'package:flutter/material.dart';

import '../services/cobro_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/precios.dart';

/// Opciones de como se redondea lo que se cobra.
///
/// Es una pantalla y no un dialogo porque el ajuste se cambia de tarde en tarde
/// y se necesita leer mientras se decide; un dialogo encima del menu lateral
/// obliga a cerrar el menu, elegir y volver a abrir.
///
/// ## Donde se aplica el redondeo
///
/// Al **cobrar**: cada linea del carrito se redondea con el modo elegido y el
/// total es la suma de esas lineas. Se redondea linea por linea y no solo el
/// total a proposito: si solo se redondeara el total, la suma de las lineas del
/// ticket no daria lo que se cobro, y eso es un reclamo del cliente con razon.
///
/// **No** se redondea el precio del catalogo al guardar el producto. Alli el
/// precio esta atado al margen de ganancia del panel de precios, y subirlo a la
/// centena dejaria un producto guardado con 33% cuando el usuario escribio 30%.
class OpcionesCobroScreen extends StatelessWidget {
  const OpcionesCobroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = CobroScope.of(context);

    return AuroraBackground(
      dark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Opciones de cobro')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              Text('REDONDEO DEL COBRO', style: theme.textTheme.labelSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Ajusta las cifras de cada linea antes de sumar el total. '
                'El cliente paga lo que dice el ticket.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ValueListenableBuilder<RedondeoCobro>(
                valueListenable: controller,
                builder: (context, modo, _) => Column(
                  children: [
                    for (final opcion in RedondeoCobro.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _TarjetaOpcion(
                          modo: opcion,
                          seleccionado: opcion == modo,
                          onTap: () => controller.cambiar(opcion),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Ejemplos(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

/// Una opcion de redondeo, con su ejemplo a la derecha.
class _TarjetaOpcion extends StatelessWidget {
  final RedondeoCobro modo;
  final bool seleccionado;
  final VoidCallback onTap;

  const _TarjetaOpcion({
    required this.modo,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    return GlassSurface(
      onTap: onTap,
      radius: AppShape.md,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      // `glow` es el acento que el sistema de diseño ya usa para "esto está
      // elegido": no hay que inventar un `borderColor` solo para una fila.
      glow: seleccionado,
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
              borderRadius: BorderRadius.circular(AppShape.sm),
            ),
            child: Icon(
              seleccionado
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 19,
              color: accent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(modo.etiqueta, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  modo.ejemplo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Como queda cada importe con el modo activo.
///
/// Sin esto el tendero tiene que hacer la cuenta de cabeza para decidir, y
/// "multiplo de 50" suena igual de claro a 300 que a 300.000.
class _Ejemplos extends StatelessWidget {
  final CobroController controller;

  const _Ejemplos({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<RedondeoCobro>(
      valueListenable: controller,
      builder: (context, modo, _) {
        if (!controller.redondea) {
          return Text(
            'Ahora mismo no se redondea nada: cada linea se cobra en pesos '
            'enteros tal como sale.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          );
        }

        return GlassSurface(
          blur: false,
          radius: AppShape.md,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calculate_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'COMO SE VENDE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final importe in const <double>[
                924,
                980,
                9823,
                25000,
                10737,
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatCurrency(importe),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        formatCurrency(controller.aplicar(importe)),
                        style: theme.textTheme.titleMedium,
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
