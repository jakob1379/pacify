import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pacify/features/cadence_detector/data/services/sensor_service.dart';
import 'package:pacify/features/cadence_detector/presentation/bloc/cadence_bloc.dart';

class CadencePage extends StatelessWidget {
  const CadencePage({super.key});

  // Set to true to use simulated sensor data (for testing without real device)
  static const bool _useSimulation = false;

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('Cadence Detector'),
      ),
      body: BlocBuilder<CadenceBloc, CadenceState>(
        builder: (context, state) {
          if (state is CadenceLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is CadenceError) {
            return Center(child: Text(state.message));
          } else if (state is CadenceLoaded) {
            return _buildVisualization(state);
          }
          return const Center(child: Text('Press the button to start'));
        },
      ),
      floatingActionButton: BlocBuilder<CadenceBloc, CadenceState>(
        builder: (context, state) {
          return FloatingActionButton(
            onPressed: () {
              final bloc = context.read<CadenceBloc>();
              if (state is CadenceLoaded || state is CadenceLoading) {
                bloc.add(StopCadenceDetection());
              } else {
                bloc.add(StartCadenceDetection());
              }
            },
            child: (state is CadenceLoaded || state is CadenceLoading)
                ? const Icon(Icons.stop)
                : const Icon(Icons.play_arrow),
          );
        },
      ),
    );

    return BlocProvider(
      create: (context) => CadenceBloc(
        sensorService: SensorService.create(useSimulation: _useSimulation),
      ),
      child: Platform.isAndroid ? WithForegroundTask(child: scaffold) : scaffold,
    );
  }

  Widget _buildVisualization(CadenceLoaded state) {
    return Column(
      children: [
        // BPM display
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'State: ${state.currentState.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              Text(
                '${state.bpm.toStringAsFixed(1)} BPM',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Time domain chart
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: state.timeSeriesData.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value);
                    }).toList(),
                    isCurved: false,
                    color: Colors.cyan,
                    barWidth: 2,
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true),
                borderData: FlBorderData(show: true),
                minX: 0,
                maxX: state.timeSeriesData.isNotEmpty ? state.timeSeriesData.length - 1.0 : 0,
                minY: state.timeSeriesData.isNotEmpty ? state.timeSeriesData.reduce((a, b) => a < b ? a : b) - 1 : -10,
                maxY: state.timeSeriesData.isNotEmpty ? state.timeSeriesData.reduce((a, b) => a > b ? a : b) + 1 : 10,
              ),
            ),
          ),
        ),
        // Frequency spectrum chart
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: state.frequencyBins.asMap().entries.map((e) {
                      final freqHz = e.value;
                      final amplitude = state.frequencySpectrum[e.key];
                      return FlSpot(freqHz, amplitude);
                    }).toList(),
                    isCurved: false,
                    color: Colors.orange,
                    barWidth: 2,
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true),
                borderData: FlBorderData(show: true),
                minX: state.frequencyBins.isNotEmpty ? state.frequencyBins.first : 0,
                maxX: state.frequencyBins.isNotEmpty ? state.frequencyBins.last : 10,
                minY: state.frequencySpectrum.isNotEmpty ? state.frequencySpectrum.reduce((a, b) => a < b ? a : b) - 1 : 0,
                maxY: state.frequencySpectrum.isNotEmpty ? state.frequencySpectrum.reduce((a, b) => a > b ? a : b) + 1 : 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
