import 'package:flutter/material.dart';

import '../models/carrito_item.dart';
import '../models/producto_model.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Muestra cuanto se va a cobrar por la cantidad que el usuario esta
/// escribiendo, sin esperar a confirmar.
///
/// Es la pieza que evita el error caro: con la libra a 5.000, escribir 120 en
/// una balanza que lee gramos son 1.323, no 600.000. La conversion se muestra
/// abierta ("120 g = 0,2646 lb") en vez de oculta, para que el cajero vea de
/// donde sale el numero.
class VistaPreviaCobro extends StatelessWidget {
  final Producto producto;
  final TextEditingController controller;

  const VistaPreviaCobro({
    super.key,
    required this.producto,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cantidad = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;

    // Se reutiliza CarritoItem para no duplicar la regla de conversion: si
    // mañana cambia el factor, el total y la vista previa cambian juntos.
    final item = CarritoItem(producto: producto, cantidad: cantidad);
    final total = item.subtotal;
    final hayCantidad = cantidad > 0;

    return GlassSurface(
      blur: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      radius: AppShape.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.calculate_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  hayCantidad
                      ? 'Se cobra ${formatCurrency(total)}'
                      : 'Escribe la cantidad para ver el total',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: hayCantidad
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (hayCantidad && producto.necesitaConversion) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${CarritoItem.formatear(cantidad)} ${producto.unidad} × '
              '${formatCurrency(item.precioUnitarioVenta)} el ${producto.unidad}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              'equivale a '
              '${CarritoItem.formatear(item.cantidadEnUnidadPrecio)} '
              '${producto.unidadPrecio} a ${formatCurrency(producto.precio)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}