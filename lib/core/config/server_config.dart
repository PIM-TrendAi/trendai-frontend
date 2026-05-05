/// Centralised Django server address.
///
/// [serverHost] is the compile-time fallback.
/// At runtime, [ServerConfig.host] is set by auto-discovery (main.dart)
/// before the app renders — so every consumer always reads the live value.
const serverHost = '127.0.0.1'; // fallback only
const serverPort = '8000';

/// Runtime-mutable config — set once in main() via ServerDiscovery.
class ServerConfig {
  static String host = serverHost;

  static String get httpBase => 'http://$host:$serverPort/api';
  static String get wsBase   => 'ws://$host:$serverPort';
}
