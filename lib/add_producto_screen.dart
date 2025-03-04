import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'database_helper.dart';
import 'producto_model.dart';

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

  Future<void> _scanBarcode() async {
    var result = await BarcodeScanner.scan();
    setState(() {
      _codigoController.text = result.rawContent;
    });
  }

  Future<void> _saveProducto() async {
    if (_formKey.currentState!.validate()) {
      final producto = Producto(
        nombre: _nombreController.text,
        codigo: _codigoController.text,
        categoria: _categoriaController.text,
        precio: double.parse(_precioController.text),
        peso: double.parse(_pesoController.text),
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
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        validator: (value) =>
                            value!.isEmpty ? "Ingrese un precio" : null,
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
    );
  }
}
