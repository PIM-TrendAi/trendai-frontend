/// Centralised Django server address.
///
/// [serverHost] is the compile-time fallback.
/// At runtime, [ServerConfig.host] is set by auto-discovery (main.dart)
/// before the app renders — so every consumer always reads the live value.
const serverHost = '192.168.1.130'; // fallback only
const serverPort = '8000';

/// Runtime-mutable config — set once in main() via ServerDiscovery.
class ServerConfig {
  static String host = serverHost;

  static bool get _isTunnel => host.contains('loca.lt');

  static String get httpBase => _isTunnel ? 'https://$host/api' : 'http://$host:$serverPort/api';
  static String get wsBase   => _isTunnel ? 'wss://$host'       : 'ws://$host:$serverPort';
}
