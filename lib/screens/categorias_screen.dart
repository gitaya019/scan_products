import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data/categorias.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';

/// Administracion del catalogo de categorias.
///
/// Las categorias viven en la tabla `categorias` (ver `DatabaseHelper`) y los
/// productos las referencian por texto en `productos.categoria`. Renombrar
/// mueve los productos en cascada; borrar esta bloqueado mientras haya
/// productos usando la categoria, porque su texto quedaria sin ningun sitio
/// donde aparecer.
class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({super.key});

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  final TextEditingController _busquedaController = TextEditingController();

  List<String> _categorias = [];
  Map<String, int> _conteo = {};
  bool _cargando = true;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => _cargando = true);

    // Sincroniza antes de leer: asi una categoria creada desde el formulario
    // (sin pasar por esta pantalla) aparece igual en la lista.
    await DatabaseHelper.instance.sincronizarCategoriasDesdeProductos();

    // Nombre y conteo vienen juntos en una sola consulta.
    final catalogo = await DatabaseHelper.instance.getCategoriasConConteo();

    if (!mounted) return;
    setState(() {
      _categorias = catalogo.keys.toList();
      _conteo = catalogo;
      _cargando = false;
    });
  }

  List<String> get _visibles {
    final f = _filtro.trim().toLowerCase();
    if (f.isEmpty) return _categorias;
    return _categorias.where((c) => c.toLowerCase().contains(f)).toList();
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  /// Texto inicial del dialogo: al renombrar, el nombre actual.
  String _sugerencia(String actual) {
    final base = Categorias.buscar(_filtro, limite: 1);
    if (base.isNotEmpty && base.first != actual) return base.first;
    return actual;
  }

  Future<void> _agregar() async {
    final nombre = await _pedirNombre(
      titulo: 'Nueva categoria',
      confirmar: 'Agregar',
      inicial: _sugerencia(''),
    );
    if (nombre == null) return;

    final creada = await DatabaseHelper.instance.agregarCategoria(nombre);
    if (creada.isEmpty) {
      _avisar('Escribe el nombre de la categoria.');
      return;
    }
    await _cargar();
    _avisar('Categoria "$creada" agregada.');
  }

  Future<void> _renombrar(String categoria) async {
    final nombre = await _pedirNombre(
      titulo: 'Renombrar categoria',
      confirmar: 'Guardar',
      inicial: categoria,
    );
    if (nombre == null) return;

    try {
      final destino =
          await DatabaseHelper.instance.renombrarCategoria(categoria, nombre);
      if (destino == null) {
        _avisar('La categoria ya no existe.');
        return;
      }
      await _cargar();
      _avisar('Renombrada a "$destino".');
    } on EstadoCategoriaException catch (e) {
      _avisar(e.mensaje);
    }
  }

  Future<void> _eliminar(String categoria) async {
    final productos = _conteo[categoria] ?? 0;
    if (productos > 0) {
      // No se pregunta nada: la operacion no se puede hacer y el motivo es
      // concreto. Un "se seguro?" aqui solo generaria frustracion.
      _avisar(
        '"$categoria" la usan $productos '
        '${productos == 1 ? 'producto' : 'productos'}. Muevelos de categoria primero.',
      );
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoria'),
        content: Text(
          'Se quitara "$categoria" del catalogo. No hay productos que la '
          'usen, asi que nada mas se ve afectada.',
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
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    await DatabaseHelper.instance.eliminarCategoria(categoria);
    await _cargar();
    _avisar('Categoria eliminada.');
  }

  /// Dialogo de alta/edicion. Devuelve `null` si se cancela.
  ///
  /// Solo se pasa el texto inicial: el `TextEditingController` lo crea y
  /// destruye el propio dialogo. Crearlo aqui y liberarlo en la linea
  /// siguiente a `showDialog` es exactamente el bug que arrastra
  /// "_dependents.isEmpty" (ver el gotcha en AGENTS.md): `showDialog` devuelve
  /// en el `Navigator.pop`, pero la ruta sigue montada durante su transicion de
  /// salida y el `TextField` con autofocus se reconstruye al moverse el teclado.
  Future<String?> _pedirNombre({
    required String titulo,
    required String confirmar,
    required String inicial,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _DialogoNombre(
        titulo: titulo,
        confirmar: confirmar,
        inicial: inicial,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AuroraBackground(
      dark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Categorias')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _agregar,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: isDark ? AppColors.inkDeep : Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nueva'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: GlassSurface(
                  radius: AppShape.pill,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: TextField(
                    controller: _busquedaController,
                    onChanged: (texto) => setState(() => _filtro = texto),
                    decoration: InputDecoration(
                      hintText: 'Buscar categoria',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: InputBorder.none,
                      suffixIcon: _filtro.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _busquedaController.clear();
                                setState(() => _filtro = '');
                              },
                            ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : _visibles.isEmpty
                        ? _CategoriasVacias(filtro: _filtro)
                        : RefreshIndicator(
                            onRefresh: _cargar,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                AppSpacing.xs,
                                AppSpacing.md,
                                96,
                              ),
                              itemCount: _visibles.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.xs),
                              itemBuilder: (context, index) {
                                final categoria = _visibles[index];
                                return _TarjetaCategoria(
                                  nombre: categoria,
                                  productos: _conteo[categoria] ?? 0,
                                  onRenombrar: () => _renombrar(categoria),
                                  onEliminar: () => _eliminar(categoria),
                                )
                                    .animate()
                                    .fadeIn(
                                      duration: 240.ms,
                                      delay: Duration(
                                        milliseconds:
                                            (index * 35).clamp(0, 240),
                                      ),
                                    )
                                    .slideY(begin: 0.04, duration: 240.ms);
                              },
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

/// Fila del catalogo con conteo de productos y acciones.
class _TarjetaCategoria extends StatelessWidget {
  final String nombre;
  final int productos;
  final VoidCallback onRenombrar;
  final VoidCallback onEliminar;

  const _TarjetaCategoria({
    required this.nombre,
    required this.productos,
    required this.onRenombrar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    return GlassSurface(
      // Sin `blur`: esta tarjeta vive dentro de una lista desplazable y cada
      // `BackdropFilter` es una capa de render propia.
      blur: false,
      radius: AppShape.md,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
              borderRadius: BorderRadius.circular(AppShape.sm),
            ),
            child: Icon(Icons.category_rounded, size: 18, color: accent),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  productos == 0
                      ? 'Sin productos'
                      : '$productos '
                          '${productos == 1 ? 'producto' : 'productos'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          GlassIconButton(
            icon: Icons.edit_rounded,
            tooltip: 'Renombrar',
            onPressed: onRenombrar,
          ),
          const SizedBox(width: AppSpacing.xs),
          GlassIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Eliminar',
            color: AppColors.danger,
            onPressed: onEliminar,
          ),
        ],
      ),
    );
  }
}

/// Dialogo de una sola linea para el nombre de la categoria.
class _DialogoNombre extends StatefulWidget {
  final String titulo;
  final String confirmar;

  /// Texto inicial. Solo el texto: el controller es del dialogo.
  final String inicial;

  const _DialogoNombre({
    required this.titulo,
    required this.confirmar,
    required this.inicial,
  });

  @override
  State<_DialogoNombre> createState() => _DialogoNombreState();
}

class _DialogoNombreState extends State<_DialogoNombre> {
  String _error = '';

  /// Vive exactamente lo que vive el dialogo, como en
  /// `_DialogoCantidadVenta`. Liberarlo fuera del `State` deja al `TextField`
  /// leyendo un controller muerto durante la transicion de salida.
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.inicial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _aceptar() {
    final texto = _controller.text.trim();
    if (texto.isEmpty) {
      setState(() => _error = 'La categoria necesita un nombre.');
      return;
    }
    Navigator.pop(context, texto);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Con el teclado abierto el alto util se reduce mucho: sin `scrollable`
      // el contenido se sale del dialogo.
      scrollable: true,
      title: Text(widget.titulo),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _aceptar(),
        onChanged: (_) {
          if (_error.isNotEmpty) setState(() => _error = '');
        },
        decoration: InputDecoration(
          labelText: 'Nombre',
          hintText: 'Lacteos',
          errorText: _error.isEmpty ? null : _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        NeonButton(
          label: widget.confirmar,
          compact: true,
          expand: false,
          onPressed: _aceptar,
        ),
      ],
    );
  }
}

/// Estado vacio: distingue "todavia no hay nada" de "el filtro no coincide".
class _CategoriasVacias extends StatelessWidget {
  final String filtro;

  const _CategoriasVacias({required this.filtro});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Mismo patron que `_MensajeVacio` en venta_screen.dart: `Center` +
    // `Column` revienta con "A RenderFlex overflowed" en cuanto el alto
    // disponible baja (por ejemplo, con el teclado abierto y un filtro sin
    // resultados). `LayoutBuilder` + `ConstrainedBox` + `SingleChildScrollView`
    // lo mantiene centrado y, si no cabe, desplazable.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 46,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    filtro.trim().isEmpty
                        ? 'Sin categorias'
                        : 'Sin coincidencias',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    filtro.trim().isEmpty
                        ? 'Crea una con el boton "Nueva" o escribela al agregar un '
                            'producto: se agrega sola al catalogo.'
                        : 'Ninguna categoria contiene "${filtro.trim()}".',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
