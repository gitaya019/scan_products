import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/database_helper.dart';
import '../models/producto_model.dart';
import 'add_producto_screen.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'edit_producto_screen.dart';
import 'venta_screen.dart';
import '../widgets/sidebar.dart';
import '../utils/formatters.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Producto> productos = [];
  List<Producto> productosFiltrados = [];
  final _searchController = TextEditingController();
  bool _isSearching = false;
  bool _stockBajoActivo = false;

  Future<void> _loadProductos() async {
    final data = await DatabaseHelper.instance.getProductos();
    setState(() {
      productos = data.map((e) => Producto.fromMap(e)).toList();
      productosFiltrados = productos;
    });
  }

  int get _umbralStockBajo => 5;
  int get _conteoStockBajo =>
      productos.where((p) => p.stock <= _umbralStockBajo).length;

  void _filtrar() {
    setState(() {
      _isSearching = _searchController.text.isNotEmpty;
      _stockBajoActivo = _stockBajoActivo;

      productosFiltrados = productos.where((p) {
        final coincideBusqueda = _searchController.text.isEmpty ||
            p.nombre
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            p.codigo
                .toLowerCase()
                .contains(_searchController.text.toLowerCase());
        final coincideStock = !_stockBajoActivo || p.stock <= _umbralStockBajo;
        return coincideBusqueda && coincideStock;
      }).toList();
    });
  }

  void _toggleStockBajo() {
    _stockBajoActivo = !_stockBajoActivo;
    _filtrar();
  }

  Future<void> _scanBarcode() async {
    try {
      var result = await BarcodeScanner.scan();
      String scannedCode = result.rawContent;

      if (scannedCode.isNotEmpty) {
        _searchController.text = scannedCode;
      }
    } catch (e) {
      print("Error al escanear: $e");
    }
  }

  Future<void> _mostrarDialogoAgregarStock(Producto producto) async {
    final controller = TextEditingController();
    final cantidad = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Agregar Stock"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(producto.nombre,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Cantidad a agregar",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final cant = double.tryParse(controller.text) ?? 0;
              Navigator.pop(ctx, cant > 0 ? cant : null);
            },
            child: const Text("Agregar"),
          ),
        ],
      ),
    );

    if (cantidad != null && cantidad > 0) {
      await DatabaseHelper.instance.updateStock(producto.codigo, cantidad);
      _loadProductos();
    }
  }

  Future<void> _deleteProducto(int id) async {
    await DatabaseHelper.instance.deleteProducto(id);
    _loadProductos();
  }

  @override
  void initState() {
    super.initState();
    _loadProductos();
    _searchController.addListener(_filtrar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: Sidebar(
        onVenta: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VentaScreen()),
          );
          _loadProductos();
        },
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.white,
              title: Text(
                "Mis Productos",
                style: TextStyle(
                    fontWeight: FontWeight.w300, color: Colors.black87),
              ),
              actions: [
                IconButton(
                  icon:
                      Icon(Icons.shopping_cart_outlined, color: Colors.black54),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => VentaScreen()),
                    );
                    _loadProductos();
                  },
                ),
              ],
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(80),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: "Buscar producto...",
                              hintStyle: TextStyle(color: Colors.black45),
                              prefixIcon:
                                  Icon(Icons.search, color: Colors.black54),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear,
                                          color: Colors.black54),
                                      onPressed: () {
                                        _searchController.clear();
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 15, horizontal: 15),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Badge(
                        isLabelVisible: _conteoStockBajo > 0,
                        label: Text(
                          '$_conteoStockBajo',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white),
                        ),
                        smallSize: 18,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _stockBajoActivo
                                ? Colors.orange.shade50
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.warning_amber_rounded,
                              color: _stockBajoActivo
                                  ? Colors.orange.shade800
                                  : Colors.black54,
                            ),
                            onPressed: _toggleStockBajo,
                            tooltip: "Filtrar stock bajo",
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(Icons.qr_code_scanner,
                              color: Colors.black54),
                          onPressed: _scanBarcode,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (productosFiltrados.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          _isSearching
                              ? Icons.search_off
                              : Icons.warning_amber_rounded,
                          size: 80,
                          color: Colors.black26),
                      SizedBox(height: 16),
                      Text(
                        _isSearching
                            ? "No se encontraron productos"
                            : _stockBajoActivo
                                ? "No hay productos con stock bajo"
                                : "No hay productos registrados",
                        style: TextStyle(
                            color: Colors.black45, fontWeight: FontWeight.w300),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final producto = productosFiltrados[index];
                    return Dismissible(
                      key: Key(producto.id?.toString() ?? 'default_key'),
                      direction: DismissDirection.startToEnd,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.only(left: 20),
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text("Eliminar Producto"),
                              content: Text(
                                  "¿Estás seguro de que deseas eliminar este producto?"),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(false);
                                  },
                                  child: Text(
                                    "Cancelar",
                                    style: TextStyle(color: Colors.green),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(true);
                                  },
                                  child: Text(
                                    "Eliminar",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) {
                        _deleteProducto(producto.id!);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            title: Text(producto.nombre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 15)),
                            subtitle: producto.stock <= _umbralStockBajo
                                ? Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded,
                                          size: 16, color: Colors.red.shade600),
                                      SizedBox(width: 4),
                                      Text(
                                        "${producto.marca != null ? '${producto.marca} | ' : ''}"
                                        "\$ ${formatCurrency(producto.precio)} | ",
                                        style: TextStyle(
                                            color: Colors.black54,
                                            fontSize: 13),
                                      ),
                                      Text(
                                        "Stock: ${producto.stock == producto.stock.roundToDouble() ? producto.stock.toInt().toString() : producto.stock.toStringAsFixed(1)}",
                                        style: TextStyle(
                                          color: Colors.red.shade600,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    "${producto.marca != null ? '${producto.marca} | ' : ''}Código: ${producto.codigo} | "
                                    "\$ ${formatCurrency(producto.precio)} | Stock: ${producto.stock == producto.stock.roundToDouble() ? producto.stock.toInt().toString() : producto.stock.toStringAsFixed(1)}",
                                    style: TextStyle(color: Colors.black54),
                                  ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.add_circle_outline,
                                      size: 20, color: Colors.green.shade600),
                                  onPressed: () =>
                                      _mostrarDialogoAgregarStock(producto),
                                  tooltip: "Agregar stock",
                                ),
                                Icon(Icons.chevron_right,
                                    color: Colors.black54),
                              ],
                            ),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EditProductoScreen(producto: producto),
                                ),
                              );
                              _loadProductos();
                            },
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1);
                  },
                  childCount: productosFiltrados.length,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (context) => AddProductoScreen()));
          _loadProductos();
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
