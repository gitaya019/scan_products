import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import '../services/database_helper.dart';
import '../models/producto_model.dart';
import '../models/carrito_item.dart';
import '../utils/formatters.dart';

class VentaScreen extends StatefulWidget {
  @override
  _VentaScreenState createState() => _VentaScreenState();
}

class _VentaScreenState extends State<VentaScreen> {
  final List<CarritoItem> _items = [];

  double get _total => _items.fold(0, (sum, item) => sum + item.subtotal);

  String _labelCantidad(Producto p) {
    if (p.unidadMedida == null) return 'Cantidad';
    final labels = {
      'kg': 'Cantidad (kg)',
      'g': 'Cantidad (g)',
      'lb': 'Cantidad (lb)',
      'L': 'Volumen (L)',
      'mL': 'Volumen (mL)',
    };
    return labels[p.unidadMedida!] ?? 'Cantidad';
  }

  String _formatearCantidad(CarritoItem item) {
    if (item.esPorPeso) {
      final dec = item.cantidad == item.cantidad.roundToDouble()
          ? item.cantidad.toInt().toString()
          : item.cantidad.toStringAsFixed(1);
      return '$dec ${item.producto.unidadMedida}';
    }
    return '${item.cantidad.toInt()}';
  }

  double _incremento(CarritoItem item) => item.esPorPeso ? 0.1 : 1.0;

  Future<void> _scanBarcode() async {
    try {
      var result = await BarcodeScanner.scan();
      String scannedCode = result.rawContent;

      if (scannedCode.isEmpty) return;

      final producto =
          await DatabaseHelper.instance.getProductoByCodigo(scannedCode);

      if (producto == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Producto no encontrado")),
          );
        }
        return;
      }

      final existingIndex =
          _items.indexWhere((item) => item.producto.codigo == producto.codigo);

      if (existingIndex >= 0) {
        setState(() {
          _items[existingIndex].cantidad += _incremento(_items[existingIndex]);
        });
      } else {
        _showQuantityDialog(producto);
      }
    } catch (e) {
      print("Error al escanear: $e");
    }
  }

  Future<void> _showQuantityDialog(Producto producto) async {
    final esPeso = ['kg', 'g', 'lb', 'L', 'mL'].contains(producto.unidadMedida);
    final cantidadController = TextEditingController(text: esPeso ? '1.0' : '1');
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(producto.nombre),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Código: ${producto.codigo}"),
              Text("Precio: \$${formatCurrency(producto.precio)}"),
              if (producto.marca != null) Text("Marca: ${producto.marca}"),
              SizedBox(height: 16),
              TextField(
                controller: cantidadController,
                decoration: InputDecoration(
                  labelText: _labelCantidad(producto),
                  border: OutlineInputBorder(),
                ),
                keyboardType: esPeso
                    ? TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.number,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 0),
              child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                final cant =
                    double.tryParse(cantidadController.text) ?? (esPeso ? 1.0 : 1);
                Navigator.pop(context, cant > 0 ? cant : (esPeso ? 0.1 : 1));
              },
              child: Text("Agregar"),
            ),
          ],
        );
      },
    );

    if (result != null && result > 0) {
      setState(() {
        _items.add(CarritoItem(producto: producto, cantidad: result));
      });
    }
  }

  void _incrementarCantidad(int index) {
    setState(() {
      _items[index].cantidad += _incremento(_items[index]);
    });
  }

  void _decrementarCantidad(int index) {
    setState(() {
      final paso = _incremento(_items[index]);
      if (_items[index].cantidad > paso) {
        _items[index].cantidad -= paso;
      } else {
        _items.removeAt(index);
      }
    });
  }

  Future<void> _finalizarVenta() async {
    if (_items.isEmpty) return;

    for (var item in _items) {
      await DatabaseHelper.instance
          .updateStock(item.producto.codigo, -item.cantidad);
    }

    await DatabaseHelper.instance.addVenta(_total, _items);

    final cantidadItems = _items.length;
    final total = _total;

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Venta Finalizada"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Productos vendidos: $cantidadItems"),
                Text("Total: \$${formatCurrency(total)}"),
                SizedBox(height: 8),
                Text("Stock actualizado correctamente."),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text("Aceptar"),
              ),
            ],
          );
        },
      );

      setState(() {
        _items.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.black54),
        title: Text(
          "Nueva Venta",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w300,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _scanBarcode,
                icon: Icon(Icons.qr_code_scanner, size: 28),
                label: Text(
                  "Escanear Producto",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
          Divider(color: Colors.grey.shade200),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_shopping_cart_outlined,
                            size: 80, color: Colors.black26),
                        SizedBox(height: 16),
                        Text(
                          "Escanee un producto para comenzar",
                          style: TextStyle(
                            color: Colors.black45,
                            fontWeight: FontWeight.w300,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        elevation: 0,
                        color: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.producto.nombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "\$${formatCurrency(item.subtotal)}",
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline),
                                    onPressed: () =>
                                        _decrementarCantidad(index),
                                    color: Colors.black54,
                                  ),
                                  Text(
                                    _formatearCantidad(item),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.add_circle_outline),
                                    onPressed: () =>
                                        _incrementarCantidad(index),
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_items.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Total",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            "\$${formatCurrency(_total)}",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _finalizarVenta,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Finalizar Venta",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
