import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:tempsense_mobile/features/tempsense/domain/entities/sensor_data.dart';
import 'package:tempsense_mobile/features/tempsense/domain/repositories/neck_cooler_repository.dart';

part 'neck_cooler_event.dart';
part 'neck_cooler_state.dart';

class NeckCoolerBloc extends Bloc<NeckCoolerEvent, NeckCoolerState> {
  final NeckCoolerRepository repository;
  StreamSubscription<SensorData>? _dataSubscription;
  StreamSubscription? _connectionSubscription;

  NeckCoolerBloc({required this.repository}) : super(const NeckCoolerInitial()) {
    on<ConnectToDevice>(_onConnectToDevice);
    on<DisconnectFromDevice>(_onDisconnectFromDevice);
    on<SensorDataUpdated>(_onSensorDataUpdated);
    on<SetFanSpeed>(_onSetFanSpeed);
    on<ToggleAutoMode>(_onToggleAutoMode);
    on<SetAutoMode>(_onSetAutoMode);
    on<ConnectionStatusChanged>(_onConnectionStatusChanged);
    on<ClearError>(_onClearError);
  }

  void _onConnectToDevice(ConnectToDevice event, Emitter<NeckCoolerState> emit) async {
    emit(const NeckCoolerLoading());
    
    try {
      await repository.connect();
      
      _dataSubscription?.cancel();
      _dataSubscription = repository.sensorStream.listen(
        (data) {
          add(SensorDataUpdated(data));
        },
        onError: (error) {
          add(ConnectionStatusChanged(false));
        },
      );
      
      // Initial state with empty data
      add(SensorDataUpdated(SensorData.empty().copyWith(
        isConnected: true,
        autoMode: true,
      )));
      
    } catch (e) {
      emit(NeckCoolerError(
        'Failed to connect: ${e.toString()}',
        DateTime.now(),
      ));
    }
  }

  void _onDisconnectFromDevice(DisconnectFromDevice event, Emitter<NeckCoolerState> emit) async {
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    await repository.disconnect();
    emit(const NeckCoolerInitial());
  }

  void _onSensorDataUpdated(SensorDataUpdated event, Emitter<NeckCoolerState> emit) {
    if (state is NeckCoolerError) {
      emit(NeckCoolerConnected(event.data, event.data.autoMode));
    } else {
      emit(NeckCoolerConnected(event.data, event.data.autoMode));
    }
  }

  void _onSetFanSpeed(SetFanSpeed event, Emitter<NeckCoolerState> emit) async {
    try {
      await repository.setFanSpeed(event.speed);
      
      if (state is NeckCoolerConnected) {
        final currentState = state as NeckCoolerConnected;
        emit(NeckCoolerConnected(
          currentState.data.copyWith(
            fanSpeed: event.speed,
            autoMode: false,
          ),
          false,
        ));
      }
    } catch (e) {
      emit(NeckCoolerError(
        'Failed to set fan speed: ${e.toString()}',
        DateTime.now(),
      ));
    }
  }

  void _onToggleAutoMode(ToggleAutoMode event, Emitter<NeckCoolerState> emit) async {
    if (state is NeckCoolerConnected) {
      final currentState = state as NeckCoolerConnected;
      final newAutoMode = !currentState.isAutoMode;
      
      try {
        await repository.setAutoMode(newAutoMode);
        emit(NeckCoolerConnected(
          currentState.data.copyWith(autoMode: newAutoMode),
          newAutoMode,
        ));
      } catch (e) {
        emit(NeckCoolerError(
          'Failed to toggle auto mode: ${e.toString()}',
          DateTime.now(),
        ));
      }
    }
  }

  void _onSetAutoMode(SetAutoMode event, Emitter<NeckCoolerState> emit) async {
    if (state is NeckCoolerConnected) {
      final currentState = state as NeckCoolerConnected;
      
      try {
        await repository.setAutoMode(event.autoMode);
        emit(NeckCoolerConnected(
          currentState.data.copyWith(autoMode: event.autoMode),
          event.autoMode,
        ));
      } catch (e) {
        emit(NeckCoolerError(
          'Failed to set auto mode: ${e.toString()}',
          DateTime.now(),
        ));
      }
    }
  }

  void _onConnectionStatusChanged(
    ConnectionStatusChanged event,
    Emitter<NeckCoolerState> emit,
  ) {
    if (state is NeckCoolerConnected) {
      final currentState = state as NeckCoolerConnected;
      emit(NeckCoolerConnected(
        currentState.data.copyWith(isConnected: event.isConnected),
        currentState.isAutoMode,
      ));
    }
  }

  void _onClearError(ClearError event, Emitter<NeckCoolerState> emit) {
    if (state is NeckCoolerConnected) {
      emit(state);
    } else {
      emit(const NeckCoolerInitial());
    }
  }

  @override
  Future<void> close() {
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    return super.close();
  }
}