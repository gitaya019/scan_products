import 'package:flutter/material.dart';

import '../models/marca.dart';
import '../theme/app_theme.dart';

/// Campo de marca con autocompletado y creacion en linea.
///
/// El objetivo es que "Alfa" se escriba una sola vez en toda la tienda. El
/// usuario escribe, ve las marcas que ya existen, y si la que quiere no esta
/// la crea con el mismo gesto sin salir del formulario.
///
/// No usa `Autocomplete` porque aqui el valor final es texto libre (una marca
/// nueva vale igual que una vieja), no un item de una lista cerrada.
class MarcaSelector extends StatelessWidget {
  final TextEditingController controller;
  final List<Marca> marcas;

  /// Registra [nombre] como marca nueva.
  ///
  /// Es lo unico que hay que avisar: el filtrado de sugerencias lo hace el
  /// propio widget escuchando el controller, asi que teclear no obliga a la
  /// pantalla a hacer `setState`.
  final ValueChanged<String> onCrear;
  final String? helperText;

  const MarcaSelector({
    super.key,
    required this.controller,
    required this.marcas,
    required this.onCrear,
    this.helperText,
  });

  /// Marcas que contienen lo escrito, mejor coincidencia primero.
  ///
  /// Busca en mayusculas y sin tildes para que "cafe" encuentre "Café" y
  /// "REY" encuentre "Rey".
  static List<Marca> _coincidencias(List<Marca> marcas, String texto) {
    final t = texto.trim().toLowerCase();
    if (t.isEmpty) return marcas.take(8).toList();

    final conTilde = _sinTildes(t);
    final lista = marcas
        .where((m) => _sinTildes(m.nombre.toLowerCase()).contains(conTilde))
        .toList();

    // Las que empiezan por lo escrito van primero: "al" ofrece "Alfa" antes que
    // "Sal y Pepper Alfredo".
    lista.sort((a, b) {
      final af = _sinTildes(a.nombre.toLowerCase()).startsWith(conTilde);
      final bf = _sinTildes(b.nombre.toLowerCase()).startsWith(conTilde);
      if (af != bf) return af ? -1 : 1;
      return a.nombre.compareTo(b.nombre);
    });
    return lista.take(8).toList();
  }

  /// Quita tildes y la letra ñ, para comparar sin depender de como se escribio.
  static String _sinTildes(String texto) {
    const mapa = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    var salida = texto;
    mapa.forEach((con, sin) => salida = salida.replaceAll(con, sin));
    return salida;
  }

  @override
  Widget build(BuildContext context) {
    // Se escucha el controller para que el filtro reaccione a cada tecla sin
    // que la pantalla tenga que acordarse de repintar.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _contenido(context),
    );
  }

  Widget _contenido(BuildContext context) {
    final theme = Theme.of(context);
    final textoActual = controller.text;
    final yaExiste = marcas.any(
      (m) =>
          _sinTildes(m.nombre.toLowerCase()) ==
          _sinTildes(textoActual.trim().toLowerCase()),
    );
    final sugerencias = _coincidencias(marcas, textoActual);
    final puedeCrear =
        textoActual.trim().isNotEmpty && !yaExiste && sugerencias.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            labelText: 'Marca',
            helperText: helperText ?? 'Escribe para buscar entre tus marcas.',
            helperMaxLines: 2,
            prefixIcon: const Icon(Icons.branding_watermark_rounded, size: 20),
          ),
        ),
        if (sugerencias.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final marca in sugerencias)
                _Pastilla(
                  texto: marca.nombre,
                  onTap: () {
                    controller.value = TextEditingValue(
                      text: marca.nombre,
                      selection:
                          TextSelection.collapsed(offset: marca.nombre.length),
                    );
                  },
                ),
            ],
          ),
        ],
        if (puedeCrear) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                size: 15,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  'Crear la marca "${textoActual.trim()}"',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontSize: 11.5,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => onCrear(textoActual.trim()),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
                child: const Text('Crear'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Pastilla extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;

  const _Pastilla({required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondary;

    return Material(
      color: color.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShape.pill),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 6,
          ),
          child: Text(
            texto,
            style: theme.textTheme.labelMedium?.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}
