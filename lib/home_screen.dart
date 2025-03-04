import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'database_helper.dart';
import 'producto_model.dart';
import 'add_producto_screen.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'edit_producto_screen.dart';
import 'package:intl/intl.dart'; // Importar el paquete intl
import 'sidebar.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Producto> productos = [];
  List<Producto> productosFiltrados = [];
  final _searchController = TextEditingController();
  bool _isSearching = false;

  // Función para formatear el valor como moneda COP
  String _formatCurrency(double value) {
    final format =
        NumberFormat.currency(locale: 'es_CO', symbol: '', decimalDigits: 0);
    return format.format(value);
  }

  Future<void> _loadProductos() async {
    final data = await DatabaseHelper.instance.getProductos();
    setState(() {
      productos = data.map((e) => Producto.fromMap(e)).toList();
      productosFiltrados = productos;
    });
  }

  void _filterProductos(String query) {
    setState(() {
      if (query.isEmpty) {
        productosFiltrados = productos;
        _isSearching = false;
      } else {
        _isSearching = true;
        productosFiltrados = productos.where((producto) {
          return producto.nombre.toLowerCase().contains(query.toLowerCase()) ||
              producto.codigo.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _scanBarcode() async {
    try {
      var result = await BarcodeScanner.scan();
      String scannedCode = result.rawContent;

      if (scannedCode.isNotEmpty) {
        _searchController.text = scannedCode;
        _filterProductos(scannedCode);
      }
    } catch (e) {
      print("Error al escanear: $e");
    }
  }

  Future<void> _deleteProducto(int id) async {
    await DatabaseHelper.instance.deleteProducto(id);
    _loadProductos(); // Recargar la lista después de eliminar
  }

  @override
  void initState() {
    super.initState();
    _loadProductos();
    _searchController.addListener(() {
      _filterProductos(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: Sidebar(onExportExcel: exportToExcel), // Agregar el Sidebar
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
                  icon: Icon(Icons.filter_list_outlined, color: Colors.black54),
                  onPressed: () {
                    // Future filter functionality
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
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
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
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 15, horizontal: 15),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(10),
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
                              : Icons.inventory_2_outlined,
                          size: 80,
                          color: Colors.black26),
                      SizedBox(height: 16),
                      Text(
                        _isSearching
                            ? "No se encontraron productos"
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
                      key: Key(producto.id?.toString() ??
                          'default_key'), // Handle nullable id
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
                        _deleteProducto(producto.id!); // Ensure id is non-null
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text(producto.nombre,
                                style: TextStyle(fontWeight: FontWeight.w500)),
                            subtitle: Text(
                              "Código: ${producto.codigo} | \$ ${_formatCurrency(producto.precio)} | Stock: ${producto.stock}",
                              style: TextStyle(color: Colors.black54),
                            ),
                            trailing: Icon(Icons.chevron_right,
                                color: Colors.black54),
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
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
