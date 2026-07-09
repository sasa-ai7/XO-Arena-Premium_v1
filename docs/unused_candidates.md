# Archived unused files

These Dart files were **not imported or referenced anywhere** in `lib/` (verified
by import + symbol grep on 2026-07-09). They were moved out of `lib/` to
`_archive_unused/` during the safe cleanup pass so they no longer compile into
the app or add to analysis, while remaining fully recoverable (also in git
history on branch `cleanup-performance-pass`).

`_archive_unused/**` is excluded from the analyzer (see `analysis_options.yaml`).

| Original path | Lines | Notes |
|---|---|---|
| `lib/coins/coins_verification_service.dart` | 203 | Cloud Functions coin verification; never wired in. IAP uses the client-only flow. |
| `lib/core/firebase_config_validator.dart` | 172 | Startup Firebase config validator; not called from `startup.dart` or `main.dart`. |
| `lib/screens/create_account_screen.dart` | 893 | Standalone create-account screen; superseded by the current onboarding/login flow. |
| `lib/services/email_verification_link_handler.dart` | 216 | Email-link verification handler; not referenced (verification uses resend controller). |
| `lib/services/offline_wallet_service.dart` | 80 | Superseded by `LocalStore` offline wallet handling. |
| `lib/widgets/numeric_keypad.dart` | 123 | Old numeric keypad; arena uses `screens/arena/widgets/digit_keypad.dart`. |
| `lib/screens/arena/widgets/round_result_overlay.dart` | 500 | Unused round-result overlay; arena uses `countdown_overlay.dart` + inline result UI. |

**Total: ~2,187 lines removed from the compiled app.**

## To restore any file
```bash
git mv _archive_unused/<path> lib/<original-path>
```
Then remove the `_archive_unused/**` exclude if the directory becomes empty.
