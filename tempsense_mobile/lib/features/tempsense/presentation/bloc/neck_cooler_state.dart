part of 'neck_cooler_bloc.dart';

@immutable
abstract class NeckCoolerState extends Equatable {
  const NeckCoolerState();

  @override
  List<Object> get props => [];
}

class NeckCoolerInitial extends NeckCoolerState {
  const NeckCoolerInitial();
}

class NeckCoolerLoading extends NeckCoolerState {
  const NeckCoolerLoading();
}

class NeckCoolerConnected extends NeckCoolerState {
  final SensorData data;
  final bool isAutoMode;
  const NeckCoolerConnected(this.data, this.isAutoMode);

  @override
  List<Object> get props => [data, isAutoMode];
}

class NeckCoolerError extends NeckCoolerState {
  final String message;
  final DateTime timestamp;
  const NeckCoolerError(this.message, this.timestamp);

  @override
  List<Object> get props => [message, timestamp];
}