import 'package:flutter/material.dart';

/// Small top-right control that shows when this build was made.
class KernelBuildButton extends StatelessWidget {
  const KernelBuildButton({super.key});

  static const buildDate = String.fromEnvironment(
    'BUILD_DATE',
    defaultValue: 'dev',
  );

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Build date: $buildDate')),
        );
      },
      child: const Text('Kernel'),
    );
  }
}
