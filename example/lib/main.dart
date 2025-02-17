import 'package:flutter/material.dart';
import 'package:mrz_scanner/mrz_scanner.dart';

Future<void> main() async {
  runApp(const MrzScannerPage());
}

class MrzScannerPage extends StatefulWidget {
  static const String routeName = "/lib/MrzScannerPage";

  const MrzScannerPage({super.key});

  @override
  State<MrzScannerPage> createState() => _MrzScannerPageState();
}

class _MrzScannerPageState extends State<MrzScannerPage> {
  final MRZController controller = MRZController();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(builder: (context) {
        return MRZScanner(
          controller: controller,
          onSuccess: (mrzResult, lines) async {
            await showDialog(
              context: context,
              builder: (context) => Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 10),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          controller.currentState?.resetScanning();
                        },
                        child: const Text('Reset Scanning'),
                      ),
                      Text('Name : ${mrzResult.givenNames}'),
                      Text('First Name : ${mrzResult.surnames}'),
                      Text('Gender : ${mrzResult.sex.name}'),
                      Text('CountryCode : ${mrzResult.countryCode}'),
                      Text('Date of Birth : ${mrzResult.birthDate}'),
                      Text('Expiry Date : ${mrzResult.expiryDate}'),
                      Text('DocNum : ${mrzResult.documentNumber}'),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
