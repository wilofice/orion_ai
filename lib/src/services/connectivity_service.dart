import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService with ChangeNotifier {
  bool _isOnline = true;
  late final StreamSubscription<ConnectivityResult> _subscription;

  ConnectivityService() {
    _subscription =
        Connectivity().onConnectivityChanged.listen(_updateStatus);
    _init();
  }

  bool get isOnline => _isOnline;

  Future<void> _init() async {
    final result = await Connectivity().checkConnectivity();
    _updateStatus(result);
  }

  void _updateStatus(ConnectivityResult result) {
    final online = result != ConnectivityResult.none;
    if (online != _isOnline) {
      _isOnline = online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
