import 'dart:io';

import 'package:flutter/material.dart';

class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.path, required this.size});
  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox(
      width: size,
      height: size,
      child: path != null && path!.isNotEmpty
          ? Image.file(
              File(path!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => _placeholder(),
            )
          : _placeholder(),
    ),
  );

  Widget _placeholder() =>
      Image.asset('assets/imgs/image.png', fit: BoxFit.cover);
}
