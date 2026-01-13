import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:tempsense_mobile/core/notifications/notification_service.dart';
import 'package:tempsense_mobile/core/utils/heat_index_utils.dart';
import 'package:tempsense_mobile/features/tempsense/presentation/bloc/neck_cooler_bloc.dart';

class HeatZone {
  final String name;
  final LatLng center;
  final double radiusMeters;
  final String description;

  HeatZone({
    required this.name,
    required this.center,
    required this.radiusMeters,
    this.description = '',
  });
}

enum LocationStatus {
  initial,
  checking,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  ready,
  error,
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  Position? _currentPosition;
  final MapController _mapController = MapController();
  late StreamSubscription<Position> _positionStream;

  LocationStatus _locationStatus = LocationStatus.initial;

  final List<HeatZone> _heatZones = [
    HeatZone(
      name: 'Kurunegala Urban Area',
      center: const LatLng(7.4818, 80.3609),
      radiusMeters: 8000,
      description: 'Higher urban temperatures',
    ),
    HeatZone(
      name: 'Colombo Metropolitan',
      center: const LatLng(6.9271, 79.8612),
      radiusMeters: 15000,
      description: 'Urban heat island',
    ),
    HeatZone(
      name: 'Anuradhapura Hot Zone',
      center: const LatLng(8.3114, 80.4037),
      radiusMeters: 10000,
    ),
  ];

  bool _inKnownHeatZone = false;
  String _currentZoneName = '';

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    setState(() {
      _locationStatus = LocationStatus.checking;
    });

    // Check if location service is enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationStatus = LocationStatus.serviceDisabled;
      });
      return;
    }

    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationStatus = LocationStatus.permissionDenied;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationStatus = LocationStatus.permissionPermanentlyDenied;
      });
      return;
    }

    // All good – start listening
    setState(() {
      _locationStatus = LocationStatus.ready;
    });
    _startPositionStream();
  }

  void _startPositionStream() {
    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
      _mapController.move(
          LatLng(position.latitude, position.longitude), 13.0);
      _checkProximityToHeatZones();
    }, onError: (error) {
      setState(() {
        _locationStatus = LocationStatus.error;
      });
    });
  }

  void _checkProximityToHeatZones() {
    if (_currentPosition == null) return;

    for (final zone in _heatZones) {
      final double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        zone.center.latitude,
        zone.center.longitude,
      );

      if (distance <= zone.radiusMeters) {
        if (!_inKnownHeatZone || _currentZoneName != zone.name) {
          NotificationService().showNotification(
            id: 10,
            title: 'Entering Known Heat Zone',
            body:
                'You are now in/near ${zone.name}. Higher temperatures expected — stay hydrated!',
          );
        }
        setState(() {
          _inKnownHeatZone = true;
          _currentZoneName = zone.name;
        });
        return;
      }
    }

    setState(() {
      _inKnownHeatZone = false;
      _currentZoneName = '';
    });
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
    // After returning, re-check
    _initializeLocation();
  }

  Future<void> _openAppSettings() async {
    await Geolocator.openAppSettings();
    // After returning, re-check
    _initializeLocation();
  }

  @override
  void dispose() {
    _positionStream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NeckCoolerBloc>().state;
    double heatIndex = 0.0;
    if (state is NeckCoolerConnected) {
      heatIndex = calculateHeatIndex(state.data.temperature, state.data.humidity);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Heat Map & Location'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          if (_locationStatus == LocationStatus.ready && _currentPosition != null)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(
                    _currentPosition!.latitude, _currentPosition!.longitude),
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.tempsense_mobile',
                ),
                CircleLayer(
                  circles: _heatZones
                      .map((zone) => CircleMarker(
                            point: zone.center,
                            radius: zone.radiusMeters,
                            useRadiusInMeter: true,
                            color: Colors.red.withOpacity(0.25),
                            borderColor: Colors.red,
                            borderStrokeWidth: 3.0,
                          ))
                      .toList(),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_currentPosition!.latitude,
                          _currentPosition!.longitude),
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.my_location,
                          color: Colors.blue, size: 40),
                    ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                    TextSourceAttribution('© OpenTopoMap (CC-BY-SA)'),
                  ],
                ),
              ],
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 80,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _getStatusTitle(),
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getStatusMessage(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _getActionButtonCallback(),
                          icon: Icon(_getActionIcon()),
                          label: Text(_getActionButtonText()),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Bottom heat status card (only when location ready)
          if (_locationStatus == LocationStatus.ready)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Current Heat Status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (state is NeckCoolerConnected)
                        Column(
                          children: [
                            Text(
                              'Heat Index: ${heatIndex.toStringAsFixed(1)}°C',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: getHeatIndexColor(heatIndex),
                              ),
                            ),
                            Text(
                              getHeatIndexRiskLevel(heatIndex),
                              style:
                                  TextStyle(color: getHeatIndexColor(heatIndex)),
                            ),
                          ],
                        ),
                      if (_inKnownHeatZone)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Near known heat zone: $_currentZoneName',
                            style: const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _locationStatus == LocationStatus.ready
          ? FloatingActionButton(
              onPressed: () {
                if (_currentPosition != null) {
                  _mapController.move(
                      LatLng(_currentPosition!.latitude,
                          _currentPosition!.longitude),
                      15.0);
                }
              },
              child: const Icon(Icons.my_location),
            )
          : null,
    );
  }

  String _getStatusTitle() {
    switch (_locationStatus) {
      case LocationStatus.checking:
        return 'Checking location settings...';
      case LocationStatus.serviceDisabled:
        return 'Location Services Disabled';
      case LocationStatus.permissionDenied:
        return 'Location Permission Required';
      case LocationStatus.permissionPermanentlyDenied:
        return 'Location Permission Denied';
      case LocationStatus.error:
        return 'Location Error';
      default:
        return 'Preparing map...';
    }
  }

  String _getStatusMessage() {
    switch (_locationStatus) {
      case LocationStatus.checking:
        return 'Please wait while we check your location settings.';
      case LocationStatus.serviceDisabled:
        return 'Please enable location services in your device settings to use the heat map.';
      case LocationStatus.permissionDenied:
        return 'TempSense needs location permission to show your position and nearby heat zones.';
      case LocationStatus.permissionPermanentlyDenied:
        return 'Location permission was permanently denied. Please enable it in app settings.';
      case LocationStatus.error:
        return 'An error occurred while accessing location. Please try again.';
      default:
        return '';
    }
  }

  VoidCallback? _getActionButtonCallback() {
    switch (_locationStatus) {
      case LocationStatus.serviceDisabled:
        return _openLocationSettings;
      case LocationStatus.permissionDenied:
      case LocationStatus.error:
        return _initializeLocation;
      case LocationStatus.permissionPermanentlyDenied:
        return _openAppSettings;
      default:
        return null;
    }
  }

  IconData _getActionIcon() {
    switch (_locationStatus) {
      case LocationStatus.serviceDisabled:
        return Icons.settings;
      case LocationStatus.permissionPermanentlyDenied:
        return Icons.settings_applications;
      default:
        return Icons.refresh;
    }
  }

  String _getActionButtonText() {
    switch (_locationStatus) {
      case LocationStatus.serviceDisabled:
        return 'Open Location Settings';
      case LocationStatus.permissionDenied:
        return 'Grant Permission';
      case LocationStatus.permissionPermanentlyDenied:
        return 'Open App Settings';
      case LocationStatus.error:
        return 'Retry';
      default:
        return 'Retry';
    }
  }
}