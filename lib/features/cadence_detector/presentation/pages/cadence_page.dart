import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pacify/features/cadence_detector/data/services/sensor_service.dart';
import 'package:pacify/features/cadence_detector/presentation/bloc/cadence_bloc.dart';
import 'package:pacify/features/cadence_detector/presentation/pages/cadence_debug_page.dart';

class CadencePage extends StatelessWidget {
  const CadencePage({super.key});

  // Set to true to use simulated sensor data (for testing without real device).
  static const bool _useSimulation = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        return CadenceBloc(
          sensorService: SensorService.create(useSimulation: _useSimulation),
        )..add(StartCadenceDetection());
      },
      child: const _CadencePageContent(),
    );
  }
}

class _CadencePageContent extends StatelessWidget {
  const _CadencePageContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<CadenceBloc, CadenceState>(
        builder: (context, state) {
          if (state is CadenceError) {
            return _CadenceErrorView(message: state.message);
          }
          if (state is CadenceLoaded) {
            return CadenceDashboard(state: state);
          }

          return const _LoadingCadenceView();
        },
      ),
    );
  }
}

class CadenceDashboard extends StatelessWidget {
  const CadenceDashboard({super.key, required this.state});

  final CadenceLoaded state;

  @override
  Widget build(BuildContext context) {
    final isSampling = state.currentState == 'sampling';
    final confidence = (state.confidence.clamp(0.0, 1.0) * 100).round();
    final pace = state.hasReliableCadence ? state.bpm.toStringAsFixed(0) : '--';

    return _CadenceShell(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MonitoringStatus(isSampling: isSampling),
          const SizedBox(height: 24),
          _PaceBlock(pace: pace),
          const SizedBox(height: 24),
          _Confidence(value: confidence),
        ],
      ),
    );
  }
}

class _CadenceShell extends StatelessWidget {
  const _CadenceShell({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 360 ? 16.0 : 24.0;
            final headerGap = constraints.maxHeight < 500 ? 20.0 : 40.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Header(),
                      SizedBox(height: headerGap),
                      body,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Pacify',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
        ),
        if (kDebugMode)
          SizedBox.square(
            dimension: 48,
            child: IconButton(
              tooltip: 'Open detector diagnostics',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                final bloc = context.read<CadenceBloc>();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => BlocProvider.value(
                      value: bloc,
                      child: const CadenceDebugPage(),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _MonitoringStatus extends StatelessWidget {
  const _MonitoringStatus({required this.isSampling});

  final bool isSampling;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = isSampling ? 'Measuring now' : 'Between samples';
    final color = isSampling ? colors.tertiary : colors.secondary;

    return Semantics(
      label: 'Monitoring phase: $label',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSampling ? Icons.sensors : Icons.schedule,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaceBlock extends StatelessWidget {
  const _PaceBlock({required this.pace});

  final String pace;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: pace == '--' ? 'Pace unavailable' : 'Pace: $pace beats per minute',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                pace,
                maxLines: 1,
                style: textTheme.displayLarge?.copyWith(
                  color: colors.onPrimary,
                  fontSize: 88,
                  fontWeight: FontWeight.w700,
                  height: 0.95,
                  letterSpacing: -2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'BPM',
              style: textTheme.labelLarge?.copyWith(
                color: colors.onPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Confidence extends StatelessWidget {
  const _Confidence({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: 'Confidence: $value percent',
      excludeSemantics: true,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Confidence',
                  style: textTheme.titleSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$value%',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: value / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: colors.primary,
            backgroundColor: colors.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}

class _LoadingCadenceView extends StatelessWidget {
  const _LoadingCadenceView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return _CadenceShell(
      body: Semantics(
        label: 'Loading: Starting pace monitoring',
        liveRegion: true,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Starting pace monitoring',
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Preparing the motion sensor…',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CadenceErrorView extends StatelessWidget {
  const _CadenceErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return _CadenceShell(
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Semantics(
              label: 'Error: $message',
              liveRegion: true,
              excludeSemantics: true,
              child: Column(
                children: [
                  Icon(Icons.error_outline, color: colors.error, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    'Monitoring unavailable',
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                context.read<CadenceBloc>().add(StartCadenceDetection());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
