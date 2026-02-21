import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/adb/adb_client.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'core/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CheryMasterControllerApp());
}

class CheryMasterControllerApp extends StatelessWidget {
  const CheryMasterControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ADBClient>.value(
      // Singleton — tüm sayfalar aynı instance'ı kullanır,
      // navigation sırasında bağlantı ve root shell kopmaz.
      value: ADBClient(),
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: AppConstants.primaryRed,
            secondary: AppConstants.primaryRedLight,
            surface: AppConstants.surfaceDark,
          ),
          scaffoldBackgroundColor: AppConstants.backgroundDark,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppConstants.primaryRed,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: AppConstants.surfaceDark,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryRed,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}
