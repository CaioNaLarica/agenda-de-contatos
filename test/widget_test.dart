import 'dart:io';

import 'package:apk_agenda_bd_local/database/helper/contact_helper.dart';
import 'package:apk_agenda_bd_local/database/model/contact_model.dart';
import 'package:apk_agenda_bd_local/main.dart';
import 'package:apk_agenda_bd_local/view/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test(
    'SQLite retains all fields after closing and reopening the database',
    () async {
      final directory = await Directory.systemTemp.createTemp('agenda-test-');
      final path = '${directory.path}/contactsDB.db';
      Future<Database> open() => databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) => ContactHelper.createTable(db),
        ),
      );
      var helper = ContactHelper.withDatabase(await open());
      try {
        final saved = await helper.saveContact(
          Contact(
            name: "João d'Ávila",
            email: 'joao@example.com',
            phone: '(42) 99999-8888',
            img: '/foto.png',
          ),
        );
        final id = saved.id!;
        await helper.close();
        helper = ContactHelper.withDatabase(await open());
        expect((await helper.getContact(id))!.toMap(), saved.toMap());
        saved.name = 'Maria';
        expect(await helper.updateContact(saved), 1);
        expect((await helper.getAllContacts()).single.name, 'Maria');
        expect(await helper.deleteContact(id), 1);
        expect(await helper.getAllContacts(), isEmpty);
        expect(await helper.getContact(id), isNull);
      } finally {
        await helper.close();
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets('Create, validate, mask, cancel edit, save, sort and delete', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
    );
    await ContactHelper.createTable(db);
    final helper = ContactHelper.withDatabase(db);
    addTearDown(helper.close);
    await tester.pumpWidget(MyApp(helper: helper));
    await tester.pumpAndSettle();
    expect(find.text('Agenda de Contatos'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Novo Contato'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    expect(find.text('Nome é obrigatório!'), findsOneWidget);
    expect(await helper.getAllContacts(), isEmpty);
    await tester.enterText(find.byType(TextField).at(0), 'João da Silva');
    await tester.enterText(find.byType(TextField).at(1), 'joao@example.com');
    await tester.enterText(find.byType(TextField).at(2), '42999998888');
    final field = tester.widget<TextField>(find.byType(TextField).at(2));
    expect(field.controller!.text, '(42) 99999-8888');
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    expect(find.text('João da Silva'), findsOneWidget);
    expect((await helper.getAllContacts()).single.phone, '(42) 99999-8888');
    await tester.tap(find.text('João da Silva'));
    await tester.pumpAndSettle();
    expect(find.text('Ligar'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Excluir'), findsOneWidget);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Alteração descartada',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('João da Silva'), findsOneWidget);
    expect(find.text('Alteração descartada'), findsNothing);
    await tester.tap(find.text('João da Silva'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Zélia');
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    expect(find.text('Zélia'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Ana');
    await tester.enterText(find.byKey(const Key('email')), 'ana@example.com');
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    for (final ascending in [true, false]) {
      await tester.tap(find.byType(PopupMenuButton<OrderOptions>));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(ascending ? 'Ordenar de A-Z' : 'Ordenar de Z-A'),
      );
      await tester.pumpAndSettle();
      final names = tester
          .widgetList<Text>(
            find.descendant(of: find.byType(Card), matching: find.byType(Text)),
          )
          .where((text) => text.style?.fontSize == 22)
          .map((text) => text.data)
          .toList();
      expect(names, ascending ? ['Ana', 'Zélia'] : ['Zélia', 'Ana']);
    }
    await tester.tap(find.text('Zélia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Zélia'), findsNothing);
    expect((await helper.getAllContacts()).single.name, 'Ana');
    expect(tester.takeException(), isNull);
  });
}
