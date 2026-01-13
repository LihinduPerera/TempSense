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
  final double radiusMeters; // radius in meters
  final String description;

  HeatZone({
    required this.name,
    required this.center,
    required this.radiusMeters,
    this.description = '',
  });
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
    _checkAndRequestLocationPermission();
  }

  Future<void> _checkAndRequestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable location services')));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission permanently denied')));
      return;
    }

    _startPositionStream();
  }

  void _startPositionStream() {
    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
      _mapController.move(LatLng(position.latitude, position.longitude), 13.0);
      _checkProximityToHeatZones();
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
            body: 'You are now in/near ${zone.name}. Higher temperatures expected — stay hydrated!',
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
          _currentPosition == null
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    initialZoom: 13.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
          // Bottom overlay card
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
                            style: TextStyle(color: getHeatIndexColor(heatIndex)),
                          ),
                        ],
                      ),
                    if (_inKnownHeatZone)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Near known heat zone: $_currentZoneName',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentPosition != null) {
            _mapController.move(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 15.0);
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}