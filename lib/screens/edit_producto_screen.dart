import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../models/producto_model.dart';
import '../widgets/producto_text_field.dart';
import '../widgets/precio_field.dart';
import '../utils/formatters.dart';

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
  final _marcaController = TextEditingController();

  late String _unidadMedida;
  late String _iva;

  final _unidades = ['kg', 'g', 'lb', 'L', 'mL', 'unidad', 'paquete', 'caja'];
  final _ivas = ['0', '5', '19'];

  @override
  void initState() {
    super.initState();
    _nombreController.text = widget.producto.nombre;
    _codigoController.text = widget.producto.codigo;
    _categoriaController.text = widget.producto.categoria;
    _precioController.text = formatCurrency(widget.producto.precio);
    _pesoController.text = widget.producto.peso.toString();
    _stockController.text = widget.producto.stock.toString();
    _marcaController.text = widget.producto.marca ?? '';
    _unidadMedida = widget.producto.unidadMedida ?? _unidades.first;
    _iva = widget.producto.iva.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _codigoController.dispose();
    _categoriaController.dispose();
    _precioController.dispose();
    _pesoController.dispose();
    _stockController.dispose();
    _marcaController.dispose();
    super.dispose();
  }

  Future<void> _updateProducto() async {
    if (_formKey.currentState!.validate()) {
      final producto = Producto(
        id: widget.producto.id,
        nombre: _nombreController.text,
        codigo: _codigoController.text,
        categoria: _categoriaController.text,
        precio: parseCurrency(_precioController.text),
        peso: double.parse(_pesoController.text),
        stock: int.parse(_stockController.text),
        marca: _marcaController.text.isEmpty ? null : _marcaController.text,
        unidadMedida: _unidadMedida,
        iva: double.parse(_iva),
      );

      await DatabaseHelper.instance.updateProducto(producto.toMap());
      Navigator.pop(context);
    }
  }

  Future<void> _deleteProducto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Producto"),
        content: const Text("¿Estás seguro de que deseas eliminar este producto?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.green)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && widget.producto.id != null) {
      await DatabaseHelper.instance.deleteProducto(widget.producto.id!);
      Navigator.pop(context);
    }
  }

  Widget _buildDropdown(String label, IconData icon, String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.black54),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        labelStyle: const TextStyle(color: Colors.black54),
      ),
      items: items.map((v) {
        return DropdownMenuItem(
          value: v,
          child: Text(label == "IVA %" ? "$v%" : v),
        );
      }).toList(),
      onChanged: onChanged,
    );
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
                ProductoTextField(
                  controller: _nombreController,
                  label: "Nombre del Producto",
                  icon: Icons.shopping_basket_outlined,
                  validator: (value) =>
                      value!.isEmpty ? "Ingrese un nombre" : null,
                ),
                SizedBox(height: 16),
                ProductoTextField(
                  controller: _codigoController,
                  label: "Código de Barras",
                  icon: Icons.barcode_reader,
                  validator: (value) =>
                      value!.isEmpty ? "Ingrese un código" : null,
                ),
                SizedBox(height: 16),
                ProductoTextField(
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
                      child: ProductoTextField(
                        controller: _marcaController,
                        label: "Marca",
                        icon: Icons.branding_watermark_outlined,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdown(
                        "Unidad", Icons.scale_outlined,
                        _unidadMedida, _unidades, (v) {
                          if (v != null) setState(() => _unidadMedida = v);
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: PrecioField(
                        controller: _precioController,
                        validator: (value) =>
                            value!.isEmpty ? "Ingrese un precio" : null,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ProductoTextField(
                        controller: _pesoController,
                        label: "Peso",
                        icon: Icons.monitor_weight_outlined,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        validator: (value) =>
                            value!.isEmpty ? "Ingrese un peso" : null,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ProductoTextField(
                        controller: _stockController,
                        label: "Stock",
                        icon: Icons.inventory,
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            value!.isEmpty ? "Ingrese un stock" : null,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdown(
                        "IVA %", Icons.receipt_long_outlined,
                        _iva, _ivas, (v) {
                          if (v != null) setState(() => _iva = v);
                        },
                      ),
                    ),
                  ],
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
                SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _deleteProducto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "Eliminar Producto",
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
}
