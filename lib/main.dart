import 'package:flutter/material.dart';

import 'database/helper/contact_helper.dart';
import 'database/model/contact_model.dart';
import 'services/contact_photo_service.dart';
import 'view/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDatabasePlatform();
  Contact? recoveredContact;
  String? recoveryError;
  try {
    recoveredContact = await ContactPhotoService().recover();
  } catch (_) {
    recoveryError =
        'Não foi possível recuperar a foto. Abra o contato e tente novamente.';
  }
  runApp(
    MyApp(recoveredContact: recoveredContact, recoveryError: recoveryError),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.helper,
    this.recoveredContact,
    this.recoveryError,
  });
  final ContactHelper? helper;
  final Contact? recoveredContact;
  final String? recoveryError;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Agenda de Contatos',
    debugShowCheckedModeBanner: false,
    home: HomePage(
      helper: helper,
      recoveredContact: recoveredContact,
      recoveryError: recoveryError,
    ),
  );
}
