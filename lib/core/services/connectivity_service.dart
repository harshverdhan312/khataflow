abstract class ConnectivityService {
  Stream<bool> get isOnline;
  Future<bool> checkConnectivity();
}
