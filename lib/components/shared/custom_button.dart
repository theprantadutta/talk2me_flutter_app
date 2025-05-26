import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const CustomButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 5,
              shadowColor: Colors.blue.withOpacity(0.5),
            ),
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .shimmer(duration: 3000.ms, delay: 4000.ms),
    );
  }
}
