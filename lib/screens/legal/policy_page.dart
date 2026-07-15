import 'package:flutter/material.dart';

import '../../core/app_l10n.dart';
import '../../core/app_theme.dart';
import '../../widgets/app_ui.dart';
import 'policy_content.dart';

/// Reusable in-app legal/policy page rendered in the XO Arena dark-neon style.
///
/// Content is resolved from [PolicyContent] at build time using the current
/// app language, so pages are fully readable in both English and Arabic and
/// never open an external browser.
class PolicyPage extends StatelessWidget {
  final PolicyDoc doc;

  const PolicyPage({super.key, required this.doc});

  const PolicyPage.accountDeletion({super.key})
      : doc = PolicyDoc.accountDeletion;
  const PolicyPage.terms({super.key}) : doc = PolicyDoc.terms;
  const PolicyPage.privacy({super.key}) : doc = PolicyDoc.privacy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final data = PolicyContent.forDoc(doc, l10n.isAr);

    return Scaffold(
      backgroundColor: AppPalette.bgTop,
      appBar: AppBar(
        backgroundColor: AppPalette.bgTop,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppPalette.primary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          data.appBarTitle,
          style: safeOrbitron(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppPalette.primary,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
      ),
      body: AppBackground(
        child: SafeArea(
          child: Directionality(
            textDirection: l10n.isAr ? TextDirection.rtl : TextDirection.ltr,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
              children: [
                Text(
                  data.title,
                  style: safeOrbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppPalette.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: AppPalette.primary.withValues(alpha: 0.34)),
                  ),
                  child: Text(
                    data.lastUpdated,
                    style: safeInter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                for (final section in data.sections) ...[
                  _PolicySectionCard(section: section),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicySectionCard extends StatelessWidget {
  final PolicySection section;

  const _PolicySectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppPalette.strokeSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.heading.isNotEmpty) ...[
            Text(
              section.heading,
              style: safeOrbitron(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppPalette.primary,
                letterSpacing: 0.6,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            section.body,
            style: safeInter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppPalette.text,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
