import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/carrito_item.dart';
import '../models/metodo_pago.dart';
import '../models/producto_model.dart';
import '../services/cobro_controller.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/precios.dart';
import '../widgets/producto_text_field.dart';
import '../widgets/vista_previa_cobro.dart';

/// Punto de venta: carrito en memoria que al finalizar descuenta stock y
/// registra la venta con su detalle.
class VentaScreen extends StatefulWidget {
  const VentaScreen({super.key});

  @override
  State<VentaScreen> createState() => _VentaScreenState();
}

class _VentaScreenState extends State<VentaScreen> {
  final List<CarritoItem> _items = [];
  final TextEditingController _searchController = TextEditingController();
  List<Producto> _resultados = [];
  bool _buscando = false;
  bool _finalizando = false;

  /// Modo de redondeo vigente.
  ///
  /// Empieza en el valor por defecto y lo realinea en `didChangeDependencies`:
  /// un inicializador de campo no puede llamar a `dependOnInheritedWidgetOfExactType`
  /// porque corre antes de que el elemento este montado.
  RedondeoCobro _redondeo = RedondeoCobro.sinRedondeo;

  /// Controller del que se escucha, para re-redondear si el ajuste cambia con la
  /// venta abierta. Se guarda aparte porque `dispose` necesita quitar el
  /// listener sin volver a consultar el arbol.
  CobroController? _cobro;

  double get _total => _items.fold(0.0, (suma, item) => suma + item.subtotal);

  /// IVA contenido en el carrito. No cambia el total (los precios ya lo
  /// incluyen), solo se muestra como dato.
  double get _ivaCarrito => Precios.ivaDeLineas(
        _items.map((i) => (subtotal: i.subtotal, tasa: i.producto.iva)),
      );

  /// Cuanto suma cada pulsacion del boton de mas.
  ///
  /// En productos que se pesan el paso es pequeño porque la unidad puede ser el
  /// gramo: sumar 1 g por pulsacion obligaria a tocar 120 veces una cebolla.
  double _paso(CarritoItem item) => item.esPorPeso ? _pasoPorUnidad(item) : 1.0;

  /// Paso coherente con la granularidad de la unidad.
  ///
  /// Un kilo o una libra se incrementan de a 0,1; un gramo o un mililitro de
  /// a 1, porque 0,1 g es ruido de la balanza. Lo mismo con el volumen.
  double _pasoPorUnidad(CarritoItem item) {
    switch (item.producto.unidad) {
      case 'kg':
      case 'lb':
      case 'L':
        return 0.1;
      default:
        return 1.0;
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final controller = CobroScope.of(context);
    if (identical(controller, _cobro)) return;
    _cobro?.removeListener(_alCambiarRedondeo);
    _cobro = controller..addListener(_alCambiarRedondeo);
    _alCambiarRedondeo();
  }

  /// Re-redondea el carrito cuando el tendero cambia el ajuste con la venta
  /// abierta.
  ///
  /// Cada linea guarda el modo con el que se creo. Sin esto, un producto
  /// agregado antes del cambio y otro posterior se cobrarian con reglas
  /// distintas y el total seria una mezcla que nadie pidio.
  void _alCambiarRedondeo() {
    final modo = _cobro?.value ?? RedondeoCobro.sinRedondeo;
    if (modo == _redondeo) return;
    _redondeo = modo;
    for (final item in _items) {
      item.redondeo = modo;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cobro?.removeListener(_alCambiarRedondeo);
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _resultados = [];
        _buscando = false;
      });
      return;
    }

    final encontrados = await DatabaseHelper.instance.searchProductos(query);
    if (!mounted) return;
    setState(() {
      _resultados = encontrados;
      _buscando = true;
    });
  }

  void _limpiarBusqueda() {
    _searchController.clear();
    setState(() {
      _resultados = [];
      _buscando = false;
    });
  }

  /// Indice en el carrito de un producto ya agregado, o -1.
  ///
  /// Un producto puede no tener `id` todavia, y como `null == null` da `true`,
  /// comparar solo por `id` mezclaria en el mismo item dos productos distintos
  /// que aun no estan guardados. Por eso, sin `id` se cae al codigo de barras
  /// y, si tampoco hay, se asume que es otro producto.
  int _indiceDe(Producto producto) => _items.indexWhere((i) {
        if (producto.id != null) return i.producto.id == producto.id;
        final codigo = producto.codigo;
        if (codigo != null && codigo.isNotEmpty) {
          return i.producto.codigo == codigo;
        }
        return false;
      });

  void _agregar(Producto producto) {
    final indice = _indiceDe(producto);
    if (indice >= 0) {
      setState(() => _items[indice].cantidad += _paso(_items[indice]));
      _limpiarBusqueda();
      return;
    }
    _limpiarBusqueda();
    _pedirCantidad(producto);
  }

  Future<void> _escanear() async {
    try {
      final resultado = await BarcodeScanner.scan();
      final codigo = resultado.rawContent;
      if (codigo.isEmpty) return;

      final producto =
          await DatabaseHelper.instance.getProductoByCodigo(codigo);
      if (!mounted) return;

      if (producto == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('El codigo $codigo no esta registrado'),
            backgroundColor: AppColors.danger.withValues(alpha: 0.92),
          ),
        );
        return;
      }
      _agregar(producto);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el codigo')),
      );
    }
  }

  /// Pide la cantidad y agrega el producto al carrito.
  ///
  /// El `TextEditingController` lo crea y destruye el propio dialogo, no este
  /// metodo. Antes lo creaba aqui y lo liberaba justo despues de que
  /// `showDialog` devolviera, pero `showDialog` retorna en cuanto se llama
  /// `Navigator.pop`: la ruta sigue montada durante su transicion de salida
  /// (~150 ms) y el teclado sigue subiendo. Durante esa ventana el `TextField`
  /// se reconstruye (cambia el `MediaQuery.viewInsets` al abrirse el teclado) y
  /// lee un controller ya liberado, lo que en cascada arrastra
  /// "'_dependents.isEmpty': is not true" y "'attached': is not true".
  Future<void> _pedirCantidad(Producto producto) async {
    final resultado = await showDialog<double>(
      context: context,
      builder: (ctx) => _DialogoCantidadVenta(producto: producto),
    );

    if (resultado != null && resultado > 0 && mounted) {
      setState(() => _items.add(CarritoItem(
            producto: producto,
            cantidad: resultado,
            redondeo: _redondeo,
          )));
    }
  }

  void _incrementar(int index) {
    setState(() => _items[index].cantidad += _paso(_items[index]));
  }

  void _decrementar(int index) {
    setState(() {
      final item = _items[index];
      final paso = _paso(item);
      if (item.cantidad > paso) {
        item.cantidad -= paso;
      } else {
        _items.removeAt(index);
      }
    });
  }

  void _quitar(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _finalizar() async {
    if (_items.isEmpty || _finalizando) return;

    // El cobro se pregunta **antes** de tocar el stock. Si el dialogo de cobro
    // se cancela, no hay venta, no hay descuento de inventario y no hay nada que
    // reversar: preguntar despues obligaria a devolver el stock a mano.
    final pago = await showDialog<_Cobro>(
      context: context,
      builder: (ctx) => _DialogoCobro(total: _total),
    );
    if (pago == null || !mounted) return;

    setState(() => _finalizando = true);

    final copia = List<CarritoItem>.from(_items);
    final total = _total;

    try {
      for (final item in copia) {
        await DatabaseHelper.instance.updateStock(
          item.producto.codigo,
          -item.cantidad,
          id: item.producto.id,
        );
      }
      await DatabaseHelper.instance.addVenta(
        total,
        copia,
        metodoPago: pago.metodo,
        recibido: pago.recibido,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _finalizando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo registrar la venta')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _items.clear());

    await showDialog<void>(
      context: context,
      builder: (ctx) => _DialogoVentaFinalizada(
        items: copia,
        total: total,
        metodoPago: pago.metodo,
        recibido: pago.recibido,
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Con el teclado abierto el alto util se reduce a la mitad y la zona de
    // escaneo (que ademas no sirve de nada mientras se escribe) se lleva por
    // delante el espacio. Sin esto la `Column` de abajo no alcanza: el campo de
    // busqueda, la zona de escaneo y la barra de cobro suman mas de lo que
    // queda, y la `Expanded` del medio se va a cero.
    final tecladoAbierto = MediaQuery.viewInsetsOf(context).bottom > 0;

    return AuroraBackground(
      dark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Nueva venta'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Cerrar',
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (!tecladoAbierto) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: _ZonaEscaneo(onEscanear: _escanear),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: _CampoBusqueda(
                    controller: _searchController, onClear: _limpiarBusqueda),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: _cuerpo(theme, isDark)),
              if (_items.isNotEmpty)
                _BarraTotal(
                  total: _total,
                  iva: _ivaCarrito,
                  cantidadItems: _items.length,
                  finalizando: _finalizando,
                  onConfirmar: _finalizar,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cuerpo(ThemeData theme, bool isDark) {
    if (_buscando) {
      if (_resultados.isEmpty) {
        return const _MensajeVacio(
          icono: Icons.search_off_rounded,
          titulo: 'Sin resultados',
          mensaje: 'Prueba con otro nombre o codigo.',
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: _resultados.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          final producto = _resultados[index];
          return _TarjetaResultado(
            producto: producto,
            onTap: () => _agregar(producto),
          );
        },
      );
    }

    if (_items.isEmpty) {
      return const _MensajeVacio(
        icono: Icons.point_of_sale_rounded,
        titulo: 'Carrito vacio',
        mensaje: 'Escanea un codigo o busca un producto para empezar.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _TarjetaCarrito(
          item: item,
          onMas: () => _incrementar(index),
          onMenos: () => _decrementar(index),
          onQuitar: () => _quitar(index),
        )
            .animate()
            .fadeIn(duration: 200.ms)
            .slideX(begin: 0.05, curve: Curves.easeOutCubic);
      },
    );
  }
}

class _ZonaEscaneo extends StatelessWidget {
  final VoidCallback onEscanear;

  const _ZonaEscaneo({required this.onEscanear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: 'Escanear producto',
      child: GestureDetector(
        onTap: onEscanear,
        child: Container(
          // Altura minima, no fija: las dos lineas de texto necesitan mas
          // espacio con la escala de fuente de accesibilidad activada y una
          // `height` fija las desbordaria.
          constraints: const BoxConstraints(minHeight: 66),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.secondary
                    .withValues(alpha: isDark ? 0.22 : 0.14),
                theme.colorScheme.primary
                    .withValues(alpha: isDark ? 0.22 : 0.14),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(AppShape.lg),
            border: Border.all(
              color: (isDark ? AppColors.neonCyan : AppColors.neonViolet)
                  .withValues(alpha: 0.45),
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: AppSpacing.md),
              Icon(
                Icons.qr_code_scanner_rounded,
                size: 30,
                color: isDark ? AppColors.neonCyan : AppColors.neonViolet,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Escanear producto',
                        style: theme.textTheme.titleLarge),
                    Text(
                      'Usa la camara para agregar rapido',
                      style:
                          theme.textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampoBusqueda extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;

  const _CampoBusqueda({required this.controller, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassSurface(
      radius: AppShape.pill,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          style: theme.textTheme.bodyLarge,
          cursorColor: theme.colorScheme.primary,
          decoration: InputDecoration(
            hintText: 'Buscar por nombre...',
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            prefixIcon: Icon(Icons.search_rounded,
                size: 21, color: theme.colorScheme.primary),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: onClear,
                  ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaResultado extends StatelessWidget {
  final Producto producto;
  final VoidCallback onTap;

  const _TarjetaResultado({required this.producto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassSurface(
      onTap: onTap,
      blur: false,
      radius: AppShape.md,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  producto.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    NeonText(
                      text: formatCurrency(producto.precio),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: GlassChip(
                        icon: Icons.inventory_2_rounded,
                        label:
                            'Stock ${formatCantidad(producto.stock, porPeso: producto.ventaPorPeso)}',
                        color: producto.stock <= 5
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.neonCyan, AppColors.neonViolet],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 19),
          ),
        ],
      ),
    );
  }
}

class _TarjetaCarrito extends StatelessWidget {
  final CarritoItem item;
  final VoidCallback onMas;
  final VoidCallback onMenos;
  final VoidCallback onQuitar;

  const _TarjetaCarrito({
    required this.item,
    required this.onMas,
    required this.onMenos,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final producto = item.producto;

    return GlassSurface(
      blur: false,
      radius: AppShape.md,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      producto.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatCurrency(producto.precio)} c/u',
                      style:
                          theme.textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              GlassIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Quitar del carrito',
                size: 34,
                color: AppColors.danger,
                onPressed: onQuitar,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              _BotonCantidad(
                icon: Icons.remove_rounded,
                onTap: onMenos,
                color: AppColors.neonMagenta,
              ),
              Expanded(
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        formatCantidad(item.cantidad, porPeso: item.esPorPeso),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (item.esPorPeso)
                        Text(
                          producto.unidad,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontSize: 11),
                        ),
                      if (item.notaConversion != null)
                        Text(
                          item.notaConversion!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _BotonCantidad(
                icon: Icons.add_rounded,
                onTap: onMas,
                color: isDark ? AppColors.neonCyan : AppColors.neonViolet,
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  NeonText(
                    text: formatCurrency(item.subtotal),
                    style: theme.textTheme.titleLarge,
                  ),
                  Text('subtotal',
                      style:
                          theme.textTheme.bodyMedium?.copyWith(fontSize: 10.5)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotonCantidad extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _BotonCantidad({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.42)),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }
}

class _BarraTotal extends StatelessWidget {
  final double total;
  final double iva;
  final int cantidadItems;
  final bool finalizando;
  final VoidCallback onConfirmar;

  const _BarraTotal({
    required this.total,
    required this.iva,
    required this.cantidadItems,
    required this.finalizando,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: GlassSurface(
        glow: true,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total · $cantidadItems ${cantidadItems == 1 ? 'item' : 'items'}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  NeonText(
                    text: '${formatCurrency(total)} COP',
                    style: theme.textTheme.headlineMedium,
                  ),
                  // Solo aparece si algun producto del carrito tiene IVA.
                  if (iva > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'IVA incluido ${formatCurrency(iva)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            NeonButton(
              label: 'Cobrar',
              icon: Icons.payments_rounded,
              compact: true,
              expand: false,
              loading: finalizando,
              onPressed: finalizando ? null : onConfirmar,
            ),
          ],
        ),
      ),
    );
  }
}

class _MensajeVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;

  const _MensajeVacio({
    required this.icono,
    required this.titulo,
    required this.mensaje,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // El estado vacio (icono de 92 px + titulo + mensaje) mide cerca de 200 px.
    // Con el teclado abierto el alto disponible baja a un puñado de pixeles y un
    // `Center` con `Column` revienta con "A RenderFlex overflowed by N pixels":
    // `Center` pasa constrains laxxos y la `Column` se queda con el alto que le
    // dan, por mas chico que sea. `LayoutBuilder` + `ConstrainedBox` +
    // `SingleChildScrollView` es el patron de "centrado pero desplazable":
    // centrado mientras alcanza, con scroll cuando no.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                          AppColors.neonCyan
                              .withValues(alpha: isDark ? 0.18 : 0.11),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppShape.xl),
                    ),
                    child:
                        Icon(icono, size: 42, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(titulo, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    mensaje,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
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

/// `StatefulWidget` solo para poder repintar la vista previa del cobro: cada
/// tecla tiene que recalcular cuanto se va a cobrar sin cerrar el dialogo.
class _DialogoCantidadVenta extends StatefulWidget {
  final Producto producto;

  const _DialogoCantidadVenta({required this.producto});

  @override
  State<_DialogoCantidadVenta> createState() => _DialogoCantidadVentaState();
}

class _DialogoCantidadVentaState extends State<_DialogoCantidadVenta> {
  /// Vive exactamente lo que vive el dialogo.
  ///
  /// Liberarlo en `dispose` y no cuando se cierra el dialogo es lo que evita
  /// "A TextEditingController was used after being disposed": el `State` se
  /// desmonta cuando la ruta termina su transicion de salida, no en el
  /// instante del `Navigator.pop`.
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.producto.ventaPorPeso ? '1.0' : '1',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.neonCyan : AppColors.neonViolet;
    final producto = widget.producto;

    return AlertDialog(
      // Con el teclado abierto el alto disponible se reduce a un puñado de
      // pixeles y el contenido del `AlertDialog` se pasa. Sin `scrollable` el
      // `Column` interno no tiene donde ceder y desborda.
      scrollable: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(producto.nombre, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              GlassChip(
                icon: Icons.sell_rounded,
                label: '${formatCurrency(producto.precio)} c/u',
                color: accent,
              ),
              if (producto.marca != null)
                GlassChip(
                  icon: Icons.branding_watermark_rounded,
                  label: producto.marca!,
                  color: AppColors.neonMagenta,
                ),
              GlassChip(
                icon: Icons.inventory_2_rounded,
                label:
                    'Stock ${formatCantidad(producto.stock, porPeso: producto.ventaPorPeso)}',
                color:
                    producto.stock <= 5 ? AppColors.warning : AppColors.success,
              ),
            ],
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: producto.ventaPorPeso
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: theme.textTheme.headlineSmall,
            decoration: InputDecoration(
              labelText: labelCantidad(
                porPeso: producto.ventaPorPeso,
                unidadMedida: producto.unidad,
              ),
              helperText: producto.equivalencia,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          // Vista previa del cobro: es lo que evita cobrar 600.000 por una
          // cebolla de 120 g cuando la libra esta a 5.000.
          VistaPreviaCobro(producto: producto, controller: _controller),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
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
          label: 'Agregar',
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

/// Filas con el desglose del IVA de la venta.
///
/// El precio de cada producto ya incluye su IVA, asi que esto **no** cambia el
/// total: solo informa cuanto del dinero cobrado corresponde a impuesto y
/// cuantos son base gravable. Se ocultan por completo cuando ningun producto
/// de la venta tiene IVA.
List<Widget> _desgloseImpuesto(ThemeData theme, List<CarritoItem> items) {
  final base = items.fold<double>(
    0,
    (suma, i) => suma + Precios.precioSinIVA(i.subtotal, i.producto.iva),
  );
  final impuesto = Precios.ivaDeLineas(
    items.map((i) => (subtotal: i.subtotal, tasa: i.producto.iva)),
  );

  if (impuesto <= 0) return const [];

  return [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            'Base gravable',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(formatCurrency(base), style: theme.textTheme.bodyMedium),
      ],
    ),
    const SizedBox(height: 4),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            'IVA incluido',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          formatCurrency(impuesto),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
    const SizedBox(height: 6),
  ];
}

class _DialogoVentaFinalizada extends StatelessWidget {
  final List<CarritoItem> items;
  final double total;
  final MetodoPago metodoPago;
  final double? recibido;

  const _DialogoVentaFinalizada({
    required this.items,
    required this.total,
    required this.metodoPago,
    required this.recibido,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      // Con el teclado arriba (el campo de busqueda conserva el foco hasta que
      // se confirma la venta) la altura util baja a un puñado de pixeles. Con
      // `scrollable` el titulo y el contenido van en un `SingleChildScrollView`
      // y solo las acciones quedan fijas, que es el unico que no debe moverse.
      //
      // Ojo: el `Flexible` del `ListView` de aca abajo tenia que salirse con
      // `scrollable`, porque dentro de un scroll vertical las restricciones de
      // alto son infinitas y un `Flexible` ahi revienta con "RenderFlex children
      // have non-zero flex but incoming height constraints are unbounded". El
      // que la lista sea corta ya la comprime sola al ser una `Column`.
      scrollable: true,
      title: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: AppColors.success, size: 24),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Venta registrada', style: theme.textTheme.titleLarge),
                Text('Stock descontado del inventario',
                    style: theme.textTheme.bodyMedium),
              ],
            ),
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
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 16),
              _FilaVentaFinalizada(item: items[i]),
            ],
            const Divider(height: 24),
            ..._desgloseImpuesto(theme, items),
            const Divider(height: 24),
            _FilaResumenPago(
              metodoPago: metodoPago,
              recibido: recibido,
              total: total,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Total', style: theme.textTheme.titleMedium),
                const SizedBox(width: AppSpacing.sm),
                // `Flexible` + `FittedBox`: un total largo ("1.250.000") con
                // `headlineSmall` no entra en un dialogo angosto y desbordaba
                // la fila en horizontal.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: NeonText(
                      text: formatCurrency(total),
                      style: theme.textTheme.headlineSmall,
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
          label: 'Listo',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

/// Una linea de la lista de productos de la venta confirmada.
///
/// Se extrajo del `ListView` porque al poner `scrollable` en el `AlertDialog`
/// no cabia ni `Flexible` ni un `ListView` dentro de una `Column` de alto
/// infinito.
class _FilaVentaFinalizada extends StatelessWidget {
  final CarritoItem item;

  const _FilaVentaFinalizada({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            item.producto.nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '${formatCantidad(item.cantidad, porPeso: item.esPorPeso)} x',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(width: 6),
        Text(
          formatCurrency(item.subtotal),
          style: theme.textTheme.titleMedium,
        ),
      ],
    );
  }
}

/// Como se pago y cuanto se devolvio, en el dialogo de venta confirmada.
///
/// Sin esta fila el cajero no tiene donde anotar a quien le dio Nequi, y al
/// cierre del dia no hay forma de saber si los vueltos cuadran con la caja.
class _FilaResumenPago extends StatelessWidget {
  final MetodoPago metodoPago;
  final double? recibido;
  final double total;

  const _FilaResumenPago({
    required this.metodoPago,
    required this.recibido,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // El vuelto va en su propia fila y no en la misma que el importe. En un
    // dialogo angosto (232 px utiles con el teclado abierto) las tres cosas en
    // una sola `Row` se salen: "Recibido" + "10.000" + "Vuelto 9.000" no caben
    // en horizontal, y un `Expanded` en la etiqueta no salva a las otras dos,
    // que no son flexibles.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              metodoPago.icono,
              size: 18,
              color: isDark ? AppColors.neonCyan : AppColors.cyanDeep,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                recibido == null ? metodoPago.etiqueta : 'Recibido',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              formatCurrency(recibido ?? total),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
        if (recibido != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            // El vuelto lleva su propio color: es el dato que el cajero necesita
            // leer de un vistazo antes de entregar.
            child: GlassChip(
              icon: Icons.undo_rounded,
              label: etiquetaVuelto(total, recibido!),
              color: isDark ? AppColors.neonLime : AppColors.success,
            ),
          ),
        ],
      ],
    );
  }
}

/// Lo que el dialogo de cobro devuelve al punto de venta.
///
/// `recibido` es `null` para un pago exacto (Nequi) y tambien para efectivo si
/// el cajero no lo escribio: se guarda lo que se sabe, no un cero inventado.
class _Cobro {
  final MetodoPago metodo;
  final double? recibido;

  const _Cobro({required this.metodo, this.recibido});
}

/// Dialogo de cobro: como paga y, si es efectivo, cuanto entrego.
///
/// Va **antes** de descontar el stock. Si fuera despues, cancelar el cobro
/// dejaria la venta sin registrar con el inventario ya movido, y deshacer eso a
/// mano es el peor error posible en una caja.
class _DialogoCobro extends StatefulWidget {
  final double total;

  const _DialogoCobro({required this.total});

  @override
  State<_DialogoCobro> createState() => _DialogoCobroState();
}

class _DialogoCobroState extends State<_DialogoCobro> {
  MetodoPago _metodo = MetodoPago.efectivo;
  String _error = '';

  /// Viven lo que vive el dialogo, por el gotcha de AGENTS.md.
  late final TextEditingController _recibidoController;
  late final FocusNode _focoRecibido;

  @override
  void initState() {
    super.initState();
    _recibidoController = TextEditingController();
    _focoRecibido = FocusNode();
  }

  @override
  void dispose() {
    _recibidoController.dispose();
    _focoRecibido.dispose();
    super.dispose();
  }

  double get _recibido => parseCurrency(_recibidoController.text);

  double get _vuelto => _recibido - widget.total;

  /// Billetes que se ofrecen para un total dado.
  ///
  /// Solo los que cubren el total: ofrecer un billete de 5.000 para un total de
  /// 12.000 invita a elegir algo que no sirve. El campo acepta cualquier otro
  /// numero, los chips son un atajo y no una restriccion.
  static List<double> billetesPara(double total) {
    const denominaciones = [
      1000.0,
      2000.0,
      5000.0,
      10000.0,
      20000.0,
      50000.0,
      100000.0,
      200000.0,
    ];
    return denominaciones.where((b) => b >= total).take(4).toList();
  }

  void _aceptar() {
    if (_metodo.pideVuelto) {
      if (_recibidoController.text.trim().isEmpty) {
        setState(() => _error = 'Escribe cuanto recibiste.');
        return;
      }
      // Menos del total no es un vuelto negativo, es una venta incompleta. Sin
      // este chequeo la venta se guardaba por menos de lo que el cliente debia
      // y el faltante se descubria al dia siguiente.
      if (_vuelto < 0) {
        setState(
          () => _error = 'Faltan ${formatCurrency(-_vuelto)} para completar.',
        );
        return;
      }
    }

    Navigator.pop(
      context,
      _Cobro(
        metodo: _metodo,
        // Para un pago exacto no hay billete: se guarda `null` y no una copia
        // del total, porque "llego exacto" y "no aplica" no son el mismo dato.
        recibido: _metodo.pideVuelto ? _recibido : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      // El campo tiene `autofocus`, asi que el teclado se abre y la altura util
      // se reduce a la mitad: sin `scrollable` el contenido se sale del dialogo.
      scrollable: true,
      title: const Text('Cobrar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOTAL A COBRAR', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: NeonText(
                    text: formatCurrency(widget.total),
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'COP',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('METODO DE PAGO', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (final metodo in MetodoPago.values)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: metodo == MetodoPago.values.last ? 0 : 6,
                    ),
                    child: _BotonMetodoPago(
                      metodo: metodo,
                      seleccionado: _metodo == metodo,
                      onTap: () {
                        setState(() {
                          _metodo = metodo;
                          _error = '';
                        });
                        if (!metodo.pideVuelto) _focoRecibido.unfocus();
                      },
                    ),
                  ),
                ),
            ],
          ),
          if (_metodo.pideVuelto) ...[
            const SizedBox(height: AppSpacing.md),
            ProductoTextField(
              controller: _recibidoController,
              label: 'Billete recibido',
              icon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
              focusNode: _focoRecibido,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              suffixText: 'COP',
              onChanged: (_) {
                if (_error.isNotEmpty) setState(() => _error = '');
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _FilaBilletes(
              billetes: billetesPara(widget.total),
              color: theme.colorScheme.primary,
              onTap: (valor) {
                _recibidoController.text = valor.round().toString();
                setState(() => _error = '');
                _focoRecibido.unfocus();
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            // El vuelto se muestra mientras se escribe y en rojo si el billete
            // no alcanza: es el dato que evita entregar de mas.
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppShape.sm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Vuelto', style: theme.textTheme.titleMedium),
                  ),
                  Text(
                    _recibidoController.text.trim().isEmpty
                        ? '--'
                        : formatCurrency(_vuelto < 0 ? 0 : _vuelto),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: _vuelto < 0
                          ? AppColors.danger
                          : (isDark ? AppColors.neonLime : AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        NeonButton(
          // "Confirmar" y no "Cobrar": el titulo del dialogo ya dice "Cobrar"
          // y el boton de la barra tambien. Dos widgets con el mismo texto
          // apilados obligan a los tests a acotar el finder con `descendant`
          // para no tocar el equivocado.
          label: 'Confirmar',
          icon: Icons.check_rounded,
          compact: true,
          expand: false,
          onPressed: _aceptar,
        ),
      ],
    );
  }
}

/// Boton de metodo de pago dentro del dialogo de cobro.
class _BotonMetodoPago extends StatelessWidget {
  final MetodoPago metodo;
  final bool seleccionado;
  final VoidCallback onTap;

  const _BotonMetodoPago({
    required this.metodo,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    return Semantics(
      button: true,
      selected: seleccionado,
      label: metodo.etiqueta,
      // `Material` explicito porque `InkWell` pinta su ripple sobre el
      // `Material` mas cercano y sin el no se ve nada.
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppShape.sm),
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppDuration.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: seleccionado
                  ? accent.withValues(alpha: 0.22)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppShape.sm),
              border: Border.all(
                color: seleccionado
                    ? accent.withValues(alpha: 0.7)
                    : accent.withValues(alpha: 0.2),
                width: seleccionado ? 1.6 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  metodo.icono,
                  size: 20,
                  color: seleccionado
                      ? (isDark ? Colors.white : accent)
                      : accent.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 4),
                Text(
                  metodo.etiqueta,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: seleccionado
                        ? (isDark ? Colors.white : accent)
                        : accent.withValues(alpha: 0.7),
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

/// Atajos de billete: los que cubren el total, para no escribir el numero.
class _FilaBilletes extends StatelessWidget {
  final List<double> billetes;
  final Color color;
  final ValueChanged<double> onTap;

  const _FilaBilletes({
    required this.billetes,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (billetes.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final billete in billetes)
          GlassChip(
            icon: Icons.payments_rounded,
            label: formatCurrency(billete),
            color: color,
            onTap: () => onTap(billete),
          ),
      ],
    );
  }
}
