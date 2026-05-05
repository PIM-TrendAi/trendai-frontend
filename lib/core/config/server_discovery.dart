/// Auto-discovers the Django server on the local WiFi network.
///
/// Strategy (in order):
///   1. Try the cached IP from the last successful session (instant).
///   2. Scan the most common DHCP addresses on the phone's subnet in parallel.
///   3. Cache whichever IP responds first to GET /api/health/.
///
/// Usage:
///   final ip = await ServerDiscovery.resolveHost();
///   // → '192.168.1.15'  (or whatever the PC's current IP is)
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'server_config.dart';

const _cacheKey = 'discovered_server_host';
const _port = serverPort;
const _timeout = Duration(milliseconds: 800);

/// Returns the host (no port, no scheme) of the Django server.
/// Falls back to the compile-time [serverHost] if discovery fails.
Future<String> discoverServerHost() async {
  if (kIsWeb) return '127.0.0.1'; // Localhost for web development
  
  final prefs = await SharedPreferences.getInstance();

  // 1. Try cached host first
  final cached = prefs.getString(_cacheKey);
  if (cached != null && await _isReachable(cached)) {
    return cached;
  }

  // 2. Derive subnet from the device's own IP and scan in parallel
  final subnet = await _localSubnet();
  final candidates = <String>{};

  if (subnet != null) {
    // Most routers assign low numbers first, scan 1-30 and 100-120
    for (var i = 1; i <= 30; i++) { candidates.add('$subnet.$i'); }
    for (var i = 100; i <= 120; i++) { candidates.add('$subnet.$i'); }
  }

  // Always include known historical IPs as extra hints
  candidates.addAll(['127.0.0.1', '192.168.1.15', '192.168.1.112', '192.168.1.217']);

  final found = await _raceReachable(candidates.toList());
  if (found != null) {
    await prefs.setString(_cacheKey, found);
    return found;
  }

  // 3. Fallback to compile-time constant
  return serverHost;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

Future<bool> _isReachable(String host) async {
  try {
    final client = HttpClient()..connectionTimeout = _timeout;
    final req = await client
        .getUrl(Uri.parse('http://$host:$_port/api/health/'))
        .timeout(_timeout);
    final resp = await req.close().timeout(_timeout);
    await resp.drain<void>();
    client.close();
    return resp.statusCode == 200;
  } catch (_) {
    return false;
  }
}

/// Try all candidates in parallel; return the first reachable one.
Future<String?> _raceReachable(List<String> hosts) async {
  final completer = Completer<String?>();
  var pending = hosts.length;

  for (final host in hosts) {
    _isReachable(host).then((ok) {
      if (ok && !completer.isCompleted) completer.complete(host);
      pending--;
      if (pending == 0 && !completer.isCompleted) completer.complete(null);
    });
  }

  return completer.future.timeout(const Duration(seconds: 4), onTimeout: () => null);
}

/// Returns the subnet prefix, e.g. '192.168.1' from '192.168.1.3'.
Future<String?> _localSubnet() async {
  try {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final parts = addr.address.split('.');
        if (parts.length == 4 && parts[0] == '192' && parts[1] == '168') {
          return '${parts[0]}.${parts[1]}.${parts[2]}';
        }
      }
    }
  } catch (_) {}
  return null;
}
