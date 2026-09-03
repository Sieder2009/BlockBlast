import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:block_blast/main.dart';

void main() {
  testWidgets('renders the board and score labels', (WidgetTester tester) async {
    await tester.pumpWidget(const BlockBlastApp());
    await tester.pump();

    expect(find.text('PUNKTE'), findsOneWidget);
    expect(find.text('REKORD'), findsOneWidget);
    expect(find.byType(GestureDetector), findsWidgets);
  });
}
