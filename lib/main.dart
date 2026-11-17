import 'package:flutter/material.dart';

import 'app.dart';
import 'package:habitoliving_shared/services/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppServices.instance.init();
  runApp(const HabitoApp());
}
