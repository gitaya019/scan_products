import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/producto_model.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../utils/formatters.dart';
import '../widgets/sidebar.dart';
import 'add_producto_screen.dart';
import 'edit_producto_screen.dart';
import 'venta_screen.dart';

/// Pantalla principal: lista de productos con busqueda, filtro de stock bajo
/// y acceso rapido a agregar stock o abrir el punto de venta.
class HomeScreen extends StatefulWidget {
  final ThemeController themeController;

  const HomeScreen({super.key, required this.themeController});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<Producto> _productos = [];
  final TextEditingController _searchController = TextEditingController();
  bool _stockBajoActivo = false;
  bool _cargando = true;

  /// Umbral de stock bajo. A partir de aqui el producto se marca en alerta.
  static const int _umbralStockBajo = 5;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrar);
    _cargarProductos();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_filtrar)
      ..dispose();
    super.dispose();
  }

  Future<void> _cargarProductos() async {
    final data = await DatabaseHelper.instance.getProductos();
    if (!mounted) return;
    setState(() {
      _productos = data.map((e) => Producto.fromMap(e)).toList();
      _cargando = false;
    });
  }

  List<Producto> get _filtrados => _productos.where((p) {
        final texto = _searchController.text.trim().toLowerCase();
        final coincideTexto = texto.isEmpty ||
            p.nombre.toLowerCase().contains(texto) ||
            (p.codigo ?? '').toLowerCase().contains(texto);
        final coincideStock = !_stockBajoActivo || p.stock <= _umbralStockBajo;
        return coincideTexto && coincideStock;
      }).toList();

  int get _conteoStockBajo =>
      _productos.where((p) => p.stock <= _umbralStockBajo).length;

  bool get _estaBuscando => _searchController.text.trim().isNotEmpty;

  void _filtrar() => setState(() {});

  void _alternarStockBajo() => setState(() => _stockBajoActivo = !_stockBajoActivo);

  Future<void> _escanear() async {
    try {
      final resultado = await BarcodeScanner.scan();
      final codigo = resultado.rawContent;
      if (codigo.isNotEmpty && mounted) {
        _searchController.text = codigo;
      }
    } catch (_) {
      // El usuario cancelo el escaner o no hay camara disponible.
    }
  }

  Future<void> _agregarStock(Producto producto) async {
    final cantidad = await showDialog<double>(
      context: context,
      builder: (ctx) => _DialogoCantidad(producto: producto, modo: _DialogoCantidadModo.sumar),
    );

    if (cantidad != null && cantidad > 0) {
      await DatabaseHelper.instance.updateStock(
        producto.codigo,
        cantidad,
        id: producto.id,
      );
      _cargarProductos();
    }
  }

  Future<void> _eliminar(Producto producto) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        titulo: 'Eliminar producto',
        mensaje:
            'Se eliminara "${producto.nombre}" del inventario. Esta accion no se puede deshacer.',
        textoConfirmar: 'Eliminar',
        colorConfirmar: AppColors.danger,
      ),
    );

    if (confirmado == true && producto.id != null) {
      await DatabaseHelper.instance.deleteProducto(producto.id!);
      _cargarProductos();
    }
  }

  Future<void> _abrirVenta() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VentaScreen()),
    );
    _cargarProductos();
  }

  Future<void> _abrirAgregar() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddProductoScreen()),
    );
    _cargarProductos();
  }

  Future<void> _ir(Producto producto) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditProductoScreen(producto: producto),
      ),
    );
    _cargarProductos();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtrados = _filtrados;

    return AuroraBackground(
      dark: isDark,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.transparent,
          drawer: Sidebar(
            themeController: widget.themeController,
            onVenta: _abrirVenta,
          ),
          body: SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                _AppBarAurada(
                  isDark: isDark,
                  onVenta: _abrirVenta,
                  onAgregar: _abrirAgregar,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: _BarraBusqueda(
                      controller: _searchController,
                      onEscanear: _escanear,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ResumenRapido(
                            total: _productos.length,
                            stockBajo: _conteoStockBajo,
                            mostrando: filtrados.length,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _FiltroStockBajo(
                          activo: _stockBajoActivo,
                          cantidad: _conteoStockBajo,
                          onTap: _alternarStockBajo,
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
                if (_cargando)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filtrados.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EstadoVacio(
                      buscando: _estaBuscando,
                      stockBajoActivo: _stockBajoActivo,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      120,
                    ),
                    sliver: SliverList.separated(
                      itemCount: filtrados.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final producto = filtrados[index];
                        return _TarjetaProducto(
                          producto: producto,
                          umbral: _umbralStockBajo,
                          onAgregarStock: () => _agregarStock(producto),
                          onTap: () => _ir(producto),
                          onEliminar: () => _eliminar(producto),
                        )
                            .animate()
                            .fadeIn(
                              duration: 280.ms,
                              delay: Duration(
                                milliseconds: (index * 45).clamp(0, 320),
                              ),
                            )
                            .slideY(begin: 0.06, curve: Curves.easeOutCubic);
                      },
                    ),
                  ),
              ],
            ),
          ),
          floatingActionButton: _FabVenta(onTap: _abrirVenta),
        ),
      ),
    );
  }
}

class _AppBarAurada extends StatelessWidget {
  final bool isDark;
  final VoidCallback onVenta;
  final VoidCallback onAgregar;

  const _AppBarAurada({
    required this.isDark,
    required this.onVenta,
    required this.onAgregar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleSpacing: AppSpacing.md,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Inventario',
            style: theme.textTheme.headlineSmall,
          ),
          Text(
            'Control de stock en tiempo real',
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12.5),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          child: GlassIconButton(
            icon: Icons.add_box_rounded,
            tooltip: 'Agregar producto',
            color: isDark ? AppColors.neonMagenta : AppColors.neonViolet,
            onPressed: onAgregar,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: GlassIconButton(
            icon: Icons.point_of_sale_rounded,
            tooltip: 'Nueva venta',
            color: isDark ? AppColors.neonCyan : AppColors.neonViolet,
            onPressed: onVenta,
          ),
        ),
      ],
    );
  }
}

class _BarraBusqueda extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onEscanear;

  const _BarraBusqueda({
    required this.controller,
    required this.onEscanear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassSurface(
      radius: AppShape.pill,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => TextField(
                controller: controller,
                style: theme.textTheme.bodyLarge,
                cursorColor: theme.colorScheme.primary,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o codigo...',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 19),
                          onPressed: controller.clear,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          GlassIconButton(
            icon: Icons.qr_code_scanner_rounded,
            tooltip: 'Escanear codigo',
            size: 42,
            color: isDark ? AppColors.neonCyan : AppColors.neonViolet,
            onPressed: onEscanear,
          ),
        ],
      ),
    );
  }
}

class _ResumenRapido extends StatelessWidget {
  final int total;
  final int stockBajo;
  final int mostrando;

  const _ResumenRapido({
    required this.total,
    required this.stockBajo,
    required this.mostrando,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassSurface(
      radius: AppShape.pill,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // `Flexible` porque esta barra comparte fila con el filtro de stock
          // bajo: en pantallas de 360px las dos metricas no caben si se dejan
          // pedir su ancho intrinseco completo.
          Flexible(
            child: _Metrica(
              valor: '$mostrando',
              etiqueta: mostrando == total ? 'productos' : 'de $total',
              color: isDark ? AppColors.neonCyan : AppColors.neonViolet,
            ),
          ),
          Container(
            height: 22,
            width: 1,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.14),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: _Metrica(
              valor: '$stockBajo',
              etiqueta: 'stock bajo',
              color: stockBajo > 0 ? AppColors.warning : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  final String valor;
  final String etiqueta;
  final Color color;

  const _Metrica({
    required this.valor,
    required this.etiqueta,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          valor,
          style: theme.textTheme.titleLarge?.copyWith(color: color),
        ),
        const SizedBox(width: 6),
        // La etiqueta cede espacio antes que la cifra: es la parte prescindible.
        Flexible(
          child: Text(
            etiqueta,
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _FiltroStockBajo extends StatelessWidget {
  final bool activo;
  final int cantidad;
  final VoidCallback onTap;

  const _FiltroStockBajo({
    required this.activo,
    required this.cantidad,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hayAlerta = cantidad > 0;
    final color = activo
        ? AppColors.warning
        : (hayAlerta ? AppColors.neonAmber : theme.colorScheme.primary);

    return Semantics(
      button: true,
      selected: activo,
      label: 'Filtrar productos con stock bajo',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: color.withValues(alpha: activo ? 0.22 : 0.12),
            borderRadius: BorderRadius.circular(AppShape.pill),
            border: Border.all(
              color: color.withValues(alpha: activo ? 0.7 : 0.35),
              width: activo ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 19, color: color),
              if (hayAlerta) ...[
                const SizedBox(width: 6),
                Text(
                  '$cantidad',
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaProducto extends StatelessWidget {
  final Producto producto;
  final int umbral;
  final VoidCallback onAgregarStock;
  final VoidCallback onTap;
  final VoidCallback onEliminar;

  const _TarjetaProducto({
    required this.producto,
    required this.umbral,
    required this.onAgregarStock,
    required this.onTap,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final stockBajo = producto.stock <= umbral;

    final stockColor = producto.stock <= 0
        ? AppColors.danger
        : (stockBajo ? AppColors.warning : AppColors.success);

    return Dismissible(
      key: ValueKey(producto.id ?? producto.nombre),
      direction: DismissDirection.startToEnd,
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppShape.lg),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.lg),
        child: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
            SizedBox(width: AppSpacing.xs),
            Text(
              'Eliminar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onEliminar();
        return false; // La eliminacion real la confirma el dialogo.
      },
      child: GlassSurface(
        onTap: onTap,
        blur: false,
        tint: stockBajo && isDark
            ? AppColors.warning.withValues(alpha: 0.12)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producto.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge,
                      ),
                      if (producto.categoria.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          producto.categoria,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    NeonText(
                      text: formatCurrency(producto.precio),
                      style: theme.textTheme.titleLarge,
                    ),
                    Text('precio', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (producto.marca != null && producto.marca!.isNotEmpty)
                  GlassChip(
                    icon: Icons.branding_watermark_rounded,
                    label: producto.marca!,
                    color: isDark ? AppColors.neonMagenta : AppColors.neonViolet,
                  ),
                GlassChip(
                  icon: producto.ventaPorPeso
                      ? Icons.scale_rounded
                      : Icons.inventory_2_rounded,
                  label: producto.ventaPorPeso
                      ? producto.unidad
                      : 'Por unidad',
                  color: theme.colorScheme.secondary,
                ),
                if (producto.iva > 0)
                  GlassChip(
                    icon: Icons.receipt_long_rounded,
                    label: 'IVA ${producto.iva.toStringAsFixed(0)}%',
                    color: AppColors.neonAmber,
                  ),
                GlassChip(
                  icon: stockBajo
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_rounded,
                  label:
                      'Stock ${formatCantidad(producto.stock, porPeso: producto.ventaPorPeso)}',
                  color: stockColor,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _AccionPill(
                    icon: Icons.add_rounded,
                    label: 'Agregar stock',
                    color: AppColors.success,
                    onTap: onAgregarStock,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                GlassIconButton(
                  icon: Icons.chevron_right_rounded,
                  size: 40,
                  onPressed: onTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AccionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppShape.pill),
            border: Border.all(color: color.withValues(alpha: 0.32)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final bool buscando;
  final bool stockBajoActivo;

  const _EstadoVacio({
    required this.buscando,
    required this.stockBajoActivo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (icono, titulo, mensaje) = buscando
        ? (
            Icons.search_off_rounded,
            'Sin resultados',
            'No encontramos productos que coincidan con tu busqueda.',
          )
        : stockBajoActivo
            ? (
                Icons.verified_rounded,
                'Todo en orden',
                'Ningun producto esta por debajo del umbral de stock.',
              )
            : (
                Icons.inventory_2_outlined,
                'Inventario vacio',
                'Agrega tu primer producto con el boton + o escanea un codigo.',
              );

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 96,
            width: 96,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.neonViolet.withValues(alpha: isDark ? 0.28 : 0.16),
                  AppColors.neonCyan.withValues(alpha: isDark ? 0.20 : 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppShape.xl),
            ),
            child: Icon(icono, size: 44, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(titulo, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: AppDuration.medium);
  }
}

class _FabVenta extends StatelessWidget {
  final VoidCallback onTap;

  const _FabVenta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.neonCyan, AppColors.neonViolet],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppShape.pill),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonViolet.withValues(alpha: isDark ? 0.5 : 0.34),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.point_of_sale_rounded),
        label: Text(
          'Vender',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
        shape: const StadiumBorder(),
      ),
    );
  }
}

/// Dialogo compartido para sumar o restar cantidad a un producto.
class _DialogoCantidad extends StatefulWidget {
  final Producto producto;
  final _DialogoCantidadModo modo;

  const _DialogoCantidad({
    required this.producto,
    required this.modo,
  });

  @override
  State<_DialogoCantidad> createState() => _DialogoCantidadState();
}

enum _DialogoCantidadModo { sumar, restar }

class _DialogoCantidadState extends State<_DialogoCantidad> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.modo == _DialogoCantidadModo.restar
          ? formatCantidad(widget.producto.stock, porPeso: widget.producto.ventaPorPeso)
          : (widget.producto.ventaPorPeso ? '1.0' : '1'),
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
    final producto = widget.producto;
    final sumando = widget.modo == _DialogoCantidadModo.sumar;
    final color = sumando ? AppColors.success : AppColors.warning;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      title: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppShape.sm),
            ),
            child: Icon(
              sumando ? Icons.add_rounded : Icons.remove_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sumando ? 'Agregar stock' : 'Restar stock',
                  style: theme.textTheme.titleLarge,
                ),
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
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              GlassChip(
                icon: Icons.inventory_2_rounded,
                label:
                    'Actual ${formatCantidad(producto.stock, porPeso: producto.ventaPorPeso)}',
                color: color,
              ),
              if (producto.ventaPorPeso)
                GlassChip(
                  icon: Icons.scale_rounded,
                  label: producto.unidad,
                  color: AppColors.neonCyan,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: producto.ventaPorPeso
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            style: theme.textTheme.headlineSmall,
            decoration: InputDecoration(
              labelText: labelCantidad(
                porPeso: producto.ventaPorPeso,
                unidadMedida: producto.unidad,
              ),
            ),
            onSubmitted: (_) => _confirmar(context),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ),
        NeonButton(
          label: sumando ? 'Agregar' : 'Restar',
          compact: true,
          expand: false,
          onPressed: () => _confirmar(context),
        ),
      ],
    );
  }

  void _confirmar(BuildContext context) {
    final valor = double.tryParse(_controller.text) ?? 0;
    Navigator.pop(context, valor > 0 ? valor : null);
  }
}

/// Dialogo de confirmacion reutilizable.
class _ConfirmDialog extends StatelessWidget {
  final String titulo;
  final String mensaje;
  final String textoConfirmar;
  final Color colorConfirmar;

  const _ConfirmDialog({
    required this.titulo,
    required this.mensaje,
    required this.textoConfirmar,
    required this.colorConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(titulo, style: theme.textTheme.titleLarge),
      content: Text(mensaje, style: theme.textTheme.bodyLarge),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancelar',
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: colorConfirmar,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppShape.pill),
            ),
          ),
          child: Text(textoConfirmar),
        ),
      ],
    );
  }
}
