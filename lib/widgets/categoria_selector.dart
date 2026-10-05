import 'package:flutter/material.dart';

import '../data/categorias.dart';
import '../theme/app_theme.dart';

/// Campo de categoria con atajos y texto libre.
///
/// Se eligio texto libre con sugerencias en vez de un `DropdownButton` cerrado
/// porque ninguna lista de categorias sirve para todas las tiendas: "Rancho" y
/// "Extras" existen y nadie los tiene en un catalogo. Las predeterminadas
/// aceleran el caso comun y el campo acepta cualquier otra cosa.
///
/// Las secciones van plegadas: mostrar 80 categorias de una vez empuja el
/// resto del formulario fuera de la pantalla.
class CategoriaSelector extends StatelessWidget {
  final TextEditingController controller;

  /// Validador del formulario. Se declara como [FormFieldValidator] para que el
  /// tipo del valor sea `String?` y no `dynamic`.
  final FormFieldValidator<String>? validator;
  final String? helperText;

  /// Categorias del catalogo propio (menu lateral), que se ofrecen ademas de las
  /// predeterminadas. Vienen de la base de datos porque dependen de lo que el
  /// usuario haya creado; sin ellas el selector solo conoceria la lista fija y
  /// una categoria nueva seria invisible salvo escribiendola a mano.
  final List<String> propias;

  const CategoriaSelector({
    super.key,
    required this.controller,
    this.validator,
    this.helperText,
    this.propias = const [],
  });

  @override
  Widget build(BuildContext context) {
    // Se escucha el controller en vez de recibir un `onChanged` que obligue al
    // padre a hacer `setState`: el filtro depende del texto y asi se actualiza
    // solo, sin que cada pantalla recuerde repintar.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _contenido(context),
    );
  }

  Widget _contenido(BuildContext context) {
    final theme = Theme.of(context);
    final textoActual = controller.text.trim();

    // Las propias van primero en las sugerencias: son las que el usuario creo
    // y las que quiere usar, mientras las predeterminadas son el catálogo fijo
    // de referencia. Se deduplican sin distinguir mayusculas para que "quesos"
    // no aparezca dos veces si ya esta en el catalogo.
    final sugeridas = <String>[];
    for (final c in [
      ...propias,
      ...Categorias.buscar(textoActual, limite: 10)
    ]) {
      final coincide = sugeridas.any(
        (s) => s.toLowerCase() == c.toLowerCase(),
      );
      if (!coincide) sugeridas.add(c);
    }
    final sugerencias = sugeridas.take(10).toList();

    final esConocida = [...Categorias.todas, ...propias]
        .any((c) => c.toLowerCase() == textoActual.toLowerCase());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // `TextFormField` y no `TextField` para que el validador del formulario
        // lo vea: este widget reemplaza al campo suelto, no lo complementa.
        TextFormField(
          controller: controller,
          validator: validator,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            labelText: 'Categoria',
            helperText: helperText ??
                (textoActual.isEmpty
                    ? 'Escribe o elige una de las predeterminadas.'
                    : esConocida
                        ? textoActual
                        : 'Se guardara como "${Categorias.normalizar(textoActual)}".'),
            helperMaxLines: 2,
            prefixIcon: const Icon(Icons.category_outlined, size: 20),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Secciones(controller: controller, propias: propias),
        // Las sugerencias solo aparecen con texto escrito: con el campo vacio
        // no hay nada que filtrar y mostrar 10 categorias de arranque solo
        // empuja el resto del formulario hacia abajo.
        if (textoActual.isNotEmpty && sugerencias.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final categoria in sugerencias)
                _Pastilla(
                  texto: categoria,
                  seleccionada:
                      categoria.toLowerCase() == textoActual.toLowerCase(),
                  onTap: () => controller.text = categoria,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Secciones plegables con las categorias de cada una.
class _Secciones extends StatelessWidget {
  final TextEditingController controller;
  final List<String> propias;

  const _Secciones({required this.controller, required this.propias});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Las propias se filtran contra las predeterminadas: repetir "Lacteos" en
    // las dos listas solo haria ruido.
    final predictas = Categorias.todas.map((c) => c.toLowerCase()).toSet();
    final exclusivas =
        propias.where((c) => !predictas.contains(c.toLowerCase())).toList();

    final secciones = [
      if (exclusivas.isNotEmpty)
        (seccion: 'Mis categorias', categorias: exclusivas),
      ...Categorias.porSeccion,
    ];

    // `ExpansionTile` es un `ListTile`, y un `ListTile` pinta su fondo y sus
    // salpicaduras sobre el `Material` mas cercano. Como el formulario lo mete
    // dentro de un `GlassSurface` (un `DecoratedBox` con color), sin este
    // `Material` intermedio Flutter tira la asercion "ListTile background color
    // or ink splashes may be invisible". Transparente para no cambiar el color.
    return Material(
      type: MaterialType.transparency,
      child: ExpansionTile(
        // `dense` y `tilePadding` en cero para que se aligne con el resto del
        // formulario en vez de quedar metido en una tarjeta mas.
        dense: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
        title: Row(
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Ver ${secciones.length} secciones',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        children: [
          for (final grupo in secciones)
            _Grupo(
              controller: controller,
              titulo: grupo.seccion,
              categorias: grupo.categorias,
            ),
        ],
      ),
    );
  }
}

class _Grupo extends StatelessWidget {
  final TextEditingController controller;
  final String titulo;
  final List<String> categorias;

  const _Grupo({
    required this.controller,
    required this.titulo,
    required this.categorias,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: AppSpacing.xxs),
            child: Text(
              titulo,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.secondary,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: 6,
            children: [
              for (final categoria in categorias)
                _Pastilla(
                  texto: categoria,
                  seleccionada: false,
                  onTap: () {
                    // Escribir en el controller dispara el
                    // `ListenableBuilder` de `CategoriaSelector`, asi que el
                    // filtro y el texto del campo se actualizan solos.
                    controller.value = TextEditingValue(
                      text: categoria,
                      selection: TextSelection.collapsed(
                        offset: categoria.length,
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pastilla extends StatelessWidget {
  final String texto;
  final bool seleccionada;
  final VoidCallback onTap;

  const _Pastilla({
    required this.texto,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondary;

    return Material(
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
            horizontal: AppSpacing.sm,
            vertical: 6,
          ),
          child: Text(
            texto,
            style: theme.textTheme.labelMedium?.copyWith(
              color: seleccionada
                  ? color
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
