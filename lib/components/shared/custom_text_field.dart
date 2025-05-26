import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool obscureText;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;

  const CustomTextField({
    super.key,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.onSuffixIconPressed,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _isObscured = false;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        obscureText: _isObscured,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          border: InputBorder.none,
          hintText: widget.label,
          prefixIcon: Icon(widget.icon, color: Colors.blue),
          suffixIcon: _buildSuffixIcon(),
        ),
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.obscureText) {
      return IconButton(
        icon: Icon(
          _isObscured ? Icons.visibility_off : Icons.visibility,
          color: Colors.grey,
        ),
        onPressed: () {
          setState(() {
            _isObscured = !_isObscured;
          });
        },
      );
    } else if (widget.suffixIcon != null) {
      return IconButton(
        icon: Icon(widget.suffixIcon, color: Colors.grey),
        onPressed: widget.onSuffixIconPressed,
      );
    }
    return null;
  }
}
