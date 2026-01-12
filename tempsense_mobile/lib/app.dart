import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempsense_mobile/core/theme/app_theme.dart';
import 'package:tempsense_mobile/features/tempsense/data/datasources/mqtt_data_source.dart';
import 'package:tempsense_mobile/features/tempsense/domain/repositories/neck_cooler_repository_impl.dart';
import 'package:tempsense_mobile/features/tempsense/presentation/bloc/neck_cooler_bloc.dart';
import 'package:tempsense_mobile/features/tempsense/presentation/screens/dashboard_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late SharedPreferences _prefs;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = _prefs.getBool('dark_mode') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => NeckCoolerBloc(
            repository: NeckCoolerRepositoryImpl(
              MQTTDataSource(),
            ),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'TempSense',
        theme: _darkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const DashboardScreen(),
      ),
    );
  }
}