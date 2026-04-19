/// App-wide configuration (support contact, refunds, etc.).
class AppConfig {
  /// Support account email for the game. Used for Contact Support and policies.
  static const String supportEmail = "xandomanger@gmail.com";

  /// Refund contact email. Shown in Contact Support dialog.
  static const String refundEmail = "xandomanger@gmail.com";

  /// Short refund rules text shown in Contact Support / Refunds dialog.
  static const String refundRulesText =
      "• Refund requests: Contact us at the email below with your order details.\n"
      "• Eligibility: Refunds may apply per our terms and store policy.\n"
      "• Response: We will reply within a few business days.";

  /// Privacy Policy URL
  static const String privacyPolicyUrl = "https://sites.google.com/view/xo-game-policies/privacy-policy";

  /// Terms of Service URL
  static const String termsUrl = "https://sites.google.com/view/xo-game-policies/terms";

  /// Account Deletion Information URL
  static const String accountDeletionUrl = "https://sites.google.com/view/xo-game-policies/account-deletion";

  /// Google Policies URL
  static const String googlePoliciesUrl = "https://www.termsfeed.com/live/27d1303a-4c17-4d58-a16b-6d032142b26a";
}
