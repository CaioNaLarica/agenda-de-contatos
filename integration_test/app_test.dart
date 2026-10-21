import 'dart:io';
import 'dart:ui' as ui;

import 'package:apk_agenda_bd_local/database/helper/contact_helper.dart';
import 'package:apk_agenda_bd_local/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Native Linux: create, edit, restart and delete with real SQLite',
    (tester) async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'agenda-native-test-',
      );
      final path = '${directory.path}/contactsDB.db';
      Future<ContactHelper> open() async => ContactHelper.withDatabase(
        await databaseFactoryFfiNoIsolate.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: ContactHelper.schemaVersion,
            onCreate: (db, version) => ContactHelper.createTable(db),
            onUpgrade: ContactHelper.upgradeDatabase,
          ),
        ),
      );
      var helper = await open();
      final captureKey = GlobalKey();
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = Directory(
          '${Directory.current.path}/output/verification',
        );
        await output.create(recursive: true);
        await File('${output.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      }

      Future<void> showApp() async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: captureKey,
            child: MyApp(helper: helper),
          ),
        );
        await tester.pumpAndSettle();
      }

      try {
        await showApp();
        await capture('linux-home');
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await capture('linux-novo-contato');
        await tester.enterText(find.byType(TextField).at(0), 'João da Silva');
        await tester.enterText(
          find.byType(TextField).at(1),
          'JSilva@email.com',
        );
        await tester.enterText(find.byType(TextField).at(2), '42999999999');
        await tester.ensureVisible(find.byKey(const Key('cep')));
        await tester.enterText(find.byKey(const Key('cep')), '01001000');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('city')))
              .controller!
              .text,
          'São Paulo',
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('uf')))
              .controller!
              .text,
          'SP',
        );
        await tester.ensureVisible(find.byKey(const Key('number')));
        await tester.enterText(find.byKey(const Key('number')), '123A');
        await tester.enterText(find.byKey(const Key('complement')), 'Apto 4');
        await capture('linux-endereco');
        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();
        expect(find.text('João da Silva'), findsOneWidget);
        expect(find.text('(42) 99999-9999'), findsOneWidget);
        await capture('linux-contato-salvo');
        await tester.tap(find.text('João da Silva'));
        await tester.pumpAndSettle();
        await capture('linux-opcoes');
        await tester.tap(find.text('Editar'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).first,
          'João da Silva atualizado',
        );
        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await helper.close();
        helper = await open();
        await showApp();
        expect(find.text('João da Silva atualizado'), findsOneWidget);
        final persisted = (await helper.getAllContacts()).single;
        expect(persisted.street, 'Praça da Sé');
        expect(persisted.cep, '01001-000');
        expect(persisted.number, '123A');
        expect(persisted.complement, 'Apto 4');
        expect(persisted.email, 'JSilva@email.com');
        await tester.tap(find.text('João da Silva atualizado'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Excluir'));
        await tester.pumpAndSettle();
        expect(find.byType(Card), findsNothing);
        expect(await helper.getAllContacts(), isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await helper.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
