import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacify/features/cadence_detector/data/services/sensor_service.dart';
import 'package:pacify/features/cadence_detector/presentation/bloc/cadence_bloc.dart';
import 'package:pacify/features/cadence_detector/presentation/pages/cadence_page.dart';
import 'package:pacify/main.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  const samplingState = CadenceLoaded(
    152.4,
    rawBpm: 151.1,
    uncertainty: 0.84,
    confidence: 0.72,
    currentState: 'sampling',
  );

  testWidgets('sampling dashboard prioritizes pace and monitoring status', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CadenceDashboard(state: samplingState)),
        ),
      );

      expect(find.text('Pacify'), findsOneWidget);
      expect(find.text('Measuring now'), findsOneWidget);
      expect(find.text('152'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
      expect(find.text('Confidence'), findsOneWidget);
      expect(find.text('72%'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Monitoring phase: Measuring now'),
        findsOneWidget,
      );
      expect(
          find.bySemanticsLabel('Pace: 152 beats per minute'), findsOneWidget);
      expect(find.bySemanticsLabel('Confidence: 72 percent'), findsOneWidget);

      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, 0.72);
      expect(find.text('Motion trace'), findsNothing);
      expect(find.text('Tune detector settings'), findsNothing);
      expect(find.text('Adaptive cadence'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('paused dashboard retains pace between samples', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      const pausedState = CadenceLoaded(
        147.6,
        confidence: 0.43,
        currentState: 'paused',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CadenceDashboard(state: pausedState)),
        ),
      );

      expect(find.text('Between samples'), findsOneWidget);
      expect(find.text('Measuring now'), findsNothing);
      expect(find.text('148'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
      expect(find.text('43%'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Monitoring phase: Between samples'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Pace: 148 beats per minute'),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('low-confidence samples do not report a pace', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      const stillState = CadenceLoaded(
        199,
        confidence: 0.09,
        currentState: 'sampling',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CadenceDashboard(state: stillState)),
        ),
      );

      expect(find.text('--'), findsOneWidget);
      expect(find.text('199'), findsNothing);
      expect(find.text('9%'), findsOneWidget);
      expect(find.bySemanticsLabel('Pace unavailable'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('debug settings icon opens the existing diagnostic page', (
    tester,
  ) async {
    final CadenceBloc bloc = _TestCadenceBloc(samplingState);
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: const Scaffold(body: CadenceDashboard(state: samplingState)),
        ),
      ),
    );

    final settingsButton = find.byTooltip('Open detector diagnostics');
    expect(settingsButton, findsOneWidget);
    expect(tester.getSize(settingsButton), const Size(48, 48));

    await tester.tap(settingsButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Cadence Debug'), findsOneWidget);
    expect(find.text('Filtered BPM'), findsOneWidget);
    expect(find.text('152.4'), findsOneWidget);
    expect(find.text('Raw BPM'), findsOneWidget);
    expect(find.text('151.1'), findsOneWidget);
  });

  testWidgets('app provides system-controlled light and dark themes', (
    tester,
  ) async {
    final app = await _appDefinition(tester);

    expect(app.themeMode, ThemeMode.system);
    expect(app.theme?.brightness, Brightness.light);
    expect(app.darkTheme?.brightness, Brightness.dark);

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: app.theme,
          darkTheme: app.darkTheme,
          themeMode: mode,
          home: const Scaffold(body: CadenceDashboard(state: samplingState)),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(CadenceDashboard));
      expect(
        Theme.of(context).brightness,
        mode == ThemeMode.light ? Brightness.light : Brightness.dark,
      );
      expect(find.text('152'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('dashboard avoids overflow on narrow and landscape viewports', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(body: CadenceDashboard(state: samplingState)),
        ),
      );
      await tester.pump();

      expect(find.text('Pacify'), findsOneWidget);
      expect(find.text('152'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

Future<MaterialApp> _appDefinition(WidgetTester tester) async {
  late MaterialApp app;
  await tester.pumpWidget(
    Builder(
      builder: (context) {
        app = const MyApp().build(context) as MaterialApp;
        return const SizedBox.shrink();
      },
    ),
  );
  return app;
}

class _TestCadenceBloc extends CadenceBloc {
  _TestCadenceBloc(CadenceState state)
      : super(sensorService: _FakeSensorService()) {
    emit(state);
  }
}

class _FakeSensorService implements SensorService {
  @override
  Stream<AccelerometerEvent> get accelerometerStream => const Stream.empty();

  @override
  Future<void> startListening() async {}

  @override
  void stopListening() {}
}
