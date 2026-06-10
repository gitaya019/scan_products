import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import '../services/database_helper.dart';
import '../models/producto_model.dart';
import '../widgets/producto_text_field.dart';
import '../widgets/precio_field.dart';
import '../utils/formatters.dart';

class AddProductoScreen extends StatefulWidget {
  @override
  _AddProductoScreenState createState() => _AddProductoScreenState();
}

class _AddProductoScreenState extends State<AddProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _codigoController = TextEditingController();
  final _categoriaController = TextEditingController();
  final _precioController = TextEditingController();
  final _pesoController = TextEditingController();
  final _stockController = TextEditingController();
  final _marcaController = TextEditingController();

  bool _ventaPorPeso = false;
  String _unidadMedida = 'unidad';
  final _ivaController = TextEditingController();

  final _unidades = ['kg', 'g', 'lb', 'L', 'mL', 'unidad', 'paquete', 'caja'];


  @override
  void dispose() {
    _nombreController.dispose();
    _codigoController.dispose();
    _categoriaController.dispose();
    _precioController.dispose();
    _pesoController.dispose();
    _stockController.dispose();
    _marcaController.dispose();
    _ivaController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    var result = await BarcodeScanner.scan();
    setState(() {
      _codigoController.text = result.rawContent;
    });

    final productoExistente =
        await DatabaseHelper.instance.getProductoByCodigo(result.rawContent);
    if (productoExistente != null) {
      _showUpdateStockDialog(productoExistente);
    }
  }

  Future<void> _showUpdateStockDialog(Producto producto) async {
    final cantidadController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Producto Existente"),
          content: TextField(
            controller: cantidadController,
            decoration: InputDecoration(labelText: "Cantidad a agregar"),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Cancelar"),
            ),
            TextButton(
              onPressed: () async {
                final cantidad = double.tryParse(cantidadController.text) ?? 0.0;
                if (cantidad > 0) {
                  await DatabaseHelper.instance
                      .updateStock(producto.codigo, cantidad, id: producto.id);
                  Navigator.pop(context);
                  Navigator.pop(context);
                }
              },
              child: Text("Agregar"),
            ),
          ],
        );
      },
    );
  }

  String _pesoLabel() {
    switch (_unidadMedida) {
      case 'kg':
        return 'Peso (kg)';
      case 'g':
        return 'Peso (g)';
      case 'lb':
        return 'Peso (lb)';
      case 'L':
        return 'Volumen (L)';
      case 'mL':
        return 'Volumen (mL)';
      default:
        return 'Cantidad';
    }
  }

  String _stockLabel() {
    if (_ventaPorPeso) return 'Stock ($_unidadMedida)';
    return 'Stock (unidades)';
  }

  IconData _pesoIcon() {
    switch (_unidadMedida) {
      case 'L':
      case 'mL':
        return Icons.water_drop_outlined;
      case 'unidad':
      case 'paquete':
      case 'caja':
        return Icons.inventory_2_outlined;
      default:
        return Icons.monitor_weight_outlined;
    }
  }
  Widget _seccionHeader(String titulo) {
    return Text(
      titulo,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }

  Future<void> _saveProducto() async {
    if (_formKey.currentState!.validate()) {
      final producto = Producto(
        nombre: _nombreController.text,
        codigo: _codigoController.text,
        categoria: _categoriaController.text,
        precio: parseCurrency(_precioController.text),
        peso: double.parse(_pesoController.text),
        stock: double.parse(_stockController.text),
        marca: _marcaController.text.isEmpty ? null : _marcaController.text,
        unidadMedida: _unidadMedida,
        iva: double.tryParse(_ivaController.text) ?? 0.0,
        ventaPorPeso: _ventaPorPeso,
      );

      await DatabaseHelper.instance.addProducto(producto.toMap());
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "Agregar Producto",
          style: TextStyle(
              color: Colors.black87, fontWeight: FontWeight.w300, fontSize: 22),
        ),
        iconTheme: IconThemeData(color: Colors.black54),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _seccionHeader("Información del Producto"),
                SizedBox(height: 12),
                ProductoTextField(
                  controller: _nombreController,
                  label: "Nombre del Producto",
                  icon: Icons.shopping_basket_outlined,
                  validator: (value) =>
                      value!.isEmpty ? "Ingrese un nombre" : null,
                ),
                SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ProductoTextField(
                        controller: _codigoController,
                        label: "Código de Barras (opcional)",
                        icon: Icons.barcode_reader,
                      ),
                    ),
                    SizedBox(width: 10),
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
                        icon: Icon(Icons.camera_alt_outlined,
                            color: Colors.black54),
                        onPressed: _scanBarcode,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                ProductoTextField(
                  controller: _categoriaController,
                  label: "Categoría",
                  icon: Icons.category_outlined,
                  validator: (value) =>
                      value!.isEmpty ? "Ingrese una categoría" : null,
                ),
                SizedBox(height: 24),
                _seccionHeader("Detalles del Producto"),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ProductoTextField(
                        controller: _marcaController,
                        label: "Marca",
                        icon: Icons.branding_watermark_outlined,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _unidadMedida,
                        decoration: InputDecoration(
                          labelText: "Unidad",
                          prefixIcon: Icon(Icons.scale_outlined,
                              color: Colors.black54),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 16, horizontal: 16),
                          labelStyle: TextStyle(color: Colors.black54),
                        ),
                        items: _unidades.map((u) {
                          return DropdownMenuItem(
                            value: u,
                            child: Text(u),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _unidadMedida = v);
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: SwitchListTile(
                    title: const Text("Vender por peso",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      _ventaPorPeso
                          ? "Se vende en $_unidadMedida (decimal)"
                          : "Se vende por unidad (entero)",
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    value: _ventaPorPeso,
                    onChanged: (v) => setState(() => _ventaPorPeso = v),
                    secondary: Icon(
                      _ventaPorPeso ? Icons.scale : Icons.inventory_2_outlined,
                      color: Colors.black54,
                    ),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(height: 24),
                _seccionHeader("Precio y Stock"),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: PrecioField(
                        controller: _precioController,
                        validator: (value) =>
                            value!.isEmpty ? "Ingrese un precio" : null,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: ProductoTextField(
                        controller: _pesoController,
                        label: _pesoLabel(),
                        icon: _pesoIcon(),
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        validator: (value) =>
                            value!.isEmpty ? "Ingrese un peso" : null,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ProductoTextField(
                        controller: _stockController,
                        label: _stockLabel(),
                        icon: Icons.inventory,
                        keyboardType: TextInputType.numberWithOptions(decimal: _ventaPorPeso),
                        validator: (value) =>
                            value!.isEmpty ? "Ingrese un stock" : null,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: ProductoTextField(
                        controller: _ivaController,
                        label: "IVA",
                        icon: Icons.receipt_long_outlined,
                        keyboardType: TextInputType.number,
                        suffixText: "%",
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saveProducto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    "Guardar Producto",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500),
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
