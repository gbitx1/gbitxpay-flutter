import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gbitx_pay_flutter/gbitx_pay_flutter.dart';
import 'package:http/http.dart' as http;

// Point this at YOUR server (which creates the payment with the SECRET key).
const myBackend = 'https://your-server.example.com';
const publishableKey = 'pk_test_0000000000000000000000000000000000000000000000000000000000000000';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await GbitxPay.instance.configure(publishableKey: publishableKey);
  } on GbitxPayException catch (e) {
    debugPrint('configure failed: ${e.code}');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: CheckoutScreen());
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _status = 'idle';

  Future<void> _pay() async {
    try {
      setState(() => _status = 'creating payment…');
      // 1) YOUR server creates the payment with the secret key and returns
      //    only { paymentId, clientToken }.
      final res = await http.post(Uri.parse('$myBackend/checkout'));
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      // 2) Open the hosted checkout.
      setState(() => _status = 'opening checkout…');
      final result = await GbitxPay.instance.present(
        paymentId: body['paymentId'] as String,
        clientToken: body['clientToken'] as String,
      );

      // 3) UX only. Your server fulfils the order from the signed webhook.
      setState(() => _status = 'result: ${result.runtimeType}');
    } on GbitxPayException catch (e) {
      setState(() => _status = 'error: ${e.code}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GbitXPay example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(onPressed: _pay, child: const Text('Pay with crypto')),
            const SizedBox(height: 16),
            Text(_status),
          ],
        ),
      ),
    );
  }
}
