import 'package:flutter/material.dart';

import 'services/storage_service.dart';
import 'services/vpn_engine.dart';
import 'state/app_state.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();

  final state = AppState();
  await state.load();

  runApp(SCVpnApp(state: state, vpn: VpnEngine.instance));
}

class SCVpnApp extends StatelessWidget {
  final AppState state;
  final VpnEngine vpn;

  const SCVpnApp({super.key, required this.state, required this.vpn});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([state, vpn.status]),
      builder: (context, _) => HomePage(state: state, vpn: vpn),
    );
  }
}
