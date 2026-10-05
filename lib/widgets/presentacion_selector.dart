import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/unidades.dart';

/// Selector de como se vende un producto.
///
/// Reemplaza al `Switch` que usaba antes porque un interruptor obliga a
/// interpretar el estado actual: solo dice "Venta por peso" o "Venta por
/// unidades" segun este o no marcado, sin decir cual es la otra opcion. Aqui
/// las dos opciones estan siempre escritas una al lado de la otra, con su
/// consecuencia visible (entero vs decimal) y una marca de seleccion, asi que
/// no hay nada que adivinar.
class PresentacionSelector extends StatelessWidget {
  final bool ventaPorPeso;
  final String unidadMedida;
  final ValueChanged<bool> onChanged;

  const PresentacionSelector({
    super.key,
    required this.ventaPorPeso,
    required this.unidadMedida,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final acento = theme.colorScheme.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Como se vende',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Apiladas y no en fila: en un movil angosto dos tarjetas lado a lado
        // obligan a partir los titulos en dos lineas, y ademas un `Row` con
        // `CrossAxisAlignment.stretch` dentro de un `ListView` (altura no
        // acotada) dispara "BoxConstraints forces an infinite height".
        _Opcion(
          seleccionada: !ventaPorPeso,
          icono: Icons.inventory_2_rounded,
          titulo: 'Por unidades',
          detalle:
              'Se cuenta una pieza por cada venta: 3 unidades, 2 paquetes.',
          color: acento,
          onTap: () => onChanged(false),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Opcion(
          seleccionada: ventaPorPeso,
          icono: Icons.scale_rounded,
          titulo: 'Por peso o volumen',
          detalle:
              'Se admite decimal para pesar o medir: 1,5 $unidadMedida, 0,250 $unidadMedida.',
          color: acento,
          onTap: () => onChanged(true),
        ),
      ],
    );
  }
}

/// Selector de la unidad en la que se pesa, cuando no es la del precio.
///
/// Aparece solo cuando el producto se vende por peso **y** hay una conversion
/// real disponible. Sin esto, un producto "5.000 la libra, se pesa en gramos"
/// no tendria donde elegir el gramo.
class UnidadVentaSelector extends StatelessWidget {
  final String unidadPrecio;
  final String unidadVenta;
  final List<String> candidatas;
  final ValueChanged<String> onChanged;

  const UnidadVentaSelector({
    super.key,
    required this.unidadPrecio,
    required this.unidadVenta,
    required this.candidatas,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final equivalencia = Unidades.equivalencia(
      unidadVenta: unidadVenta,
      unidadPrecio: unidadPrecio,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'En que se pesa en la balanza',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Puede ser distinta de la del precio. Por ejemplo: 5.000 la libra pero '
          'el local pesa en gramos.',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11.5,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final unidad in candidatas)
              _Chip(
                texto: unidad,
                seleccionada: unidad == unidadVenta,
                onTap: () => onChanged(unidad),
              ),
          ],
        ),
        if (equivalencia != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  '$equivalencia — el total se calcula con esta equivalencia.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Pastilla de seleccion, para marcar la unidad de la balanza.
class _Chip extends StatelessWidget {
  final String texto;
  final bool seleccionada;
  final VoidCallback onTap;

  const _Chip({
    required this.texto,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondary;

    return Semantics(
      button: true,
      selected: seleccionada,
      label: texto,
      child: Material(
        color: seleccionada
            ? color.withValues(alpha: 0.18)
            : theme.colorScheme.onSurface.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.pill),
          side: BorderSide(
            color: seleccionada
                ? color.withValues(alpha: 0.8)
                : theme.colorScheme.onSurface.withValues(alpha: 0.14),
            width: seleccionada ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              texto,
              style: theme.textTheme.labelLarge?.copyWith(
                color: seleccionada
                    ? color
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  final bool seleccionada;
  final IconData icono;
  final String titulo;
  final String detalle;
  final Color color;
  final VoidCallback onTap;

  const _Opcion({
    required this.seleccionada,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final texto = theme.colorScheme.onSurface;

    // `Material` y no un `Container` con `decoration`: las salpicaduras de
    // tinta se pintan sobre el `Material` mas cercano, asi que cualquier
    // `DecoratedBox` intermedio las tapa.
    return Semantics(
      button: true,
      selected: seleccionada,
      label: titulo,
      child: Material(
        color: seleccionada
            ? color.withValues(alpha: 0.16)
            : theme.colorScheme.onSurface.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShape.md),
          side: BorderSide(
            color: seleccionada
                ? color.withValues(alpha: 0.75)
                : theme.colorScheme.onSurface.withValues(alpha: 0.12),
            width: seleccionada ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    icono,
                    size: 20,
                    color: seleccionada ? color : texto.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        titulo,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: seleccionada ? color : texto,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detalle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: texto.withValues(alpha: 0.62),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                // La marca de seleccion solo ocupa espacio cuando aplica; asi
                // el titulo de las dos opciones arranca en el mismo punto.
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: seleccionada
                      ? Icon(Icons.check_circle_rounded, size: 18, color: color)
                      : Icon(
                          Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: texto.withValues(alpha: 0.25),
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
