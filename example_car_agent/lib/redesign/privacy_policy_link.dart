import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

/// The app's privacy policy (Google Play asks for it in the store listing and inside the app).
const kPrivacyPolicyUrl = 'https://davoice.io/privacy/car-agent';

/// A settings row that opens the privacy policy in the browser (as the React Native car agent's PrivacyPolicyLink).
class PrivacyPolicyLink extends StatelessWidget {
  const PrivacyPolicyLink({super.key});

  Future<void> _open() async {
    try {
      await launchUrl(Uri.parse(kPrivacyPolicyUrl), mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('[PrivacyPolicy] could not open the link: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Privacy policy', style: inter(14, FontWeight.w600, C.text)),
              const SizedBox(height: 2),
              Text('davoice.io/privacy/car-agent', style: inter(12, FontWeight.w400, C.text2)),
            ],
          ),
        ),
        Semantics(
          link: true,
          label: 'Open the privacy policy',
          child: GestureDetector(
            onTap: _open,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x8034D399)),
              ),
              child: Text('Open', style: inter(14, FontWeight.w600, C.mint)),
            ),
          ),
        ),
      ],
    );
  }
}
