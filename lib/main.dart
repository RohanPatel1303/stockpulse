import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stockpulse/providers/auth_provider.dart';
import 'package:stockpulse/providers/inventory_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router.dart';
import 'core/theme.dart';

void main() async{
  WidgetsFlutterBinding .ensureInitialized();
  await Supabase.initialize(
    url: 'https://mzeshmhwjpfzzjbpdwlf.supabase.co',
    anonKey: 'sb_publishable_ftbhqIPs08IwRbvM4XWniA_O0X9vEkC',
  );
  runApp(const StockPulseApp(),
  );
}
final supabase = Supabase.instance.client;

class StockPulseApp extends StatelessWidget {
  const StockPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(providers: [
      ChangeNotifierProvider(create: (_)=>AuthProvider()),
    ChangeNotifierProvider(create: (_)=>InventoryProvider()),
    ],
    child:MaterialApp.router(
      title: 'StockPulse',
      debugShowCheckedModeBanner: false,
      theme:AppTheme.light,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
    )
    );
  }
}
