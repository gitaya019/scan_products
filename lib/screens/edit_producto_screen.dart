import 'package:flutter/material.dart';

import '../models/marca.dart';
import '../models/producto_model.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/unidades.dart';
import '../widgets/categoria_selector.dart';
import '../widgets/marca_selector.dart';
import '../widgets/precio_panel.dart';
import '../widgets/presentacion_selector.dart';
import '../widgets/producto_text_field.dart';
import 'opciones_cobro_screen.dart';

/// Formulario de edicion de un producto existente, incluye eliminar.
class EditProductoScreen extends StatefulWidget {
  final Producto producto;

  const EditProductoScreen({super.key, required this.producto});

  @override
  State<EditProductoScreen> createState() => _EditProductoScreenState();
}

class _EditProductoScreenState extends State<EditProductoScreen> {
  static const List<String> _unidades = [
    'unidad', 'kg', 'g', 'lb', 'L', 'mL', 'paquete', 'caja', //
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _codigoController;
  late final TextEditingController _categoriaController;
  late final TextEditingController _marcaController;
  late final TextEditingController _medidaController;
  late final TextEditingController _stockController;

  late String _unidadMedida;
  late String _unidadVenta;
  late bool _ventaPorPeso;
  bool _guardando = false;

  /// Marcas ya registradas, para el autocompletado.
  List<Marca> _marcas = [];

  /// Categorias del catalogo propio (menu lateral).
  List<String> _categorias = [];

  // Costo, precio e IVA los administra `PrecioPanel`.
  double _costo = 0;
  double _precio = 0;
  double _iva = 0;

  /// Unidades que se venden por conteo, no por medida.
  static const Set<String> _unidadesDeConteo = {'unidad', 'paquete', 'caja'};

  @override
  void initState() {
    super.initState();
    final p = widget.producto;

    _nombreController = TextEditingController(text: p.nombre);
    _codigoController = TextEditingController(text: p.codigo ?? '');
    _categoriaController = TextEditingController(text: p.categoria);
    _marcaController = TextEditingController(text: p.marca ?? '');
    _medidaController = TextEditingController(
      text: formatCantidad(p.peso, porPeso: true),
    );
    _stockController = TextEditingController(
      text: formatCantidad(p.stock, porPeso: p.ventaPorPeso),
    );

    _costo = p.costo;
    _precio = p.precio;
    _iva = p.iva;

    _unidadMedida = p.unidadMedida ?? _unidades.first;
    // `Producto.unidad` ya resuelve el `null` heredado ("misma que el precio"),
    // asi que nunca devuelve nulo.
    _unidadVenta = p.unidad;
    _ventaPorPeso = p.ventaPorPeso;

    _cargarMarcas();
    _cargarCategorias();
  }

  /// Catalogo propio de categorias, para las sugerencias del selector.
  Future<void> _cargarCategorias() async {
    final nombres = await DatabaseHelper.instance.getCategorias();
    if (!mounted) return;
    setState(() => _categorias = nombres);
  }

  Future<void> _cargarMarcas() async {
    final db = DatabaseHelper.instance;
    await db.sincronizarMarcasDesdeProductos();
    final nombres = await db.getMarcas();
    if (!mounted) return;
    setState(() => _marcas = nombres.map((n) => Marca(nombre: n)).toList());
  }

  Future<void> _crearMarca(String nombre) async {
    if (nombre.trim().isEmpty) return;
    final guardada = await DatabaseHelper.instance.agregarMarca(nombre);
    if (!mounted) return;
    setState(() {
      _marcas = [..._marcas, Marca(nombre: guardada)]
        ..sort((a, b) => a.nombre.compareTo(b.nombre));
      _marcaController.text = guardada;
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _codigoController.dispose();
    _categoriaController.dispose();
    _marcaController.dispose();
    _medidaController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  /// Propone una unidad coherente al cambiar de modo de venta, para no dejar
  /// un queso medido en `paquete` o una bolsa pesada medida en `unidad`.
  void _alCambiarPresentacion(bool porPeso) {
    setState(() {
      _ventaPorPeso = porPeso;
      if (porPeso && _unidadesDeConteo.contains(_unidadMedida)) {
        _unidadMedida = 'kg';
      } else if (!porPeso &&
          !_unidadesDeConteo.contains(_unidadMedida) &&
          _unidadMedida != 'kg' &&
          _unidadMedida != 'lb') {
        _unidadMedida = 'unidad';
      }
      if (!_unidadDeVentaValida(_unidadVenta)) {
        _unidadVenta = _unidadMedida;
      }
    });
  }

  bool _unidadDeVentaValida(String unidad) =>
      _unidadDeVentaCandidatas.contains(unidad);

  /// Unidades en las que se puede pesar cuando el precio esta en [_unidadMedida].
  ///
  /// Solo las que tienen conversion real: si el precio esta en "unidad", no
  /// tiene sentido ofrecer gramos como unidad de pesaje.
  List<String> get _unidadDeVentaCandidatas => [
        _unidadMedida,
        for (final u in Unidades.todas)
          if (u != _unidadMedida &&
              Unidades.factor(origen: u, destino: _unidadMedida) != null)
            u,
      ];

  /// Muestra el selector de balanza cuando hay algo distinto a elegir.
  bool get _mostrarUnidadVenta =>
      _ventaPorPeso && _unidadDeVentaCandidatas.length > 1;

  bool get _porVolumen => _unidadMedida == 'L' || _unidadMedida == 'mL';

  IconData get _iconoMedida {
    if (_porVolumen) return Icons.water_drop_rounded;
    if (_ventaPorPeso) return Icons.scale_rounded;
    return Icons.inventory_2_rounded;
  }

  Future<void> _actualizar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    final producto = Producto(
      id: widget.producto.id,
      nombre: _nombreController.text.trim(),
      codigo: _codigoController.text.trim(),
      // Igual que al crear: el nombre canonico sale del catalogo propio si esta
      // ahi, y de las predeterminadas si no.
      categoria: await DatabaseHelper.instance
          .normalizarCategoria(_categoriaController.text),
      precio: _precio,
      costo: _costo,
      peso: double.tryParse(_medidaController.text) ?? 1.0,
      stock: double.tryParse(_stockController.text) ?? 0.0,
      marca: _marcaController.text.trim().isEmpty
          ? null
          : _marcaController.text.trim(),
      unidadMedida: _unidadMedida,
      unidadVenta: _unidadVenta == _unidadMedida ? null : _unidadVenta,
      iva: _iva,
      ventaPorPeso: _ventaPorPeso,
    );

    try {
      await DatabaseHelper.instance.updateProducto(producto.toMap());
      if (producto.marca != null) {
        await DatabaseHelper.instance.asegurarMarca(producto.marca!);
      }
      // Al editar tambien puede cambiar la categoria, asi que entra al
      // catalogo igual que al crear.
      if (producto.categoria.isNotEmpty) {
        await DatabaseHelper.instance.asegurarCategoria(producto.categoria);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No se pudo guardar. Revisa que el codigo no este repetido.'),
        ),
      );
    }
  }

  Future<void> _eliminar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          'Se eliminara "${widget.producto.nombre}" del inventario. Esta accion no se puede deshacer.',
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

    if (confirmado == true && widget.producto.id != null) {
      await DatabaseHelper.instance.deleteProducto(widget.producto.id!);
      if (!mounted) return;
      Navigator.pop(context);
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
        appBar: AppBar(title: const Text('Editar producto')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [
                _PanelInfo(producto: widget.producto),
                const SizedBox(height: AppSpacing.md),
                _Seccion(
                  icono: Icons.info_outline_rounded,
                  titulo: 'Identificacion',
                  color: AppColors.neonCyan,
                  child: Column(
                    children: [
                      ProductoTextField(
                        controller: _nombreController,
                        label: 'Nombre del producto',
                        icon: Icons.shopping_basket_outlined,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingresa un nombre'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ProductoTextField(
                        controller: _codigoController,
                        label: 'Codigo de barras',
                        icon: Icons.barcode_reader,
                        helperText: 'Opcional',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      CategoriaSelector(
                        controller: _categoriaController,
                        propias: _categorias,
                        validator: (v) =>
                            (v == null || v.isEmpty || v.trim().isEmpty)
                                ? 'Ingresa una categoria'
                                : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _Seccion(
                  icono: Icons.tune_rounded,
                  titulo: 'Presentacion',
                  color: AppColors.neonMagenta,
                  child: Column(
                    children: [
                      PresentacionSelector(
                        ventaPorPeso: _ventaPorPeso,
                        unidadMedida: _unidadMedida,
                        onChanged: _alCambiarPresentacion,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        initialValue: _unidadMedida,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(AppShape.md),
                        icon: const Icon(Icons.unfold_more_rounded, size: 20),
                        decoration: InputDecoration(
                          labelText: _ventaPorPeso
                              ? 'Unidad en que se cotiza el precio'
                              : 'Unidad',
                          prefixIcon:
                              const Icon(Icons.straighten_rounded, size: 20),
                        ),
                        style: theme.textTheme.titleMedium,
                        items: _unidades
                            .map((u) =>
                                DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _unidadMedida = v;
                            if (!_unidadDeVentaValida(_unidadVenta) ||
                                _unidadVenta == 'unidad') {
                              _unidadVenta = v;
                            }
                          });
                        },
                      ),
                      if (_mostrarUnidadVenta) ...[
                        const SizedBox(height: AppSpacing.md),
                        UnidadVentaSelector(
                          unidadPrecio: _unidadMedida,
                          unidadVenta: _unidadVenta,
                          candidatas: _unidadDeVentaCandidatas,
                          onChanged: (v) => setState(() => _unidadVenta = v),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      MarcaSelector(
                        controller: _marcaController,
                        marcas: _marcas,
                        onCrear: _crearMarca,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _Seccion(
                  icono: Icons.sell_outlined,
                  titulo: 'Precio y existencias',
                  color: AppColors.neonLime,
                  child: Column(
                    children: [
                      PrecioPanel(
                        costoInicial: _costo,
                        precioInicial: _precio,
                        ivaInicial: _iva,
                        onCambio: (v) {
                          _costo = v.costo;
                          _precio = v.precio;
                          _iva = v.iva;
                        },
                        onEditarCobro: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OpcionesCobroScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ProductoTextField(
                              controller: _medidaController,
                              label: labelCantidad(
                                porPeso: _ventaPorPeso,
                                unidadMedida: _unidadMedida,
                              ),
                              icon: _iconoMedida,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: ProductoTextField(
                              controller: _stockController,
                              label: labelStock(
                                porPeso: _ventaPorPeso,
                                unidadMedida: _ventaPorPeso
                                    ? _unidadVenta
                                    : _unidadMedida,
                              ),
                              icon: Icons.inventory_rounded,
                              keyboardType: _ventaPorPeso
                                  ? const TextInputType.numberWithOptions(
                                      decimal: true)
                                  : TextInputType.number,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Ingresa el stock'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                NeonButton(
                  label: 'Guardar cambios',
                  icon: Icons.check_rounded,
                  loading: _guardando,
                  onPressed: _guardando ? null : _actualizar,
                ),
                const SizedBox(height: AppSpacing.sm),
                _BotonEliminar(onTap: _eliminar),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelInfo extends StatelessWidget {
  final Producto producto;

  const _PanelInfo({required this.producto});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassSurface(
      blur: false,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vista rapida', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Valor en inventario ${formatCurrency(producto.precio * producto.stock)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              NeonText(
                text: formatCurrency(producto.precio),
                style: theme.textTheme.headlineSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final Color color;
  final Widget child;

  const _Seccion({
    required this.icono,
    required this.titulo,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              height: 22,
              width: 22,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppShape.xs),
              ),
              child: Icon(icono, size: 13, color: color),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              titulo.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        GlassSurface(blur: false, child: child),
      ],
    );
  }
}

class _BotonEliminar extends StatelessWidget {
  final VoidCallback onTap;

  const _BotonEliminar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Eliminar producto',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppShape.pill),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Eliminar producto',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
