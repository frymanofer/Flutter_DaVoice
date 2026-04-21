import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_davoice_example/main.dart';

void main() {
  testWidgets('shows the voice model chooser first', (tester) async {
    await tester.pumpWidget(const DavoiceExampleApp());

    expect(find.text('Choose Voice Model'), findsOneWidget);
    expect(find.text('Lite'), findsOneWidget);
    expect(find.text('Ariana'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
