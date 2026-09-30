import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

import '../../../Model/Comunication_model/Send_email_table.dart';
import '../../../constant/constant.dart';
import '../../../provider/dateProvider.dart';
import '../../../widgets/custom_drawer.dart';

/// Full "Email Details" view (Subject, To, From, Status, Body) — the mobile
/// equivalent of tapping the Subject on web (EmailDialog.jsx). All fields come
/// straight off the email-log row, so no extra API call is needed. Tenant
/// Communications opens it too (web reuses EmailDialog for both lists), so
/// [drawerPage] keeps the drawer on the page the user came from.
class EmailDetailsScreen extends StatelessWidget {
  final Emailss email;
  final String drawerPage;

  const EmailDetailsScreen(
      {Key? key, required this.email, this.drawerPage = "E-mail Logs"})
      : super(key: key);

  bool get _isOpened => email.opens != null && email.opens!.isNotEmpty;

  String get _toValue =>
      (email.to != null && email.to!.isNotEmpty) ? email.to!.join(', ') : 'N/A';

  String _openedAtText(DateProvider dateProvider) {
    if (!_isOpened) return '';
    final raw = email.opens!.first.openedAt;
    if (raw == null || raw.trim().isEmpty) return '';
    try {
      final ms = int.tryParse(raw);
      final dt = ms != null
          ? DateTime.fromMillisecondsSinceEpoch(ms)
          : DateTime.parse(raw);
      // Saved Date & Time Format (12/24-hour, with seconds), like web.
      return dateProvider.formatLocalDateTime(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentpage: drawerPage,
        dropdown: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 500 ? 28 : 16,
                vertical: 8,
              ),
              child: titleBar(
                width: double.infinity,
                title: 'Email Details',
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 500 ? 28 : 16,
                vertical: 8,
              ),
              child: Column(
                children: [
                  _card(
                    icon: Icons.email_outlined,
                    label: 'SUBJECT',
                    child: Text(
                      (email.subject ?? '').isNotEmpty
                          ? email.subject!
                          : 'No Subject',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                        height: 1.5,
                      ),
                    ),
                  ),
                  _card(
                    icon: Icons.person_outline,
                    label: 'TO',
                    child: Text(
                      _toValue,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF333333),
                        height: 1.5,
                      ),
                    ),
                  ),
                  _card(
                    icon: Icons.send_outlined,
                    label: 'FROM',
                    child: Text(
                      (email.from ?? '').isNotEmpty ? email.from! : 'N/A',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF333333),
                        height: 1.5,
                      ),
                    ),
                  ),
                  _card(
                    icon: _isOpened
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    iconColor: _isOpened
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF9800),
                    label: 'STATUS',
                    child: _statusRow(dateProvider),
                  ),
                  _card(
                    icon: Icons.email_outlined,
                    label: 'BODY',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE8E8E8)),
                      ),
                      child: Html(
                        data: (email.body ?? '').trim().isNotEmpty
                            ? email.body!
                            : "<p style='color:#999;font-style:italic;'>No content available</p>",
                        // The 2FA/login-code email template sizes its navy
                        // title band for a 600px desktop inbox (24px h1, 30px
                        // padding); on a phone-width screen "Two-Factor
                        // Authentication" wraps to two lines and the band
                        // reads as oversized. This only touches how this
                        // preview renders it — the selector targets the white
                        // title text specifically (its style attribute has
                        // color: #ffffff), not the navy verification-code h1
                        // in the box below it (color: #152B51), which stays
                        // full size. The email actually sent/stored is
                        // untouched.
                        style: {
                          "h1[style*=\"ffffff\"]": Style(
                            fontSize: FontSize(18),
                            margin: Margins.zero,
                          ),
                          "div[style*=\"152B51\"]": Style(
                            padding: HtmlPaddings.symmetric(vertical: 16),
                          ),
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(DateProvider dateProvider) {
    final openedAt = _openedAtText(dateProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _isOpened ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _isOpened ? 'Opened' : 'Not Opened',
            style: TextStyle(
              color:
                  _isOpened ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        if (openedAt.isNotEmpty) ...[
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              openedAt,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _card({
    required IconData icon,
    required String label,
    required Widget child,
    Color? iconColor,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor ?? blueColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: blueColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
