import 'package:flutter/material.dart';
import 'package:stockpulse/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

class AuthProvider extends ChangeNotifier{
  Profile? _profile;
  bool _isLoading=false;
  String? _error;

  Profile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAdmin=>_profile?.isAdmin??false;
  bool get isLoggedIn=>supabase.auth.currentUser!=null;

  AuthProvider(){
    _init();
  }

  void _init(){
    //Listen to the auth changes
    supabase.auth.onAuthStateChange.listen((data){
      final event=data.event;
      if(event==AuthChangeEvent.signedIn){
        _fetchProfile();
      }else if(event==AuthChangeEvent.signedOut){
        _profile=null;
        notifyListeners();
      }
    });

    //Load profile if already logged in
    if (isLoggedIn){
      _fetchProfile();
    }
  }
  Future<void> _fetchProfile()async{
    try{
      final userId=supabase.auth.currentUser!.id;
      final data=await supabase.from('profiles').select().eq('id', userId).single();
      _profile=Profile.fromJson(data);
    } catch (e) {
      _error=e.toString();
      notifyListeners();
    }
  }
  //Sign up a new user
 //[isAdmin] should only be true when creating admin accounts
Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    bool isAdmin=false,
})async{
    try{
      _isLoading=true;
      _error=null;
      notifyListeners();

      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'is_admin': isAdmin,
        }

      );
      return null;
    }on AuthException catch(e){
      _error=e.message;
      return _error;
    }finally{
      _isLoading=false;
      notifyListeners();
    }
}
 //Sign in existing user
Future<String?> signIn({
    required String email,
    required String password,
})async{
    try{
      _isLoading=true;
      _error=null;
      notifyListeners();

      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return null;
    }on AuthException catch(e){
      _error=e.message;
      return _error;
    }finally{
      _isLoading=false;
      notifyListeners();
    }
}

  Future<void> signOut()async{
    await supabase.auth.signOut();
  }
}