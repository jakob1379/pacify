import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pacify/features/cadence_detector/presentation/bloc/cadence_bloc.dart';

class CadenceDebugPage extends StatelessWidget {
  const CadenceDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadence Debug')),
      body: BlocBuilder<CadenceBloc, CadenceState>(
        builder: (context, state) {
          if (state is CadenceLoaded) return _DebugBody(state: state);
          if (state is CadenceError) return Center(child: Text(state.message));
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

class _DebugBody extends StatelessWidget {
  const _DebugBody({required this.state});

  final CadenceLoaded state;

  @override
  Widget build(BuildContext context) {
    final motionSpots = state.timeSeriesData
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList();
    final cadenceSpots = List<FlSpot>.generate(
      min(state.frequencyBins.length, state.frequencySpectrum.length),
      (index) =>
          FlSpot(state.frequencyBins[index], state.frequencySpectrum[index]),
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric(
                label: 'Filtered BPM',
                value: state.bpm.toStringAsFixed(1),
              ),
              _Metric(label: 'Raw BPM', value: state.rawBpm.toStringAsFixed(1)),
              _Metric(
                label: 'Confidence',
                value: '${(state.confidence * 100).round()}%',
              ),
              _Metric(
                label: 'Uncertainty',
                value: state.uncertainty.toStringAsFixed(2),
              ),
              _Metric(label: 'Phase', value: state.currentState),
            ],
          ),
          const SizedBox(height: 24),
          _DiagnosticChart(
            title: 'Motion trace',
            emptyMessage: 'Collecting accelerometer samples…',
            spots: motionSpots,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          _DiagnosticChart(
            title: 'AMDF similarity',
            emptyMessage: 'Waiting for a completed sample window…',
            spots: cadenceSpots,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 148,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticChart extends StatelessWidget {
  const _DiagnosticChart({
    required this.title,
    required this.emptyMessage,
    required this.spots,
    required this.color,
  });

  final String title;
  final String emptyMessage;
  final List<FlSpot> spots;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: spots.isEmpty
                ? Center(
                    child: Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : LineChart(_chartData(theme)),
          ),
        ],
      ),
    );
  }

  LineChartData _chartData(ThemeData theme) {
    final firstX = spots.first.x;
    final lastX = spots.last.x;
    var minY = spots.first.y;
    var maxY = spots.first.y;
    for (final spot in spots.skip(1)) {
      minY = min(minY, spot.y);
      maxY = max(maxY, spot.y);
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    return LineChartData(
      minX: firstX,
      maxX: firstX == lastX ? lastX + 1 : lastX,
      minY: minY,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          color: color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ],
      gridData: FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: theme.colorScheme.outlineVariant, strokeWidth: 1),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 44),
        ),
        bottomTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 32),
        ),
      ),
    );
  }
}
