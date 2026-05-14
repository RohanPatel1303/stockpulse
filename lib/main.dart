import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async{
  WidgetsFlutterBinding .ensureInitialized();
  await Supabase.initialize(
    url: 'https://your-supabase-url.supabase.co',
    anonKey: 'your-anon-key',
  );
  runApp(const StockPulseApp();
}
final supabase = Supabase.instance.client;

class StockPulseApp extends StatelessWidget {
  const StockPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(providers: [
      ChangeNotifierProvider(create: (_)=>AuthProvider());
    ChangeNotifierProvider(create: (_)=>InventoryProvider()),
    ],
    child:MaterialApp.router(
      title: 'StockPulse',
      debugShowCheckedModeBanner: false,
      theme:AppTheme.light,
      themeMode: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
    )
    );
  }
}
