part of 'neck_cooler_bloc.dart';

@immutable
abstract class NeckCoolerEvent extends Equatable {
  const NeckCoolerEvent();

  @override
  List<Object> get props => [];
}

class ConnectToDevice extends NeckCoolerEvent {
  const ConnectToDevice();
}

class DisconnectFromDevice extends NeckCoolerEvent {
  const DisconnectFromDevice();
}

class SensorDataUpdated extends NeckCoolerEvent {
  final SensorData data;
  const SensorDataUpdated(this.data);

  @override
  List<Object> get props => [data];
}

class SetFanSpeed extends NeckCoolerEvent {
  final int speed;
  const SetFanSpeed(this.speed);

  @override
  List<Object> get props => [speed];
}

class ToggleAutoMode extends NeckCoolerEvent {
  const ToggleAutoMode();
}

class SetAutoMode extends NeckCoolerEvent {
  final bool autoMode;
  const SetAutoMode(this.autoMode);

  @override
  List<Object> get props => [autoMode];
}

class ConnectionStatusChanged extends NeckCoolerEvent {
  final bool isConnected;
  const ConnectionStatusChanged(this.isConnected);

  @override
  List<Object> get props => [isConnected];
}

class ClearError extends NeckCoolerEvent {
  const ClearError();
}