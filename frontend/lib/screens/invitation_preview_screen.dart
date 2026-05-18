import 'package:flutter/material.dart';

class InvitationPreviewScreen extends StatelessWidget {
  final String token;

  const InvitationPreviewScreen({required this.token, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zaproszenie')),
      body: const Center(
        child: Text('Podgląd zaproszenia – wkrótce'),
      ),
    );
  }
}
