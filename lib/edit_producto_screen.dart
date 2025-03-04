import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'producto_model.dart';
import 'package:intl/intl.dart';

class EditProductoScreen extends StatefulWidget {
  final Producto producto;

  EditProductoScreen({required this.producto});

  @override
  _EditProductoScreenState createState() => _EditProductoScreenState();
}

class _EditProductoScreenState extends State<EditProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _codigoController = TextEditingController();
  final _categoriaController = TextEditingController();
  final _precioController = TextEditingController();
  final _pesoController = TextEditingController();
  final _stockController = TextEditingController();

  // Formateador de moneda
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CO', // Cambia el locale según tu región
    symbol: '\$', // Símbolo de la moneda
    decimalDigits: 0, // Número de decimales
  );

  @override
  void initState() {
    super.initState();
    // Inicializa los controladores con los datos del producto
    _nombreController.text = widget.producto.nombre;
    _codigoController.text = widget.producto.codigo;
    _categoriaController.text = widget.producto.categoria;
    _precioController.text =
        _currencyFormat.format(widget.producto.precio); // Formatear precio
    _pesoController.text = widget.producto.peso.toString();
    _stockController.text = widget.producto.stock.toString();
  }

  Future<void> _updateProducto() async {
    if (_formKey.currentState!.validate()) {
      // Convertir el precio formateado a double
      final precio = _currencyFormat
          .parse(_precioController.text.replaceAll('\$', '').trim());

      final producto = Producto(
        id: widget.producto.id,
        nombre: _nombreController.text,
        codigo: _codigoController.text,
        categoria: _categoriaController.text,
        precio: precio.toDouble(),
        peso: double.parse(_pesoController.text),
        stock: int.parse(_stockController.text),
      );

      await DatabaseHelper.instance.updateProducto(producto.toMap());
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
          "Editar Producto",
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
                _buildTextField(
                  controller: _codigoController,
                  label: "Código de Barras",
                  icon: Icons.barcode_reader,
                  validator: (value) =>
                      value!.isEmpty ? "Ingrese un código" : null,
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
                      child: _buildCurrencyTextField(
                        controller: _precioController,
                        label: "Precio",
                        icon: Icons.attach_money_outlined,
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
                SizedBox(height: 16),
                _buildTextField(
                  controller: _stockController,
                  label: "Stock",
                  icon: Icons.inventory,
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value!.isEmpty ? "Ingrese un stock" : null,
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _updateProducto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "Guardar Cambios",
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

  Widget _buildCurrencyTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
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
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      validator: validator,
      onChanged: (value) {
        // Formatear el valor mientras el usuario escribe
        if (value.isNotEmpty) {
          final parsedValue =
              double.tryParse(value.replaceAll('\$', '').replaceAll(',', '')) ??
                  0.0;
          controller.value = TextEditingValue(
            text: _currencyFormat.format(parsedValue),
            selection: TextSelection.collapsed(
                offset: _currencyFormat.format(parsedValue).length),
          );
        }
      },
    );
  }
}
