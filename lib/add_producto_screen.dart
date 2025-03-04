import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'database_helper.dart';
import 'producto_model.dart';
import 'package:intl/intl.dart'; // Importar el paquete intl

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
  final FocusNode _precioFocusNode =
      FocusNode(); // FocusNode para el campo de precio

  // Función para formatear el valor como moneda COP
  String _formatCurrency(double value) {
    final format =
        NumberFormat.currency(locale: 'es_CO', symbol: '', decimalDigits: 0);
    return format.format(value);
  }

  // Función para desformatear el valor de moneda COP a double
  double _parseCurrency(String value) {
    final cleanedValue = value.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(cleanedValue) ?? 0.0;
  }

  // Función para formatear el precio cuando el campo pierde el foco
  void _formatPrecioOnUnfocus() {
    final doubleValue = _parseCurrency(_precioController.text);
    _precioController.value = TextEditingValue(
      text: _formatCurrency(doubleValue),
      selection:
          TextSelection.collapsed(offset: _formatCurrency(doubleValue).length),
    );
  }

  @override
  void initState() {
    super.initState();
    _precioFocusNode.addListener(() {
      if (!_precioFocusNode.hasFocus) {
        _formatPrecioOnUnfocus(); // Formatear el precio cuando el campo pierde el foco
      }
    });
  }

  @override
  void dispose() {
    _precioFocusNode.dispose(); // Liberar el FocusNode
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    var result = await BarcodeScanner.scan();
    setState(() {
      _codigoController.text = result.rawContent;
    });

    // Verificar si el producto ya existe
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
                final cantidad = int.tryParse(cantidadController.text) ?? 0;
                if (cantidad > 0) {
                  await DatabaseHelper.instance
                      .updateStock(producto.codigo, cantidad);
                  Navigator.pop(context);
                  Navigator.pop(
                      context); // Cerrar la pantalla de agregar producto
                }
              },
              child: Text("Agregar"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveProducto() async {
    if (_formKey.currentState!.validate()) {
      final producto = Producto(
        nombre: _nombreController.text,
        codigo: _codigoController.text,
        categoria: _categoriaController.text,
        precio:
            _parseCurrency(_precioController.text), // Desformatear el precio
        peso: double.parse(_pesoController.text),
        stock: int.parse(_stockController.text),
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextField(
                  controller: _nombreController,
                  label: "Nombre del Producto",
                  icon: Icons.shopping_basket_outlined,
                  validator: (value) =>
                      value!.isEmpty ? "Ingrese un nombre" : null,
                ),
                SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _codigoController,
                        label: "Código de Barras",
                        icon: Icons.barcode_reader,
                        validator: (value) =>
                            value!.isEmpty ? "Ingrese un código" : null,
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.camera_alt_outlined,
                            color: Colors.black54),
                        onPressed: _scanBarcode,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _buildTextField(
                  controller: _categoriaController,
                  label: "Categoría",
                  icon: Icons.category_outlined,
                  validator: (value) =>
                      value!.isEmpty ? "Ingrese una categoría" : null,
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _precioController,
                        label: "Precio",
                        icon: Icons.attach_money_outlined,
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            value!.isEmpty ? "Ingrese un precio" : null,
                        focusNode: _precioFocusNode, // Asignar el FocusNode
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _pesoController,
                        label: "Peso",
                        icon: Icons.scale_outlined,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        validator: (value) =>
                            value!.isEmpty ? "Ingrese un peso" : null,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _buildTextField(
                  controller: _stockController,
                  label: "Stock Inicial",
                  icon: Icons.inventory,
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value!.isEmpty ? "Ingrese un stock inicial" : null,
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saveProducto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "Guardar Producto",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    FocusNode? focusNode, // Parámetro opcional para el FocusNode
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.black54),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        labelStyle: TextStyle(color: Colors.black54),
      ),
      keyboardType: keyboardType,
      validator: validator,
      focusNode: focusNode, // Asignar el FocusNode
    );
  }
}
