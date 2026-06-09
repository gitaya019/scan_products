import 'package:flutter/material.dart';
import '../utils/formatters.dart';
import 'producto_text_field.dart';

class PrecioField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const PrecioField({
    super.key,
    required this.controller,
    this.validator,
  });

  @override
  State<PrecioField> createState() => _PrecioFieldState();
}

class _PrecioFieldState extends State<PrecioField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && widget.controller.text.isNotEmpty) {
      final value = parseCurrency(widget.controller.text);
      widget.controller.text = formatCurrency(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProductoTextField(
      controller: widget.controller,
      label: "Precio",
      icon: Icons.attach_money_outlined,
      keyboardType: TextInputType.number,
      validator: widget.validator,
      focusNode: _focusNode,
    );
  }
}
