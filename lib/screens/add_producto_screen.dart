import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../data/categorias.dart';
import '../models/marca.dart';
import '../models/producto_model.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/precios.dart';
import '../utils/unidades.dart';
import '../widgets/categoria_selector.dart';
import '../widgets/marca_selector.dart';
import '../widgets/precio_panel.dart';
import '../widgets/presentacion_selector.dart';
import '../widgets/producto_text_field.dart';

/// Formulario para registrar un producto nuevo.
///
/// Si el codigo de barras ya existe, en lugar de crear un duplicado se ofrece
/// sumar stock al producto existente.
class AddProductoScreen extends StatefulWidget {
  const AddProductoScreen({super.key});

  @override
  State<AddProductoScreen> createState() => _AddProductoScreenState();
}

class _AddProductoScreenState extends State<AddProductoScreen> {
  static const List<String> _unidades = [
    'unidad', 'kg', 'g', 'lb', 'L', 'mL', 'paquete', 'caja', //
  ];

  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _codigoController = TextEditingController();
  final _categoriaController = TextEditingController();
  final _marcaController = TextEditingController();
  final _medidaController = TextEditingController();
  final _stockController = TextEditingController();

  String _unidadMedida = 'unidad';
  String _unidadVenta = 'unidad';
  bool _ventaPorPeso = false;
  bool _guardando = false;

  /// Marcas ya registradas, para el autocompletado.
  List<Marca> _marcas = [];

  // Costo, precio e IVA los administra `PrecioPanel`, que los mantiene
  // sincronizados entre si y los reporta por aqui para armar el `Producto`.
  double _costo = 0;
  double _precio = 0;
  double _iva = 0;

  @override
  void initState() {
    super.initState();
    _medidaController.text = '1';
    _cargarMarcas();
  }

  /// Trae las marcas existentes y, de paso, registra las que ya estaban en los
  /// productos de una base creada antes de que existiera la tabla.
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

  /// Unidades que se venden por conteo, no por medida.
  static const Set<String> _unidadesDeConteo = {'unidad', 'paquete', 'caja'};

  /// Al pasar a venta por peso/volumen la unidad actual suele quedar sin
  /// sentido ("Queso" medido en `paquete`), asi que se propone una coherente.
  /// Solo se cambia si el usuario no habia escogido algo que ya sirva.
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

  /// Si la unidad de venta ya no tiene sentido (por ejemplo se paso de kg a
  /// "unidad"), se vuelve a la del precio en vez de quedar en un valor muerto.
  bool _unidadDeVentaValida(String unidad) =>
      _unidadDeVentaCandidatas.contains(unidad);

  /// Unidades en las que se puede pesar cuando el precio esta en [_unidadMedida].
  ///
  /// Solo las que tienen conversion real: si el precio esta en "unidad", no
  /// tiene sentido ofrecer grams como unidad de pesaje.
  List<String> get _unidadDeVentaCandidatas => [
        _unidadMedida,
        for (final u in Unidades.todas)
          if (u != _unidadMedida &&
              Unidades.factor(origen: u, destino: _unidadMedida) != null)
            u,
      ];

  /// Muestra el selector de balanza cuando hay algo distinto a elegir.
  ///
  /// Si el precio ya esta en la unica unidad disponible (por ejemplo
  /// "unidad"), no hay conversion posible y el selector solo confunde. Si ya son
  /// distintas, se muestra igual aunque el valor siga siendo el del precio: asi
  /// el usuario descubre que la opcion existe en vez de tener que buscarla.
  bool get _mostrarUnidadVenta =>
      _ventaPorPeso && _unidadDeVentaCandidatas.length > 1;

  bool get _porVolumen => _unidadMedida == 'L' || _unidadMedida == 'mL';

  IconData get _iconoMedida {
    if (_porVolumen) return Icons.water_drop_rounded;
    if (_ventaPorPeso) return Icons.scale_rounded;
    return Icons.inventory_2_rounded;
  }

  Future<void> _escanear() async {
    try {
      final resultado = await BarcodeScanner.scan();
      final codigo = resultado.rawContent;
      if (codigo.isEmpty) return;

      setState(() => _codigoController.text = codigo);

      final existente = await DatabaseHelper.instance.getProductoByCodigo(codigo);
      if (existente != null && mounted) {
        await _ofrecerSumarStock(existente);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el codigo de barras')),
      );
    }
  }

  Future<void> _ofrecerSumarStock(Producto producto) async {
    final cantidad = await showDialog<double>(
      context: context,
      builder: (ctx) => _DialogoStockProducto(producto: producto),
    );

    if (cantidad != null && cantidad > 0) {
      await DatabaseHelper.instance
          .updateStock(producto.codigo, cantidad, id: producto.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock actualizado en "${producto.nombre}"'),
          backgroundColor: AppColors.success.withValues(alpha: 0.9),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    final producto = Producto(
      nombre: _nombreController.text.trim(),
      codigo: _codigoController.text.trim(),
      // La categoria se normaliza contra la lista de predeterminadas para que
      // "quesos" y "Quesos" no queden como dos categorias distintas.
      categoria: Categorias.normalizar(_categoriaController.text),
      precio: _precio,
      costo: _costo,
      peso: double.tryParse(_medidaController.text) ?? 1.0,
      stock: double.tryParse(_stockController.text) ?? 0.0,
      marca: _marcaController.text.trim().isEmpty
          ? null
          : _marcaController.text.trim(),
      unidadMedida: _unidadMedida,
      // Solo se guarda si difiere: si son la misma, `null` deja la columna
      // limpia y el producto se lee igual que uno antiguo.
      unidadVenta: _unidadVenta == _unidadMedida ? null : _unidadVenta,
      iva: _iva,
      ventaPorPeso: _ventaPorPeso,
    );

    try {
      await DatabaseHelper.instance.addProducto(producto.toMap());
      // La marca se registra despues: si el producto falla por codigo repetido,
      // no queda una marca huerfana de un producto que nunca existio.
      if (producto.marca != null) {
        await DatabaseHelper.instance.asegurarMarca(producto.marca!);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar. Revisa que el codigo no este repetido.'),
        ),
      );
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
        appBar: AppBar(title: const Text('Nuevo producto')),
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
                _EncabezadoSeccion(
                  icono: Icons.info_outline_rounded,
                  titulo: 'Identificacion',
                  color: AppColors.neonCyan,
                ),
                const SizedBox(height: AppSpacing.sm),
                GlassSurface(
                  blur: false,
                  child: Column(
                    children: [
                      ProductoTextField(
                        controller: _nombreController,
                        label: 'Nombre del producto',
                        icon: Icons.shopping_basket_outlined,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ProductoTextField(
                              controller: _codigoController,
                              label: 'Codigo de barras',
                              icon: Icons.barcode_reader,
                              helperText: 'Opcional',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: GlassIconButton(
                              icon: Icons.qr_code_scanner_rounded,
                              tooltip: 'Escanear codigo',
                              size: 52,
                              color: isDark ? AppColors.neonCyan : AppColors.neonViolet,
                              onPressed: _escanear,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      CategoriaSelector(
                        controller: _categoriaController,
                                                validator: (v) => (v == null || v.isEmpty || v.trim().isEmpty)
                            ? 'Ingresa una categoria'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _EncabezadoSeccion(
                  icono: Icons.tune_rounded,
                  titulo: 'Presentacion',
                  color: AppColors.neonMagenta,
                ),
                const SizedBox(height: AppSpacing.sm),
                GlassSurface(
                  blur: false,
                  child: Column(
                    children: [
                      PresentacionSelector(
                        ventaPorPeso: _ventaPorPeso,
                        unidadMedida: _unidadMedida,
                        onChanged: _alCambiarPresentacion,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _DropdownUnidad(
                        valor: _unidadMedida,
                        items: _unidades,
                        label: _ventaPorPeso
                            ? 'Unidad en que se cotiza el precio'
                            : 'Unidad',
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
                        // Solo tiene sentido cuando hay conversion real; si el
                        // precio esta en kg y la balanza tambien, no hay nada
                        // que mostrar y el selector solo confunde.
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
                _EncabezadoSeccion(
                  icono: Icons.sell_outlined,
                  titulo: 'Precio y existencias',
                  color: AppColors.neonLime,
                ),
                const SizedBox(height: AppSpacing.sm),
                GlassSurface(
                  blur: false,
                  child: Column(
                    children: [
                      PrecioPanel(
                        costoInicial: 0,
                        precioInicial: 0,
                        ivaInicial: Precios.tasaPorDefecto,
                        onCambio: (v) {
                          _costo = v.costo;
                          _precio = v.precio;
                          _iva = v.iva;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ProductoTextField(
                              controller: _medidaController,
                              // El contenido se expresa en la unidad del
                              // precio, que es la del contador de la balanza.
                              label: labelCantidad(
                                porPeso: _ventaPorPeso,
                                unidadMedida: _unidadMedida,
                              ),
                              icon: _iconoMedida,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              helperText: 'Contenido por unidad de venta',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: ProductoTextField(
                              controller: _stockController,
                              // El stock se cuenta en la unidad de la
                              // balanza, que puede ser distinta.
                              label: labelStock(
                                porPeso: _ventaPorPeso,
                                unidadMedida:
                                    _ventaPorPeso ? _unidadVenta : _unidadMedida,
                              ),
                              icon: Icons.inventory_rounded,
                              keyboardType: _ventaPorPeso
                                  ? const TextInputType.numberWithOptions(decimal: true)
                                  : TextInputType.number,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Ingresa el stock' : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                NeonButton(
                  label: 'Guardar producto',
                  icon: Icons.check_rounded,
                  loading: _guardando,
                  onPressed: _guardando ? null : _guardar,
                ),
              ],
            )
                .animate()
                .fadeIn(duration: AppDuration.medium)
                .slideY(begin: 0.04, curve: Curves.easeOutCubic),
          ),
        ),
      ),
    );
  }
}

class _EncabezadoSeccion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final Color color;

  const _EncabezadoSeccion({
    required this.icono,
    required this.titulo,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
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
    );
  }
}

class _DropdownUnidad extends StatelessWidget {
  final String valor;
  final List<String> items;
  final String label;
  final ValueChanged<String?> onChanged;

  const _DropdownUnidad({
    required this.valor,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropdownButtonFormField<String>(
      initialValue: valor,
      isExpanded: true,
      borderRadius: BorderRadius.circular(AppShape.md),
      icon: const Icon(Icons.unfold_more_rounded, size: 20),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.straighten_rounded, size: 20),
      ),
      style: theme.textTheme.titleMedium,
      items: items
          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Dialogo para sumar stock cuando el codigo de barras ya existe.
class _DialogoStockProducto extends StatefulWidget {
  final Producto producto;

  const _DialogoStockProducto({required this.producto});

  @override
  State<_DialogoStockProducto> createState() => _DialogoStockProductoState();
}

class _DialogoStockProductoState extends State<_DialogoStockProducto> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.producto.ventaPorPeso ? '1.0' : '1');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final producto = widget.producto;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: AppColors.neonAmber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppShape.sm),
            ),
            child: const Icon(Icons.inventory_rounded,
                color: AppColors.neonAmber, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ya existe', style: theme.textTheme.titleLarge),
                Text(
                  producto.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Este codigo ya esta registrado. Puedes sumar stock al producto existente en lugar de crear uno nuevo.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: producto.ventaPorPeso
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: labelCantidad(
                porPeso: producto.ventaPorPeso,
                unidadMedida: producto.unidad,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        NeonButton(
          label: 'Sumar stock',
          compact: true,
          expand: false,
          onPressed: () {
            final valor = double.tryParse(_controller.text) ?? 0;
            Navigator.pop(context, valor > 0 ? valor : null);
          },
        ),
      ],
    );
  }
}
