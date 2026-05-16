import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:stockpulse/main.dart';
import 'package:stockpulse/screens/dashboard/dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../activity/activity_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup.dart';
import '../screens/inventory/add_item_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/inventory/item_detail_screen.dart';
import '../screens/scanner/scanner_screen.dart';

final appRouter=GoRouter(
  initialLocation: '/dashboard',

  //redirect logic - check auth on every route.
  redirect :(context,state){
    final isLoggedIn=supabase.auth.currentUser!=null;
    final isAuthRoute=state.matchedLocation=='/login'||state.matchedLocation=='/signup';

    if(!isLoggedIn&&!isAuthRoute)return '/login';
    if(isLoggedIn&&isAuthRoute)return '/dashboard';
    return null;
  },
    //refresh when auth state changes
    refreshListenable: GoRouterRefreshStream(
      supabase.auth.onAuthStateChange,
    ),
    routes: [
      GoRoute(
        path: '/login',
        builder:(context,state)=>const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context,state)=>const SignupScreen(),
      ),
      GoRoute(path: '/dashboard',builder: (context,state)=>const DashboardScreen()),
      GoRoute(path: '/inventory',
      builder:(context,sate)=>const InventoryScreen(),
        routes: [
          GoRoute(path: 'add',builder: (context,state)=>const AddItemScreen(),
          ),
          GoRoute(
            path: ':id',
            builder:(context,state){
              final itemId=state.pathParameters['id'];
              return ItemDetailScreen(itemId: itemId!);
            },
          ),
        ],
      ),
      GoRoute(
        path:'/scanner',
        builder:(context,state)=>const ScannerScreen(),
      ),
      GoRoute(
        path:'/activity',
        builder:(context,state)=>const ActivityScreen(),
      ),
    ],
);
//Helper to make GoRouter work with Supabase auth stream
class GoRouterRefreshStream extends ChangeNotifier{
  GoRouterRefreshStream(Stream<AuthState> stream){
    notifyListeners();
    _subscription=stream.listen((_)=>notifyListeners());

  }
  late final dynamic _subscription;
  @override
  void dispose(){
    _subscription.cancel();
    super.dispose();
  }
}