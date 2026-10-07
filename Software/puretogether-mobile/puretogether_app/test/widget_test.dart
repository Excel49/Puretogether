import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puretogether_app/providers/provider.dart';
import 'package:puretogether_app/providers/robot_provider.dart';
import 'package:puretogether_app/widgets/main_scaffold.dart';

void main() {
  testWidgets('MainScaffold loads and displays Home/Dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => RobotProvider(),
        child: const MaterialApp(
          home: MainScaffold(),
        ),
      ),
    );

    expect(find.byType(MainScaffold), findsOneWidget);
    expect(find.text('PureTogether'), findsOneWidget);
    expect(find.text('Air Quality Robot Monitor'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });
}
