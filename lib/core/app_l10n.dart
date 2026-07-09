import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Centralized localization strings for XO ARENA.
///
/// Supports English ('en') and Arabic ('ar').
/// The game name "XO ARENA" is always in English regardless of locale.
///
/// Usage: AppL10n.of(context).someString
class AppL10n {
  final String languageCode;

  const AppL10n(this.languageCode);

  bool get isAr => languageCode == 'ar';

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n) ?? const AppL10n('en');
  }

  // ── Game title — ALWAYS English ────────────────────────────────────────
  String get gameTitle => 'XO ARENA';
  String get gameSubtitle => isAr ? 'معارك إلكترونية متطورة' : 'PREMIUM CYBER BATTLES';

  // ── Character selection ────────────────────────────────────────────────
  String get selectCharacter => isAr ? 'اختر الشخصية' : 'SELECT CHARACTER';
  String get chooseYourCharacter => isAr ? 'اختر شخصيتك' : 'Choose Your Character';
  String get selectCharacterSubtitle => isAr
      ? 'اختر الشخصية التي تناسبك لتجربة XO ARENA.'
      : 'Select your character to personalize your XO Arena experience.';
  String get male => isAr ? 'ذكر' : 'Male';
  String get female => isAr ? 'أنثى' : 'Female';
  String get next => isAr ? 'التالي' : 'NEXT';

  // ── Offline player setup (first launch, no sign-in) ────────────────────
  String get offlineSetupTitle => isAr ? 'أنشئ لاعبك' : 'Create Your Player';
  String get offlineSetupSubtitle => isAr
      ? 'العب دون اتصال الآن. سجّل الدخول لاحقاً للأونلاين والمتجر.'
      : 'Play offline now. Sign in later for online play & store.';
  String get playerNameLabel => isAr ? 'اسم اللاعب' : 'PLAYER NAME';
  String get playerNameHint => isAr ? 'أدخل اسمك' : 'Enter your name';
  String get playerNameRequired =>
      isAr ? 'الرجاء إدخال اسم صحيح' : 'Please enter a valid name';
  String get boy => isAr ? 'ولد' : 'Boy';
  String get girl => isAr ? 'بنت' : 'Girl';
  String get startPlaying => isAr ? 'ابدأ اللعب' : 'START PLAYING';
  String get canChangeCharacterLater => isAr
      ? 'يمكنك تغيير شخصيتك لاحقاً في إعدادات ملفك الشخصي.'
      : 'You can change your character later in your profile settings.';

  // ── Create Account / Complete Profile ─────────────────────────────────
  String get createAccount => isAr ? 'إنشاء الحساب' : 'CREATE ACCOUNT';
  String get completeProfile => isAr ? 'COMPLETE PROFILE' : 'COMPLETE PROFILE';
  String get forgeYourArenaId => isAr ? 'أنشئ هويتك في الساحة' : 'Forge Your Arena ID';
  String get activateArenaProfile => isAr ? 'فعّل ملفك في الساحة' : 'Activate Your Arena Profile';
  String get accountDetails => isAr ? 'تفاصيل الحساب' : 'ACCOUNT DETAILS';
  String get completeYourProfile => isAr ? 'أكمل ملفك الشخصي' : 'COMPLETE YOUR PROFILE';
  String get verifiedGoogleEmail => isAr ? 'بريد جوجل موثق' : 'VERIFIED GOOGLE EMAIL';
  String get setPassword => isAr ? 'تعيين كلمة المرور' : 'SET PASSWORD';
  String get setPasswordHint => isAr
      ? 'عيّن كلمة مرور لتسجيل الدخول باستخدام البريد الإلكتروني وكلمة المرور.'
      : 'Set a password to sign in with email & password.';
  String get linkingNote => isAr
      ? 'يربط هذا طريقة تسجيل الدخول بالبريد وكلمة المرور بحسابك على Google.'
      : 'This links an email/password login method to your Google account.';

  // ── Form fields ────────────────────────────────────────────────────────
  String get nameHint => isAr ? 'الاسم' : 'Name';
  String get emailHint => isAr ? 'البريد الإلكتروني' : 'Email';
  String get passwordHint => isAr ? 'كلمة المرور' : 'PASSWORD';
  String get confirmPasswordHint => isAr ? 'تأكيد كلمة المرور' : 'CONFIRM PASSWORD';

  String get agreeToTerms => isAr
      ? 'أوافق على الشروط والسياسات'
      : 'I agree to the terms and policies';
  String get agreeToTermsAlt => isAr
      ? 'أوافق على شروط الخدمة وسياسة الخصوصية'
      : 'I accept the Terms of Service and Privacy Policy';
  String get privacyPolicy => isAr ? 'سياسة الخصوصية' : 'Privacy Policy';
  String get googlePolicies => isAr ? 'سياسات Google' : 'Google Policies';
  String get agreeToPrivacyPrefix => isAr ? 'أوافق على ' : 'I agree to the ';
  String get agreeToPrivacyAnd => isAr ? ' و' : ' and ';

  // ── Validation errors ──────────────────────────────────────────────────
  String get nameRequired => isAr ? 'الاسم مطلوب' : 'Name is required';
  String get nameTooShort => isAr ? 'الاسم قصير جداً' : 'Name is too short';
  String get nameTooLong =>
      isAr ? 'الاسم طويل جداً (الحد الأقصى 20 حرفاً)' : 'Name is too long (max 20 characters)';
  String get emailRequired => isAr ? 'البريد الإلكتروني مطلوب' : 'Email is required';
  String get emailInvalid => isAr ? 'أدخل بريداً إلكترونياً صحيحاً' : 'Enter a valid email';
  String get passwordRequired => isAr ? 'كلمة المرور مطلوبة' : 'Password is required';
  String get passwordTooShort =>
      isAr ? 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل' : 'Password must be at least 6 characters';
  String get confirmPasswordRequired =>
      isAr ? 'الرجاء تأكيد كلمة المرور' : 'Confirm your password';
  String get passwordsDoNotMatch =>
      isAr ? 'كلمتا المرور غير متطابقتين' : 'Passwords do not match';
  String get acceptTermsRequired =>
      isAr ? 'الرجاء قبول الشروط والسياسات للمتابعة.' : 'Please accept the Terms & Privacy Policy to continue.';
  String get acceptPrivacyRequired =>
      isAr ? 'الرجاء قبول سياسة الخصوصية للمتابعة.' : 'Please accept the Privacy Policy to continue.';

  // ── Age restriction ────────────────────────────────────────────────────
  String get ageRestrictionTitle => isAr ? 'قيد عمري' : 'Age Restriction';
  String get ageRestrictionMsg => isAr
      ? 'هذا التطبيق غير مخصص للمستخدمين دون سن 13. الرجاء التواصل مع ولي الأمر.'
      : 'This app is not for users under 13. Please contact a parent.';
  String get ageRestrictionMsgAlt => isAr
      ? 'يجب أن يكون عمرك 13 سنة على الأقل لاستخدام هذا التطبيق.'
      : 'You must be at least 13 years old to use this app.';
  String get ok => isAr ? 'حسناً' : 'OK';

  // ── Age gate (Yes/No 13+ confirmation) ─────────────────────────────────
  String get ageGateQuestion =>
      isAr ? 'هل عمرك 13 سنة أو أكثر؟' : 'Are you 13 or older?';
  String get ageGateYes =>
      isAr ? 'نعم، عمري 13 أو أكثر' : 'Yes, I am 13 or older';
  String get ageGateNo => isAr ? 'لا' : 'No';
  String get ageGateRequired => isAr
      ? 'الرجاء تأكيد عمرك للمتابعة.'
      : 'Please confirm your age to continue.';

  // ── Online Friends (Home card replacing Coin Battle) ───────────────────
  String get onlineFriendsTitle => isAr ? 'أصدقاء أونلاين' : 'ONLINE FRIENDS';
  String get onlineFriendsSubtitle => isAr
      ? 'العب 1 ضد 1 برمز غرفة خاص.'
      : 'Play 1v1 with a private room code.';
  String get badgeMultiplayer => isAr ? 'متعدد اللاعبين' : 'MULTIPLAYER';

  // ── Daily Reminders (Settings toggle) ──────────────────────────────────
  String get dailyRemindersLabel =>
      isAr ? 'إشعارات اللعبة' : 'Game Notifications';
  String get dailyRemindersSubtitle =>
      isAr ? 'المكافآت والدعوات والمزيد' : 'Rewards, invites and more';
  String get notificationPermissionDenied => isAr
      ? 'تم رفض إذن الإشعارات.'
      : 'Notification permission denied.';

  // ── Login screen ───────────────────────────────────────────────────────
  String get signIn => isAr ? 'تسجيل الدخول' : 'SIGN IN';
  String get enterArena => isAr ? 'دخول الساحة' : 'ENTER ARENA';
  String get continueWithGoogle => isAr ? 'المتابعة عبر Google' : 'CONTINUE WITH GOOGLE';
  String get continueAsGuest => isAr ? 'المتابعة كضيف' : 'CONTINUE AS GUEST';
  String get alreadyHaveAccount => isAr ? 'لديك حساب بالفعل؟ ' : 'Already have an account? ';
  String get signInLink => isAr ? 'تسجيل الدخول' : 'Sign In';
  String get language => isAr ? 'اللغة' : 'Language';
  // ── Welcome screen ─────────────────────────────────────────────────────
  String get theArenaAwaits => isAr ? 'الساحة في انتظارك' : 'THE ARENA AWAITS';
  String get enterTheArena => isAr ? 'دخول الساحة' : 'ENTER THE ARENA';
  String get quickStart => isAr ? 'بداية سريعة' : 'QUICK START';
  String get quickStartDesc => isAr ? 'لا حاجة للتسجيل. العب في ثوانٍ.' : 'No signup needed. Play in seconds.';
  String get fairRewards => isAr ? 'مكافآت عادلة' : 'FAIR REWARDS';
  String get fairRewardsDesc => isAr ? 'اكسب عملات وافتح إضافات.' : 'Earn coins, unlock cosmetics.';
  String get competitiveFlow => isAr ? 'تدفق تنافسي' : 'COMPETITIVE FLOW';
  String get competitiveFlowDesc =>
      isAr ? 'منفرد، 1v1، معارك عملات والمزيد.' : 'Solo, 1v1, coin battles & more.';

  // ── Settings ───────────────────────────────────────────────────────────
  String get settings => isAr ? 'الإعدادات' : 'Settings';
  String get languageToggleLabel => isAr ? 'اللغة: العربية' : 'Language: English';
  String get switchToArabic => isAr ? 'التبديل إلى الإنجليزية' : 'Switch to Arabic';

  // ── Common ─────────────────────────────────────────────────────────────
  String get back => isAr ? 'رجوع' : 'Back';
  String get close => isAr ? 'إغلاق' : 'Close';
  String get loading => isAr ? 'جاري التحميل...' : 'Loading...';
  String get error => isAr ? 'خطأ' : 'Error';
  String get success => isAr ? 'نجاح' : 'Success';
  String get retry => isAr ? 'إعادة المحاولة' : 'Retry';

  // ── Chip labels ────────────────────────────────────────────────────────
  String get chipAge13Plus => isAr ? '+13 سنة' : 'AGE 13+';
  String get chipEmailVerified => isAr ? 'بريد موثق' : 'EMAIL VERIFIED';
  String get chipSyncReady => isAr ? 'جاهز للمزامنة' : 'SYNC READY';
  // ── Account creation flow description ─────────────────────────────────
  String get createAccountDesc => isAr
      ? 'أنشئ ملفاً موثقاً لمزامنة العملات والإضافات والمشتريات والتقدم في كل جلسة.'
      : 'Create a verified profile to sync coins, cosmetics, purchases, and progression across every arena session.';
  String get activateProfileDesc => isAr
      ? 'أكمل الإعداد حتى يبقى تقدمك وإضافاتك ورصيدك مرتبطاً في كل مكان.'
      : 'Finish setup so your progress, cosmetics, and balance stay linked everywhere.';

  // ── Verification dialog ────────────────────────────────────────────────
  String get verifyEmail => isAr ? 'تحقق من بريدك الإلكتروني' : 'Verify your email';
  String get emailVerified => isAr ? 'تم التحقق من البريد!' : 'Email Verified!';
  String get verifyEmailMsg => isAr
      ? 'تم إرسال رسالة إلى بريدك الإلكتروني.\nالرجاء التحقق من صندوق الوارد (بما فيه البريد العشوائي).'
      : 'A message has been sent to your email.\nPlease check your inbox (including the spam folder).';
  String get emailVerifiedMsg => isAr
      ? 'تم التحقق من بريدك الإلكتروني. يمكنك الآن تسجيل الدخول.'
      : 'Your email has been verified. You can now log in to your account.';
  String get checkSpamTip => isAr
      ? 'تلميح: تحقق من صندوق الوارد / العروض الترويجية / البريد العشوائي.'
      : 'Tip: Check Inbox / Promotions / Spam for the verification email.';
  String get refreshStatus => isAr ? 'تحديث الحالة' : 'Refresh Status';
  String get checking => isAr ? 'جاري التحقق...' : 'Checking...';
  String get resendEmail => isAr ? 'إعادة إرسال البريد' : 'Resend Email';
  String get sending => isAr ? 'جاري الإرسال...' : 'Sending...';
  String get goToLogin => isAr ? 'الذهاب إلى تسجيل الدخول' : 'Go to Login';

  // ── Offline / Online transitions ───────────────────────────────────────
  String get offlineMode => isAr ? 'غير متصل' : 'OFFLINE';
  String get connectionLost => isAr ? 'تم فقدان الاتصال' : 'Connection Lost';
  String get switchingToOfflineMode =>
      isAr ? 'جارٍ التحويل إلى وضع عدم الاتصال...' : 'Switching to Offline Mode...';
  String get offlineProgressNote =>
      isAr ? 'تقدمك محفوظ محلياً.' : 'Offline progress is saved locally.';
  String get connectionRestored =>
      isAr ? 'تم استعادة الاتصال' : 'CONNECTION RESTORED';
  String get syncingOnlineAccount =>
      isAr ? 'جارٍ مزامنة حسابك...' : 'SYNCING YOUR ACCOUNT...';
  String get returningToOnlineAccount =>
      isAr ? 'جارٍ العودة إلى حسابك المتصل...' : 'Returning to your online account...';

  // ── A1 — Home navigation & game mode section ───────────────────────────
  String get home => isAr ? 'الرئيسية' : 'Home';
  String get storeTab => isAr ? 'المتجر' : 'Store';
  String get settingsTab => isAr ? 'الإعدادات' : 'Settings';
  String get selectMode => isAr ? 'اختر النمط' : 'SELECT MODE';
  String get chooseYourArena => isAr ? 'اختر ساحتك' : 'Choose your arena';
  String get arenaModesDesc =>
      isAr ? 'منفرد، 1v1، معارك عملات، أو تحديات مستويات.' : 'Solo, 1v1, coin battles, or level challenges.';
  String get modesCount => isAr ? '4 أنماط' : '4 MODES';
  String get vsAiTitle => isAr ? 'ضد الذكاء الاصطناعي' : 'VS AI';
  String get vsAiSubtitle => isAr ? 'تدرب، تحدى، تسيطر' : 'Train, challenge, dominate';
  String get vsFriendTitle => isAr ? 'ضد صديق' : 'VS FRIEND';
  String get vsFriendSubtitle => isAr ? '1v1 على نفس الجهاز' : '1v1 on one device';
  String get levelsTitle => isAr ? 'المستويات' : 'LEVELS';
  String get levelsSubtitle => isAr ? 'تخطَّ المراحل، افتح المكافآت' : 'Beat stages, unlock rewards';
  String get badgeAi => isAr ? 'ذكاء' : 'AI';
  String get badgeHot => isAr ? 'رائج' : 'HOT';
  String get badgeReward => isAr ? 'مكافأة' : 'REWARD';
  String get saveYourProgress => isAr ? 'احفظ تقدمك' : 'SAVE YOUR PROGRESS';
  String get saveYourProgressDesc => isAr
      ? 'أنشئ حساباً مجانياً لمزامنة عملاتك وإضافاتك وإحصائياتك عبر الأجهزة.'
      : 'Create a free account to sync your coins, cosmetics, and stats across devices.';
  String get maybeLater => isAr ? 'ربما لاحقاً' : 'MAYBE LATER';
  String get signInRequiredTitle => isAr ? 'تسجيل الدخول مطلوب' : 'Sign in required';
  String get signInRequiredDesc => isAr
      ? 'سجّل دخولك لكسب العملات وشراء الإضافات. ستحصل أيضاً على 200 عملة كهدية ترحيبية.'
      : 'Sign in to earn coins and buy themes. You\'ll also get a 200 coins welcome gift.';
  String get notNow => isAr ? 'ليس الآن' : 'Not now';
  String get signInBtn => isAr ? 'تسجيل الدخول' : 'Sign in';
  String get underMaintenance => isAr ? 'تحت الصيانة' : 'Under Maintenance';
  String get underMaintenanceDesc => isAr
      ? 'البرنامج يواجه خطأ وهو حالياً تحت الصيانة'
      : 'The program has an error and is under maintenance';

  // ── A2 — Language switch dialog & UX ──────────────────────────────────
  String get changeLanguageTitle => isAr ? 'تغيير اللغة؟' : 'Change Language?';
  String get changeLanguageToArabicMsg =>
      isAr ? 'هل تريد تحويل لغة التطبيق إلى العربية؟' : 'Switch the app language to Arabic?';
  String get changeLanguageToEnglishMsg =>
      isAr ? 'هل تريد تحويل لغة التطبيق إلى الإنجليزية؟' : 'Switch the app language to English?';
  String get switchLanguageBtn => isAr ? 'تغيير' : 'Switch';
  String get cancelBtn => isAr ? 'إلغاء' : 'CANCEL';
  String get switchingLanguage => isAr ? 'جارٍ تغيير اللغة...' : 'Switching language...';
  String get languageChangedSuccessfully =>
      isAr ? 'تم تغيير اللغة بنجاح.' : 'Language changed successfully.';
  String get currentLanguageLabel => isAr ? 'اللغة: العربية' : 'Language: English';
  String get switchToLabel =>
      isAr ? 'اضغط للتبديل إلى الإنجليزية' : 'Tap to switch to Arabic';

  // ── A3 — Login screen auth errors ─────────────────────────────────────
  String get networkError =>
      isAr ? 'خطأ في الشبكة. تحقق من الاتصال.' : 'NETWORK ERROR. CHECK YOUR CONNECTION.';
  String get incorrectPassword =>
      isAr ? 'كلمة المرور غير صحيحة. حاول مرة أخرى.' : 'INCORRECT PASSWORD. TRY AGAIN.';
  String get accountNotFound =>
      isAr ? 'الحساب غير موجود. تحقق من البريد الإلكتروني.' : 'ACCOUNT NOT FOUND. CHECK EMAIL.';
  String get invalidEmailError =>
      isAr ? 'البريد الإلكتروني غير صحيح.' : 'INVALID EMAIL ADDRESS.';
  String get emailUsesGoogle =>
      isAr ? 'هذا البريد مرتبط بـ Google. استخدم تسجيل الدخول عبر Google.' : 'THIS EMAIL USES GOOGLE SIGN-IN. CONTINUE WITH GOOGLE.';
  String get loginFailed =>
      isAr ? 'فشل تسجيل الدخول. حاول مرة أخرى.' : 'LOGIN FAILED. TRY AGAIN.';
  String get invalidEmailOrPassword =>
      isAr ? 'بريد إلكتروني أو كلمة مرور غير صحيحة.' : 'INVALID EMAIL OR PASSWORD.';
  String get connectingArenaProfile =>
      isAr ? 'جارٍ تحميل ملفك في الساحة...' : 'CONNECTING YOUR ARENA PROFILE...';
  String get displayNameLengthError =>
      isAr ? 'يجب أن يكون الاسم بين 3 و16 حرفاً.' : 'DISPLAY NAME MUST BE 3-16 CHARACTERS.';

  // ── A4 — Create account / Complete profile errors ──────────────────────
  String get failedToSyncProfile =>
      isAr ? 'تم تسجيل الدخول لكن فشل مزامنة الملف الشخصي' : 'Logged in but failed to sync profile';
  String get signUpFailed =>
      isAr ? 'فشل إنشاء الحساب. حاول مرة أخرى.' : 'Sign-up failed. Try again.';
  String get couldNotOpenPrivacyPolicy =>
      isAr ? 'تعذّر فتح سياسة الخصوصية.' : 'Could not open Privacy Policy.';
  String get couldNotOpenGooglePolicies =>
      isAr ? 'تعذّر فتح سياسات Google.' : 'Could not open Google Policies.';
  String get emailAlreadyInUse =>
      isAr ? 'هذا البريد الإلكتروني مستخدم بالفعل.' : 'An account already exists with this email.';
  String get passwordTooWeak =>
      isAr ? 'كلمة المرور ضعيفة. استخدم 6 أحرف على الأقل.' : 'Password is too weak. Use at least 6 characters.';
  String get internetProblem =>
      isAr ? 'خطأ في الشبكة. تحقق من اتصالك.' : 'Network error. Check your connection.';
  String get verificationEmailSent =>
      isAr ? 'تم إرسال بريد التحقق!' : 'Verification email sent!';
  String get failedToSendVerification =>
      isAr ? 'فشل إرسال بريد التحقق.' : 'Failed to send verification email.';
  String get emailVerifiedSuccess =>
      isAr ? 'تم التحقق من بريدك! يمكنك الآن تسجيل الدخول.' : 'Email verified! You can now log in.';
  String get emailNotVerifiedYet =>
      isAr ? 'لم يتم التحقق من بريدك بعد. تحقق من صندوق الوارد.' : 'Email not verified yet. Please check your email.';
  String get failedToRefreshStatus =>
      isAr ? 'فشل تحديث الحالة. حاول مرة أخرى.' : 'Failed to refresh status. Please try again.';
  String get profileCompletedFailedSync =>
      isAr ? 'اكتمل الملف الشخصي لكن فشلت المزامنة' : 'Profile completed but failed to sync';
  String get profileCompletedSuccess =>
      isAr ? 'اكتمل إعداد ملفك الشخصي بنجاح!' : 'Profile completed successfully!';
  String get emailMustMatchGoogle =>
      isAr ? 'يجب أن يطابق البريد بريدك في Google.' : 'Email must match your Google account email.';
  String get passwordAlreadyLinked =>
      isAr ? 'كلمة المرور هذه مرتبطة بحساب آخر.' : 'This password is already linked to another account.';
  String tryAgainIn(String formatted) =>
      isAr ? 'أعد المحاولة خلال $formatted' : 'Try again in $formatted';
  String resendInSeconds(int s) =>
      isAr ? 'إعادة الإرسال خلال $sث...' : 'Resend in ${s}s...';

  // ── A5 — Account details screen ───────────────────────────────────────
  String get accountDetailsTitle => isAr ? 'تفاصيل الحساب' : 'ACCOUNT DETAILS';
  String get identity => isAr ? 'الهوية' : 'IDENTITY';
  String get walletSection => isAr ? 'المحفظة' : 'WALLET';
  String get statsSection => isAr ? 'الإحصائيات' : 'STATS';
  String get inventorySection => isAr ? 'المخزون' : 'INVENTORY';
  String get uidLabel => isAr ? 'المعرّف' : 'UID';
  String get emailLabel => isAr ? 'البريد الإلكتروني' : 'Email';
  String get displayNameLabel => isAr ? 'اسم العرض' : 'Display Name';
  String get loginProviderLabel => isAr ? 'طريقة تسجيل الدخول' : 'Login Provider';
  String get emailVerifiedLabel => isAr ? 'البريد موثق' : 'Email Verified';
  String get yesVerified => isAr ? 'نعم ✓' : 'Yes ✓';
  String get notVerifiedLabel => isAr ? 'لا' : 'No';
  String get accountStatusLabel => isAr ? 'حالة الحساب' : 'Account Status';
  String get createdAtLabel => isAr ? 'تاريخ الإنشاء' : 'Created At';
  String get lastLoginLabel => isAr ? 'آخر تسجيل دخول' : 'Last Login';
  String get passwordLabel => isAr ? 'كلمة المرور' : 'Password';
  String get protectedByFirebase =>
      isAr ? 'محمية بـ Firebase Auth — لا تُخزَّن أبداً' : 'Protected by Firebase Auth — never stored';
  String get coinsLabel => isAr ? 'العملات' : 'Coins';
  String get lifetimeEarned => isAr ? 'مكتسب إجمالاً' : 'Lifetime Earned';
  String get lifetimeSpent => isAr ? 'منفق إجمالاً' : 'Lifetime Spent';
  String get gamesPlayedLabel => isAr ? 'الألعاب المُلعوبة' : 'Games Played';
  String get winsLabel => isAr ? 'الانتصارات' : 'Wins';
  String get lossesLabel => isAr ? 'الهزائم' : 'Losses';
  String get drawsLabel => isAr ? 'التعادلات' : 'Draws';
  String get winRateLabel => isAr ? 'نسبة الفوز' : 'Win Rate';
  String get equippedAvatarLabel => isAr ? 'الصورة الرمزية المجهزة' : 'Equipped Avatar';
  String get equippedXSkinLabel => isAr ? 'مظهر X المجهز' : 'Equipped X Skin';
  String get equippedOSkinLabel => isAr ? 'مظهر O المجهز' : 'Equipped O Skin';
  String get ownedAvatarsLabel => isAr ? 'الصور الرمزية المملوكة' : 'Owned Avatars';
  String get ownedXSkinsLabel => isAr ? 'مظاهر X المملوكة' : 'Owned X Skins';
  String get ownedOSkinsLabel => isAr ? 'مظاهر O المملوكة' : 'Owned O Skins';
  String get noneLabel => isAr ? 'لا شيء' : 'None';
  String get recentTransactionsLabel => isAr ? 'المعاملات الأخيرة' : 'RECENT TRANSACTIONS';
  String get unableToLoadTransactions =>
      isAr ? 'تعذّر تحميل المعاملات.' : 'Unable to load transactions.';
  String get noTransactionsYet => isAr ? 'لا توجد معاملات حتى الآن.' : 'No transactions yet.';
  String get matchRewardLabel => isAr ? 'مكافأة مباراة' : 'Match Reward';
  String get coinPurchaseIap => isAr ? 'شراء عملات' : 'Coin Purchase (IAP)';
  String get avatarPurchaseLabel => isAr ? 'شراء صورة رمزية' : 'Avatar Purchase';
  String get xSkinPurchaseLabel => isAr ? 'شراء مظهر X' : 'X Skin Purchase';
  String get oSkinPurchaseLabel => isAr ? 'شراء مظهر O' : 'O Skin Purchase';
  String get adminAdjustmentLabel => isAr ? 'تعديل إداري' : 'Admin Adjustment';
  String get notSignedIn => isAr ? 'لم يتم تسجيل الدخول.' : 'Not signed in.';
  String get errorLoadingAccount =>
      isAr ? 'خطأ في تحميل بيانات الحساب.' : 'Error loading account data.';
  String copiedLabel(String label) => isAr ? 'تم نسخ $label' : '$label copied';
  String itemsOwned(int n) => isAr ? '$n مملوك' : '$n owned';

  // ── A6 — Settings screen ──────────────────────────────────────────────
  String get musicLabel => isAr ? 'الموسيقى' : 'MUSIC';
  String get performanceModeLabel =>
      isAr ? 'وضع الأداء' : 'PERFORMANCE MODE';
  String get performanceModeHint => isAr
      ? 'تقليل المؤثرات والحركات لأداء أنعم'
      : 'Reduce effects and animations for smoother play';

  // ── Missions ──────────────────────────────────────────────────────────
  String get missionsTitle => isAr ? 'المهام' : 'MISSIONS';
  String get playerDefaultName => isAr ? 'اللاعب' : 'PLAYER';
  String get missionsDailyTab => isAr ? 'يومية' : 'DAILY';
  String get missionsWeeklyTab => isAr ? 'أسبوعية' : 'WEEKLY';
  String get missionGo => isAr ? 'اذهب' : 'GO';
  String get missionClaim => isAr ? 'استلام' : 'CLAIM';
  String get missionClaimedDone => isAr ? 'تم' : 'DONE';
  String get missionCompleted => isAr ? 'مكتملة' : 'DONE';
  String get missionViewAll => isAr ? 'عرض الكل' : 'VIEW ALL';
  String get missionsDayDone => isAr ? 'تم إنهاء مهام اليوم' : 'All daily missions done';
  String get missionsWeekDone =>
      isAr ? 'تم إنهاء مهام الأسبوع' : 'All weekly missions done';
  String get missionAlreadyClaimed =>
      isAr ? 'تم استلام المكافأة بالفعل' : 'Reward already claimed';
  String get missionClaimRetry =>
      isAr ? 'غير متاح الآن، حاول لاحقًا' : 'Not available now, try later';
  String get missionRewardClaimed =>
      isAr ? 'تم استلام المكافأة!' : 'Reward claimed!';
  String missionRenewsIn(int days, int hours) => isAr
      ? 'تتجدد خلال $days أيام و $hours ساعات'
      : 'Renews in ${days}d ${hours}h';
  String get playNowBtn => isAr ? 'العب الآن' : 'PLAY NOW';
  String get playOnlineSignInTitle => isAr
      ? 'سجّل الدخول للعب أونلاين مع أصدقائك'
      : 'Sign in to play online with friends';
  String get playVsAiBtn => isAr ? 'العب ضد الذكاء الاصطناعي' : 'Play vs AI';
  String get accountSection => isAr ? 'الحساب' : 'ACCOUNT';
  String get supportAndLegal => isAr ? 'الدعم والقانونية' : 'SUPPORT & LEGAL';
  String get accountDetailsRow => isAr ? 'تفاصيل الحساب' : 'Account Details';
  String get accountDetailsSubtitle =>
      isAr ? 'عرض المعرّف والإحصائيات والمحفظة والمخزون' : 'View UID, stats, wallet, inventory';
  String get changePassword => isAr ? 'تغيير كلمة المرور' : 'Change Password';
  String get changePasswordSubtitle =>
      isAr ? 'تحديث كلمة مرور تسجيل الدخول' : 'Update your login password';
  String get contactSupportRow => isAr ? 'التواصل مع الدعم' : 'Contact Support';
  String get contactSupportSubtitle =>
      isAr ? 'تواصل مع فريق دعم XO ARENA' : 'Reach the XO ARENA support team';
  String get privacyPolicyRow => isAr ? 'سياسة الخصوصية' : 'Privacy Policy';
  String get privacyPolicySubtitle =>
      isAr ? 'اقرأ كيف يتم التعامل مع بياناتك' : 'Read how your data is handled';
  String get termsOfService => isAr ? 'شروط الخدمة' : 'Terms of Service';
  String get termsOfServiceSubtitle =>
      isAr ? 'قواعد اللعبة والشروط القانونية' : 'Game rules and legal terms';
  String get accountDeletionInfo => isAr ? 'معلومات حذف الحساب' : 'Account Deletion Info';
  String get accountDeletionInfoSubtitle =>
      isAr ? 'تعرّف على ما سيتم حذفه نهائياً' : 'Learn what gets removed permanently';
  String get currentPasswordHint => isAr ? 'كلمة المرور الحالية' : 'CURRENT PASSWORD';
  String get newPasswordHint =>
      isAr ? 'كلمة المرور الجديدة (6 أحرف على الأقل)' : 'NEW PASSWORD (MIN 6 CHARS)';
  String get confirmNewPasswordHint =>
      isAr ? 'تأكيد كلمة المرور الجديدة' : 'CONFIRM NEW PASSWORD';
  String get googlePasswordNote =>
      isAr ? 'يتم إدارة كلمات مرور حسابات Google عبر Google.' : 'Google accounts manage passwords through Google.';
  String get changePasswordTitle => isAr ? 'تغيير كلمة المرور' : 'CHANGE PASSWORD';
  String get nameCannotBeEmpty => isAr ? 'الاسم لا يمكن أن يكون فارغاً.' : 'Name cannot be empty.';
  String get nameTooLong20 =>
      isAr ? 'الاسم طويل جداً (الحد الأقصى 20 حرفاً).' : 'Name is too long (max 20 characters).';
  String get nameUpdated => isAr ? 'تم تحديث الاسم!' : 'Name updated!';
  // ── Profile photo (Google-only since 2026-05) ────────────────────────────
  // Custom photo upload was removed in favor of Google Sign-In photoURL only.
  // The strings below are kept for now (marked deprecated) so any leftover
  // compile site still resolves — but no live code path surfaces them.

  /// Helper text shown in Settings explaining that the profile photo comes
  /// from the user's Google account and cannot be edited in-app.
  String get profilePhotoFromGoogle => isAr
      ? 'تتم مزامنة صورة الملف الشخصي من حساب Google.'
      : 'Profile photo is synced from your Google account.';

  @Deprecated('Custom photo upload removed — Google photoURL only.')
  String get imageTooLarge =>
      isAr ? 'الصورة كبيرة جداً (الحد الأقصى 5 ميجابايت)' : 'Image too large (max 5MB)';
  @Deprecated('Custom photo upload removed — Google photoURL only.')
  String get noInternetPhotoSaved =>
      isAr ? 'لا يوجد اتصال. تم حفظ الصورة محلياً.' : 'No internet connection. Photo saved locally.';
  @Deprecated('Custom photo upload removed — Google photoURL only.')
  String get uploadingPhoto => isAr ? 'جارٍ رفع الصورة...' : 'Uploading photo...';
  @Deprecated('Custom photo upload removed — Google photoURL only.')
  String get uploadNotAllowed =>
      isAr ? 'الرفع غير مسموح. تحقق من قواعد التخزين.' : 'Upload not allowed. Please check Storage rules.';
  @Deprecated('Custom photo upload removed — Google photoURL only.')
  String get uploadFailed => isAr ? 'فشل الرفع. حاول مرة أخرى.' : 'Upload failed. Please try again.';
  @Deprecated('Custom photo upload removed — Google photoURL only.')
  String get photoUpdated => isAr ? 'تم تحديث الصورة!' : 'Photo updated!';
  String get couldNotOpenLink => isAr ? 'تعذّر فتح الرابط.' : 'Could not open link.';
  String get mailNotAvailable => isAr ? 'تطبيق البريد غير متاح.' : 'Mail app not available.';
  String get deleteAccountTitle => isAr ? 'حذف الحساب' : 'Delete Account';
  String get deleteAccountReasonPrompt =>
      isAr ? 'يرجى اختيار سبب:' : 'Please select a reason:';
  String get confirmDelete => isAr ? 'تأكيد الحذف' : 'Confirm Delete';
  String get deleteReasonHint => isAr ? 'يرجى وصف سببك...' : 'Please describe your reason...';
  String get dontUseAnymore =>
      isAr ? 'لم أعد أستخدم التطبيق' : 'I don\'t use the app anymore';
  String get foundBetterAlternative =>
      isAr ? 'وجدت بديلاً أفضل' : 'I found a better alternative';
  String get tooBuggy => isAr ? 'كثير من الأخطاء أو التعطلات' : 'Too many bugs or crashes';
  String get privacyConcernsReason => isAr ? 'مخاوف تتعلق بالخصوصية' : 'Privacy concerns';
  String get wantFresh => isAr ? 'أريد البدء من جديد' : 'I want to start fresh';
  String get otherReason => isAr ? 'أخرى (اكتب سببك)' : 'Other (write your reason)';
  String get accountDeletedSuccessfully =>
      isAr ? 'تم حذف الحساب بنجاح.' : 'Account deleted successfully.';
  @Deprecated('Custom photo upload removed — Google photoURL only.')
  String uploadFailedCode(String code) =>
      isAr ? 'فشل الرفع ($code). حاول مرة أخرى.' : 'Upload failed ($code). Please try again.';

  // ── A7 — Store / Coins screen ─────────────────────────────────────────
  String get buyCoins => isAr ? 'شراء العملات' : 'Buy Coins';
  String get noInternetToPurchase =>
      isAr ? 'تحتاج إلى اتصال بالإنترنت لشراء العملات' : 'You need an internet connection to purchase coins';
  String get processingPurchase => isAr ? 'جارٍ معالجة الشراء...' : 'Processing purchase...';
  String get pleaseWait => isAr ? 'يرجى الانتظار' : 'Please wait';
  String get purchaseAlreadyProcessed =>
      isAr ? 'تم معالجة هذا الشراء مسبقاً.' : 'Purchase was already processed.';
  String get purchaseFailedOrCanceled =>
      isAr ? 'فشل الشراء أو تم إلغاؤه.' : 'Purchase failed or canceled.';
  String get coinsAddedToWallet =>
      isAr ? 'نجاح! تمت إضافة العملات إلى محفظتك.' : 'Success! Coins added to your wallet.';
  String get pendingPurchasesChecked =>
      isAr ? 'تم فحص المشتريات المعلقة. تحقق من رصيدك.' : 'Pending purchases checked. Check your balance.';
  String get purchaseTimedOut =>
      isAr ? 'انتهت مهلة الشراء. تحقق من رصيدك أو حاول مرة أخرى.' : 'Purchase timed out. Check your balance or try again.';
  String get createAccountToPurchase =>
      isAr ? 'سجّل حساباً موثقاً في الساحة لشراء حزم العملات.' : 'Register a verified arena account to purchase coin packs.';
  String get storeNotConfigured =>
      isAr ? 'لم يتم تهيئة المتجر بعد. حاول لاحقاً.' : 'Coins store not configured yet. Please try again later.';
  String get checkPendingPurchasesBtn =>
      isAr ? 'التحقق من المشتريات المعلقة' : 'Check pending purchases';
  String get processingLabel => isAr ? 'جارٍ المعالجة...' : 'PROCESSING';
  String get buyNowLabel => isAr ? 'اشترِ الآن' : 'BUY NOW';
  String get noInternetConnectionTitle =>
      isAr ? 'لا يوجد اتصال بالإنترنت' : 'No Internet Connection';
  String get noInternetConnectionDesc => isAr
      ? 'لا يوجد اتصال بالإنترنت.\nاتصل بالإنترنت لشراء العملات.'
      : 'No internet connection.\nConnect to the internet to purchase coins.';
  String coinsAddedDesc(int coins) =>
      isAr ? 'تمت إضافة $coins عملة إلى حسابك' : '$coins coins have been added to your account';
  String newBalanceLabel(int balance) =>
      isAr ? 'الرصيد الجديد: $balance عملة' : 'New balance: $balance coins';
  String checkFailed(String err) => isAr ? 'فشل الفحص: $err' : 'Check failed: $err';

  // ── A8 — Avatar store tab / Main store dialogs ────────────────────────
  String get legendaryAnimated => isAr ? 'أسطوري متحرك' : 'LEGENDARY ANIMATED';
  String get freeUnlockLabel => isAr ? 'فتح مجاني' : 'FREE UNLOCK';
  String get claimBtn => isAr ? 'استلام' : 'CLAIM';
  String get confirmBtn => isAr ? 'تأكيد' : 'CONFIRM';
  String get equippedLabel => isAr ? 'مجهّز' : 'EQUIPPED';
  String get equipLabel => isAr ? 'تجهيز' : 'EQUIP';
  String get unlockFreeLabel => isAr ? 'افتح مجاناً' : 'UNLOCK FREE';
  String get alreadyOwned => isAr ? 'تم الامتلاك مسبقاً!' : 'Already owned!';
  String get avatarGalleryTab => isAr ? 'معرض الصور الرمزية' : 'Avatar Gallery';
  String get notEnoughCoinsTitle => isAr ? 'عملات غير كافية' : 'Not Enough Coins';
  String get unlockXColorTitle => isAr ? 'فتح لون X؟' : 'Unlock X Color?';
  String get unlockOColorTitle => isAr ? 'فتح لون O؟' : 'Unlock O Color?';
  String get purchasedXColor => isAr ? 'تم شراء لون X!' : 'Purchased X color!';
  String get purchasedOColor => isAr ? 'تم شراء لون O!' : 'Purchased O color!';
  String get xColorApplied => isAr ? 'تم تطبيق لون X!' : 'X color applied!';
  String get oColorApplied => isAr ? 'تم تطبيق لون O!' : 'O color applied!';
  String get xSkinEquipped => isAr ? 'تم تجهيز مظهر X!' : 'X Skin equipped!';
  String get oSkinEquipped => isAr ? 'تم تجهيز مظهر O!' : 'O Skin equipped!';
  String get restoredDefaultX => isAr ? 'تمت استعادة X الافتراضي' : 'Restored default X';
  String get xSkinSelectedLabel => isAr ? 'تم اختيار مظهر X!' : 'X Skin selected!';
  String get restoredDefaultO => isAr ? 'تمت استعادة O الافتراضي' : 'Restored default O';
  String get oSkinSelectedLabel => isAr ? 'تم اختيار مظهر O!' : 'O Skin selected!';
  String xoCoinPrice(String price) => isAr ? '$price عملة XO' : '$price XO COINS';
  String buyWithPrice(String price) => isAr ? 'شراء $price' : 'BUY $price';
  String purchasedItemName(String name) => isAr ? 'تم شراء $name!' : 'Purchased $name!';
  String itemEquippedName(String name) => isAr ? 'تم تجهيز $name!' : '$name equipped!';
  String notEnoughCoinsDesc(int required, int current) => isAr
      ? 'تحتاج إلى $required عملة لشراء هذا العنصر.\nرصيدك الحالي $current عملة.'
      : 'You need $required coins to purchase this item.\nYou currently have $current coins.';
  String needMoreCoins(int needed) =>
      isAr ? 'تحتاج $needed عملة إضافية' : 'Need $needed more coins';

  // ── A9 — Intro screen ─────────────────────────────────────────────────
  String get enteringArena => isAr ? 'جارٍ الدخول إلى XO ARENA' : 'ENTERING XO ARENA';
  String get openingArenaHub => isAr ? 'جارٍ فتح مركز الساحة' : 'Opening your arena hub';
  String get openingSignIn => isAr ? 'جارٍ فتح تسجيل الدخول' : 'Opening sign in';
  String get destinationReady =>
      isAr ? 'الوجهة جاهزة. بدء الانتقال' : 'Destination ready. Starting transition';
  String get syncingSession =>
      isAr ? 'مزامنة الجلسة وتحميل الوجهة' : 'Syncing session and loading destination';
  String get preparingStartup =>
      isAr ? 'جارٍ تحضير أنظمة الإطلاق' : 'Preparing startup systems';

  // ── B1 — Exit match dialogs ───────────────────────────────────────────
  String get exitMatchTitle =>
      isAr ? 'الخروج من المباراة؟' : 'Exit Match?';
  String get exitLevelRunTitle =>
      isAr ? 'الخروج من جولة المستوى؟' : 'Exit Level Run?';
  String get exitMatchBody => isAr
      ? 'إذا غادرت الآن فسيتم إنهاء هذه الجولة، وستفقد التقدم الحالي في اللوحة.'
      : 'Leave now and this round will be abandoned. Your current board progress will be lost.';
  String get exitLevelBody => isAr
      ? 'إذا غادرت الآن سيتم إعادة ضبط جولتك الحالية من البداية.'
      : 'Leave now and your current campaign run resets back to the start.';
  String get stayBtn  => isAr ? 'البقاء'  : 'STAY';
  String get leaveBtn => isAr ? 'مغادرة' : 'LEAVE';

  // ── B2 — Match result dialog ──────────────────────────────────────────
  String get matchResolved => isAr ? 'انتهت المباراة'  : 'MATCH RESOLVED';
  String get replayBtn     => isAr ? 'إعادة اللعب'    : 'REPLAY';
  String get restartBtn    => isAr ? 'إعادة البداية'  : 'RESTART';
  String get nextBtn       => isAr ? 'التالي'          : 'NEXT';
  String get homeBtn       => isAr ? 'الرئيسية'        : 'HOME';
  String addedCoins(int n) =>
      isAr ? 'تمت إضافة +$n عملات' : 'Added +$n coins';
  String levelCompleteTitle(int n) =>
      isAr ? 'اكتمل المستوى $n!' : 'LEVEL $n COMPLETE!';
  String startingLevel(int n) =>
      isAr ? 'جارٍ بدء المستوى $n...' : 'Starting level $n...';

  // ── Setup screens shared labels ───────────────────────────────────────
  String get boardSizeLabel => isAr ? 'حجم اللوحة' : 'BOARD SIZE';
  String get chooseSymbol    => isAr ? 'اختر الرمز'    : 'CHOOSE SYMBOL';
  String get coinAmountDesc  => isAr
      ? 'يتم خصم العملات عند بدء المباراة وإعادتها تلقائيًا في حالة التعادل.'
      : 'Funds are deducted when the match begins and refunded automatically on draws.';
  String get orCustomAmount  => isAr ? 'أو أدخل قيمة مخصصة' : 'OR CUSTOM AMOUNT';
  String get enterAmountHint => isAr ? 'أدخل القيمة'         : 'Enter amount';
  String get enterMatch      => isAr ? 'ابدأ المباراة'       : 'ENTER MATCH';
  String get readyLabel      => isAr ? 'جاهز'               : 'READY';
  String get tapToPick       => isAr ? 'اضغط للاختيار'      : 'TAP TO PICK';
  String symbolLabel(String sym) => isAr ? 'الرمز $sym' : 'SYMBOL $sym';

  // ── B4 — Store / Colors tab ───────────────────────────────────────────
  String get xAndOColorsTab => isAr ? 'ألوان X و O' : 'X & O COLORS';
  String get xColorsSection => isAr ? 'ألوان X'     : 'X COLORS';
  String get oColorsSection => isAr ? 'ألوان O'     : 'O COLORS';
  String xColorsSectionCount(int n, int total) =>
      isAr ? 'ألوان X ($n/$total)' : 'X COLORS ($n/$total)';
  String oColorsSectionCount(int n) =>
      isAr ? 'ألوان O ($n)' : 'O COLORS ($n)';
  String get eachColorCosts =>
      isAr ? 'كل لون يكلف 1,000 عملة' : 'Each color costs 1,000 coins';
  String notEnoughCoinsColor(int price) => isAr
      ? 'عملاتك غير كافية — تحتاج $price عملة.'
      : 'Not enough coins — need $price coins.';
  String get selectedBadge => isAr ? 'محدد'   : 'SELECTED';
  String get ownedBadge    => isAr ? 'مملوك'  : 'OWNED';
  String get freeBadge     => isAr ? 'مجاني'  : 'FREE';
  String get noneBadge     => isAr ? 'لا شيء' : 'NONE';
  String xColorsChip(int n) => isAr ? '$n ألوان X' : '$n X COLORS';
  String oColorsChip(int n) => isAr ? '$n ألوان O' : '$n O COLORS';
  String get storeSubtitle  => isAr
      ? 'تصفح الإضافات وجهّز ساحتك.'
      : 'Browse and equip your arena cosmetics.';
  String get avatarGallerySubtitle => isAr
      ? 'جهّز صورتك الرمزية دون ازدحام معرض العرض.'
      : 'Equip premium avatars without crowding the gallery layout.';
  String get buyCoinsSubtitle => isAr
      ? 'أضف عملات إلى محفظتك وعُد إلى المباريات فوراً.'
      : 'Top up your arena wallet and get back into the match flow.';

  // ── B5 — Game HUD / in-match strings ─────────────────────────────────
  String get aiThinking       => isAr ? 'يفكر الذكاء الاصطناعي...' : 'AI THINKING...';
  String get nextTurnLabel    => isAr ? 'التالي:'           : 'NEXT:';
  String get progressLabel    => isAr ? 'التقدم'            : 'PROGRESS';
  String get currentLevelLabel => isAr ? 'المستوى الحالي'  : 'CURRENT LEVEL';

  // ── B6 — Delete account warning ──────────────────────────────────────
  String get deleteAccountWarning => isAr
      ? 'سيتم حذف حسابك وجميع بياناته المرتبطة نهائيًا. لا يمكن التراجع عن هذا الإجراء.'
      : 'This will permanently delete your account and associated data. This action cannot be undone.';

  // ── B7 — Setup / Configuration screens ──────────────────────────────
  String get setupLabel            => isAr ? 'الإعداد'                 : 'SETUP';
  String get soloTraining          => isAr ? 'التدريب الفردي'           : 'SOLO TRAINING';
  String get tacticalSetup         => isAr ? 'الإعداد التكتيكي'         : 'TACTICAL SETUP';
  String get tacticalSetupSubtitle => isAr
      ? 'اختر رمزك، واضبط مستوى الذكاء الاصطناعي، وحدد حجم اللوحة لبدء مباراة نظيفة.'
      : 'Choose your mark, tune the AI pressure, pick the arena size, and launch a clean match.';
  String get difficultyLabel       => isAr ? 'الصعوبة'                 : 'DIFFICULTY';
  String get boardSizeHint         => isAr
      ? 'حجم اللوحة يحدد قاعدة الفوز: 3 أو 4 أو 5 على التوالي.'
      : 'Board size sets the win rule too: 3, 4, or 5 in a row.';
  String get localSetup            => isAr ? 'الإعداد المحلي'           : 'LOCAL SETUP';
  String get localDuel             => isAr ? 'المبارزة المحلية'          : 'LOCAL DUEL';
  String get headToHeadSetup       => isAr ? 'مباراة وجهاً لوجه'        : 'HEAD-TO-HEAD SETUP';
  String get headToHeadSubtitle    => isAr
      ? 'اختر رمز البداية، وحدد حجم اللوحة، وابدأ مباراة على الجهاز نفسه.'
      : 'Pick the opening symbol, scale the board, and launch a same-device match.';
  String get whoStarts             => isAr ? 'من يبدأ؟'                : 'WHO STARTS?';

  // ── B8 — Level game setup screen ─────────────────────────────────────
  String get levelGame             => isAr ? 'لعبة المستويات'           : 'LEVEL GAME';
  String get campaignMode          => isAr ? 'وضع الحملة'               : 'CAMPAIGN MODE';
  String get levelRun              => isAr ? 'جولة المستويات'            : 'LEVEL RUN';
  String get levelRunSubtitle      => isAr
      ? 'أكمل لوحات الساحة المتصاعدة، وحافظ على سلسلتك، واجمع مكافآت المراحل.'
      : 'Clear progressive arena boards, keep your streak alive, and collect milestone payouts.';
  String get rewardsLabel          => isAr ? 'المكافآت'                 : 'REWARDS';
  String get eachLevelCoins        => isAr ? 'كل مستوى: +10 عملات'     : 'Each level: +10 coins';
  String get gridBoard3x3          => isAr ? 'لوحة 3×3'                : '3x3 GRID';
  String get gridBoard4x4          => isAr ? 'لوحة 4×4'                : '4x4 GRID';
  String get gridBoard5x5          => isAr ? 'لوحة 5×5'                : '5x5 GRID';

  // ── B9 — Result modal + setup screen labels ───────────────────────────
  String get youWin            => isAr ? 'لقد فزت!'             : 'YOU WIN!';
  String get youLost           => isAr ? 'لقد خسرت'             : 'YOU LOST';
  String get drawResult        => isAr ? 'تعادل'                 : 'DRAW';
  String xWins(String x)       => isAr ? '$x يفوز'              : '$x WINS';
  String get launchMatch       => isAr ? 'ابدأ المباراة'          : 'LAUNCH MATCH';
  String get lockedIn          => isAr ? 'محدد'                   : 'LOCKED IN';
  String get tapToSelect       => isAr ? 'اضغط للاختيار'         : 'TAP TO SELECT';
  String get easyDifficulty    => isAr ? 'سهل'                   : 'EASY';
  String get mediumDifficulty  => isAr ? 'متوسط'                 : 'MEDIUM';
  String get hardDifficulty    => isAr ? 'صعب'                   : 'HARD';
  String get rarityLegendary   => isAr ? 'أسطوري'                : 'Legendary';
  String get rarityEpic        => isAr ? 'ملحمي'                 : 'Epic';
  String get rarityAnimated    => isAr ? 'متحرك'                 : 'Animated';
  String get maxEntryExceeded  => isAr
      ? 'الحد الأقصى للرهان هو 10,000 عملة.'
      : 'Maximum entry is 10,000 coins.';

  // ── Network / Disconnect overlay ──────────────────────────────────────────
  // connectionLost, switchingToOfflineMode, returningToOnlineAccount already
  // defined in the "Offline / Online transitions" section above.

  String get connectionLostMatchBody => isAr
      ? 'أنت غير متصل. لا يمكن متابعة هذه المباراة المتصلة حتى يعود الاتصال.'
      : 'You are offline. This online match cannot continue until the connection is restored.';

  String get restartInOfflineMode =>
      isAr ? 'إعادة التشغيل بوضع عدم الاتصال' : 'Restart in Offline Mode';

  String get waitForConnection =>
      isAr ? 'انتظار عودة الاتصال' : 'Wait for Connection';

  String get exitToHome =>
      isAr ? 'الخروج للرئيسية' : 'Exit to Home';

  // ── Status badges ─────────────────────────────────────────────────────────
  String get statusOffline => isAr ? 'غير متصل' : 'Offline';
  String get statusOnline  => isAr ? 'متصل'      : 'Online';

  // ── Store item states ─────────────────────────────────────────────────────
  String get storeBuy      => isAr ? 'شراء'    : 'Buy';
  String get storeOwned    => isAr ? 'مملوك'   : 'Owned';
  String get storeEquip    => isAr ? 'تفعيل'   : 'Equip';
  String get storeEquipped => isAr ? 'مُفعّل'  : 'Equipped';

  // ── Coin match validation ─────────────────────────────────────────────────
  String get enterValidAmount    => isAr ? 'أدخل قيمة صحيحة.'       : 'Enter a valid amount.';
  String get entryAmountTooHigh  => isAr ? 'قيمة الدخول كبيرة جدًا.' : 'Entry amount is too high.';
  String get notEnoughCoins      => isAr ? 'ليس لديك عملات كافية.'   : 'You do not have enough coins.';

  // ── Match interruption ────────────────────────────────────────────────────
  String get matchInterrupted    => isAr ? 'تم قطع المباراة'         : 'Match interrupted';
  String get noResultCalculated  => isAr ? 'لم يتم احتساب نتيجة'    : 'No result was calculated';

  // ── Avatar unequip ────────────────────────────────────────────────────────
  String get avatarUnequipped    => isAr ? 'تم إلغاء تفعيل الصورة الرمزية' : 'Avatar unequipped';

  // ── Connection problem overlay (general — not match-specific) ─────────────

  /// Title for the full-screen "no internet" overlay.
  String get connectionProblemTitle => isAr
      ? 'مشكلة في الاتصال'
      : 'Connection Problem';

  /// Body text explaining that online play cannot continue safely.
  String get connectionProblemBody => isAr
      ? 'اتصال الإنترنت ضعيف أو غير متصل.\nلا يمكن متابعة اللعب المتصل بأمان.\nللعب بدون اتصال، أعد تشغيل اللعبة في وضع عدم الاتصال.'
      : 'Your internet connection is weak or disconnected.\nOnline gameplay cannot continue safely.\nTo play offline, restart the game in Offline Mode.';

  /// Shown while the app loads the offline profile after a restart.
  String get loadingOfflineProfile => isAr
      ? 'جارٍ تحميل ملف عدم الاتصال...'
      : 'Loading offline profile...';

  /// Badge label shown on the avatar / home screen when in offline guest mode.
  String get offlineGuestBadge => isAr ? 'ضيف • غير متصل' : 'GUEST • OFFLINE';

  /// Shown when a match was cleanly abandoned before switching to offline.
  String get matchAbandonedSafely => isAr
      ? 'تم إنهاء المباراة بأمان. لم يتم احتساب أي نتيجة.'
      : 'Match ended safely. No result was calculated.';

  /// Short label for the offline mode state.
  String get offlineModeLabel => isAr ? 'وضع عدم الاتصال' : 'Offline Mode';

  /// Shown in the reconnect snackbar after "Wait for Connection" succeeds.
  String get returnedToOnlineAccount => isAr
      ? 'جارٍ الرجوع إلى الحساب المتصل.'
      : 'Returning to your online account.';

  // ── Weak Connection overlay (non-match, home / store / settings) ──────────

  String get weakConnectionTitle =>
      isAr ? 'الاتصال ضعيف' : 'Weak Connection';

  String get weakConnectionBody => isAr
      ? 'أنت غير متصل الآن.\nلا يمكن متابعة اللعب المتصل بأمان.\nأعد التشغيل في وضع الأوفلاين للمتابعة باستخدام البيانات المحلية فقط.'
      : 'You are offline now.\nOnline gameplay cannot continue safely.\nRestart in Offline Mode to continue using local data only.';

  String get tryReconnect =>
      isAr ? 'محاولة إعادة الاتصال' : 'Try Reconnect';

  String get tryingToReconnect =>
      isAr ? 'جاري محاولة إعادة الاتصال...' : 'Trying to reconnect...';

  String get connectionStillUnavailable => isAr
      ? 'لا يزال الاتصال غير متاح.'
      : 'Connection is still unavailable.';

  String get modeRequiresStableInternet => isAr
      ? 'يتطلب هذا النمط اتصالًا ثابتًا بالإنترنت.'
      : 'This mode requires a stable internet connection.';

  // ── Image picker messages ─────────────────────────────────────────────────

  String get imagePickerAlreadyOpen =>
      isAr ? 'منتقي الصور مفتوح بالفعل.' : 'Image picker is already open.';

  String get permissionDenied =>
      isAr ? 'تم رفض الإذن.' : 'Permission denied.';

  String get profileImageUpdated => isAr
      ? 'تم تحديث صورة الملف الشخصي.'
      : 'Profile image updated.';

  // ── Auth / store extra messages ───────────────────────────────────────────

  String get noAuthenticatedUser =>
      isAr ? 'لا يوجد مستخدم مسجل' : 'No authenticated user';

  String get pleaseSignInAgain =>
      isAr ? 'يرجى تسجيل الدخول مرة أخرى' : 'Please sign in again';

  String get avatarMustBePurchasedFirst => isAr
      ? 'يجب شراء الصورة الرمزية أولًا'
      : 'Avatar must be purchased first';

  String get noAvatarSelected =>
      isAr ? 'لا توجد صورة رمزية محددة' : 'No avatar selected';

  String get itemNotOwned =>
      isAr ? 'هذا العنصر غير مملوك' : 'This item is not owned';

  String get unequip => isAr ? 'إلغاء التفعيل' : 'Unequip';

  // ── Online switch confirmation overlay ────────────────────────────────────

  String get goOnlineTitle =>
      isAr ? 'الدخول إلى وضع الاتصال؟' : 'Go Online?';

  String get goOnlineBody => isAr
      ? 'عاد الاتصال بالإنترنت.\nهل تريد الانتقال إلى وضع الاتصال؟\nستبقى عملات وتقدم الأوفلاين محفوظة محليًا ولن يتم دمجها مع حسابك المتصل.'
      : 'Your connection is back.\nDo you want to switch to Online Mode?\nYour offline coins and progress will stay saved locally and will not be merged with your online account.';

  String get goOnlinePrimary =>
      isAr ? 'الدخول أونلاين' : 'Go Online';

  String get stayOffline =>
      isAr ? 'البقاء أوفلاين' : 'Stay Offline';

  // ── Arena (private friend rooms) ───────────────────────────────────────
  String get arenaTab => isAr ? 'الساحة' : 'Arena';
  String get inviteFriendsTitle => isAr ? 'دعوة الأصدقاء' : 'Invite Friends';
  String get inviteFriendsBody => isAr
      ? 'ادعو 10 من أصدقائك واكسب 1000 كوين.\nتكسب 100 كوين عن كل صديق جديد يدخل كود الدعوة الخاص بك.'
      : 'Invite 10 friends and earn 1000 coins.\nYou earn 100 coins for each new friend who enters your invite code.';
  String get shareInvite => isAr ? 'مشاركة الدعوة' : 'Share Invite';
  String get enterInviteCode => isAr ? 'إدخال كود الدعوة' : 'Enter Invite Code';
  String get playWithFriend => isAr ? 'العب مع صديق' : 'Play With Friend';
  String get createRoom => isAr ? 'إنشاء روم' : 'Create Room';
  String get joinRoom => isAr ? 'دخول روم' : 'Join Room';
  String get roomCode => isAr ? 'كود الروم' : 'Room Code';
  String get rounds => isAr ? 'الجولات' : 'Rounds';
  String get boardLabel => isAr ? 'الخريطة' : 'Board';
  String get notReadyLabel => isAr ? 'غير جاهز' : 'Not Ready';
  String get startRoom => isAr ? 'بدء الروم' : 'Start Room';
  String get shareRoom => isAr ? 'مشاركة الروم' : 'Share Room';
  String get waitingForFriend => isAr ? 'في انتظار صديقك' : 'Waiting for friend';
  String get leaveRoom => isAr ? 'مغادرة الروم' : 'Leave Room';
  String get cancelRoom => isAr ? 'إلغاء الروم' : 'Cancel Room';
  String get roomNotFound => isAr ? 'الروم غير موجود.' : 'Room not found.';
  String get roomIsFull => isAr ? 'الروم ممتلئ.' : 'Room is full.';
  String get roomExpired => isAr ? 'انتهت صلاحية الروم.' : 'Room expired.';
  String get cantJoinOwnRoom => isAr
      ? 'لا يمكنك دخول الروم الخاص بك كلاعب ثاني.'
      : 'You cannot join your own room.';
  String get alreadyInActiveRoom => isAr
      ? 'أنت بالفعل داخل روم نشط.'
      : 'You are already in an active room.';
  String get drawReplayRound => isAr
      ? 'تعادل! سيتم إعادة نفس الجولة.'
      : 'Draw! Replay this round.';
  String get opponentLeftYouWin => isAr
      ? 'غادر الخصم الروم. لقد فزت.'
      : 'Opponent left the room. You win.';
  String get leaveCountsAsLoss => isAr
      ? 'إذا خرجت الآن سيتم احتسابها خسارة. هل تريد المتابعة؟'
      : 'Leaving now will count as a loss. Continue?';
  String get leaveRoomTitle => isAr ? 'مغادرة الروم؟' : 'Leave Room?';
  String get leaveRoomConfirm => isAr
      ? 'هل أنت متأكد أنك تريد الخروج؟'
      : 'Are you sure you want to leave?';
  String get cancelRoomTitle => isAr ? 'إلغاء الروم؟' : 'Cancel Room?';
  String get cancelRoomConfirm => isAr
      ? 'سيتم إلغاء الروم وخروج جميع اللاعبين. هل تريد المتابعة؟'
      : 'The room will be cancelled and all players removed. Continue?';
  String get fightWord => isAr ? 'ابدأ' : 'Fight';
  String get keypadDelete => isAr ? 'مسح' : 'Delete';
  String get keypadEnter => isAr ? 'دخول' : 'Enter';
  String get hostLabel => isAr ? 'المضيف' : 'Host';
  String get guestLabel => isAr ? 'الضيف' : 'Guest';
  String get timeLeftLabel => isAr ? 'الوقت المتبقي' : 'Time left';
  String get copyCode => isAr ? 'نسخ الكود' : 'Copy Code';
  String get codeCopied => isAr ? 'تم نسخ الكود' : 'Code copied';
  String get currentRoundLabel => isAr ? 'الجولة' : 'Round';
  String get roomLabel => isAr ? 'الروم' : 'Room';
  String get prizeLabel => isAr ? 'الجائزة' : 'Prize';
  String get coinsWord => isAr ? 'كوين' : 'coins';
  String get yourTurn => isAr ? 'دورك' : 'Your turn';
  String get opponentTurn => isAr ? 'دور الخصم' : 'Opponent turn';
  String get youWon => isAr ? 'لقد فزت!' : 'You won!';
  String get roomFinished => isAr ? 'انتهى الروم' : 'Room finished';
  String get notEnoughCoinsCreate => isAr
      ? 'لا تمتلك كوينات كافية لإنشاء هذا الروم.'
      : 'Not enough coins to create this room.';
  String get notEnoughCoinsJoin => isAr
      ? 'لا تملك كوينات كافية لدخول هذا الروم.'
      : 'You do not have enough coins to join this room.';
  String get opponentNotEnoughCoins => isAr
      ? 'لا يمتلك الخصم كوينات كافية للرهان.'
      : 'Opponent does not have enough coins.';
  String get playWithCoins => isAr ? 'اللعب بالكوينز' : 'Play with Coins';
  String get betAmount => isAr ? 'قيمة الرهان' : 'Bet Amount';
  String get yourCoins => isAr ? 'كوينزك' : 'Your Coins';
  String get perRoundMaps => isAr ? 'خرائط الجولات' : 'Per-round maps';
  String get mapsLabel => isAr ? 'الخرائط' : 'Maps';
  String get roomSummary => isAr ? 'ملخص الروم' : 'Room Summary';
  String get copiedToClipboard => isAr
      ? 'تم نسخ النص.'
      : 'Copied to clipboard.';
  String get referralCompletedShort => isAr ? 'مكتمل' : 'Completed';
  String get yourInviteCode => isAr ? 'كود الدعوة الخاص بك' : 'Your invite code';
  String get referralProgress => isAr ? 'تقدم الدعوات' : 'Referral progress';
  String get referralCompleted => isAr
      ? 'لقد أكملت كل المكافآت! شكراً لك.'
      : 'You have unlocked all rewards. Thank you!';
  String get referralEarned => isAr ? 'الكوينات المكتسبة' : 'Coins earned';
  String get enterInviteCodeTitle => isAr ? 'أدخل كود الدعوة' : 'Enter Invite Code';
  String get referralCodeMustBe9 => isAr
      ? 'كود الدعوة يجب أن يكون 9 أرقام.'
      : 'Invite code must be 9 digits.';
  String get referralCantUseOwn => isAr
      ? 'لا يمكنك استخدام كود الدعوة الخاص بك.'
      : 'You cannot use your own invite code.';
  String get referralAlreadyUsed => isAr
      ? 'لقد استخدمت كود دعوة من قبل.'
      : 'You have already used an invite code.';
  String get referralCodeInvalid => isAr
      ? 'كود الدعوة غير صحيح.'
      : 'Invalid invite code.';
  String get referralCodeNotFound => isAr
      ? 'كود الدعوة غير موجود.'
      : 'Invite code not found.';
  String get referralRedeemError => isAr
      ? 'لم يتم استخدام كود الدعوة. حاول مرة أخرى.'
      : 'Could not redeem invite code. Please try again.';
  String get giftClaimed => isAr ? 'تم استلام الهدية!' : 'Gift Claimed!';
  String referralReceivedCoins(int coins, String name) => isAr
      ? 'حصلت على $coins كوينز من $name'
      : 'You received $coins coins from $name';
  String get shareYourCode => isAr
      ? 'شارك كودك مع أصدقائك أيضاً!'
      : 'Share your code with friends too!';
  String get myInviteCode => isAr ? 'كود الدعوة الخاص بي' : 'My Invite Code';
  String get pasteCode => isAr ? 'لصق' : 'Paste';
  String get clipboardNoValidInviteCode => isAr
      ? 'الحافظة لا تحتوي على كود دعوة صالح'
      : 'Clipboard does not contain a valid invite code';
  String get clipboardNoValidRoomCode => isAr
      ? 'الحافظة لا تحتوي على كود غرفة صالح'
      : 'Clipboard does not contain a valid room code';
  String get referralNotEligible => isAr
      ? 'كود الدعوة متاح فقط للمستخدمين الجدد.'
      : 'Invite code is only available for new users.';
  String get referralSuccess => isAr
      ? 'تم تطبيق كود الدعوة بنجاح!'
      : 'Invite code applied successfully!';
  String get arenaOnlineOnly => isAr
      ? 'الساحة متاحة فقط في وضع الاتصال.'
      : 'Arena is available in Online Mode only.';
  String get pendingRewardCredited => isAr
      ? 'تم استلام مكافأة الدعوة!'
      : 'Invite reward received!';

  // ── Arena match screen (in-game UI) ───────────────────────────────────
  /// Small banner that appears in the arena match when the RTDB connection
  /// is briefly lost. Kept short so it fits the floating chip layout.
  String get reconnectingShort =>
      isAr ? 'جارٍ إعادة الاتصال…' : 'Reconnecting…';

  /// Header above the round counter on the arena game screen.
  String get roundWord => isAr ? 'الجولة' : 'ROUND';

  /// Small badge next to the local player's name.
  String get youTag => isAr ? 'أنت' : 'YOU';

  /// "YOUR MARK" label above the equipped X/O preview in the self card.
  String get yourMarkLabel => isAr ? 'علامتك' : 'YOUR MARK';

  /// "OPP MARK" label above the equipped X/O preview in the opponent card.
  String get oppMarkLabel => isAr ? 'علامة الخصم' : 'OPP MARK';

  /// Button on the end-of-match dialog that returns to the arena hub.
  String get backToArena => isAr ? 'العودة للساحة' : 'BACK TO ARENA';

  /// Round-end banner (self winner).
  String get roundWonBanner => isAr ? 'فزت بالجولة' : 'ROUND WON';

  /// Round-end banner (opponent winner).
  String get roundLostBanner => isAr ? 'خسرت الجولة' : 'ROUND LOST';

  /// Round-end / match-end short "DRAW" headline (the longer form is
  /// [drawResult] — kept distinct for visual hierarchy in the final dialog).
  String get drawShort => isAr ? 'تعادل' : 'DRAW';

  /// Gold "+N coins" badge shown when a bet payout was credited.
  String coinsWonBadge(int coins) =>
      isAr ? '+$coins كوينز' : '+$coins coins';

  // ── Settings — additional localized labels ────────────────────────────
  /// Title of the legacy Privacy & Terms dialog.
  String get privacyAndTerms => isAr ? 'الخصوصية والشروط' : 'PRIVACY & TERMS';

  /// Title of the Contact Support / Refunds dialog.
  String get contactSupportTitle =>
      isAr ? 'التواصل مع الدعم' : 'Contact Support / Refunds';

  /// Send Email button label in the Contact Support dialog.
  String get sendEmailBtn => isAr ? 'إرسال بريد' : 'Send email';

  /// Tile label for the new web Contact link (settings → Support & Legal).
  String get contactLinkLabel => isAr ? 'تواصل معنا' : 'Contact';

  /// Tile subtitle for the new Contact tile.
  String get contactLinkSubtitle =>
      isAr ? 'افتح صفحة التواصل على الويب' : 'Open the contact page on the web';

  /// Shown when re-authentication for account deletion fails.
  String get reauthFailedRetry => isAr
      ? 'فشل التحقق من الهوية. حاول مرة أخرى.'
      : 'Re-authentication failed. Please try again.';

  // ── Referral additions ────────────────────────────────────────────────
  /// Shown when the invite code page fails to load after retries.
  String get referralLoadFailed => isAr
      ? 'تعذّر تحميل كود الدعوة الخاص بك.'
      : "Couldn't load your invite code.";

  /// Generic network-error message shown by referral actions on timeout / no
  /// connectivity.
  String get referralNetworkError => isAr
      ? 'خطأ في الشبكة. تحقق من الاتصال وحاول مرة أخرى.'
      : 'Network error. Please check your connection and try again.';

  /// Bilingual invite-share message (Arabic + English in a single blob).
  String inviteShareMessage(String referralCode) =>
      'انضم إلى XO Arena واستخدم كود الدعوة الخاص بي: $referralCode\n'
      'كل لاعب جديد يساعدني أكسب مكافآت داخل اللعبة!\n\n'
      '--------------------\n\n'
      'Join XO Arena and use my invite code: $referralCode\n'
      'Help me earn rewards and start playing XO Arena!';

  /// Bilingual room-share message (Arabic + English in a single blob).
  String roomShareMessage({
    required String roomCode,
    required int roundCount,
    required String maps,
    required bool betEnabled,
    required int betAmount,
    required int prizePool,
  }) {
    final betAr = betEnabled
        ? '$betAmount كوين لكل لاعب — الجائزة $prizePool كوين'
        : 'بدون رهان';
    final betEn = betEnabled
        ? '$betAmount coins each — Prize $prizePool coins'
        : 'Off';
    return 'تعالى العب معي في XO Arena\n'
        'كود الروم: $roomCode\n'
        'الجولات: $roundCount\n'
        'الخرائط: $maps\n'
        'الرهان: $betAr\n\n'
        '--------------------\n\n'
        'Play XO Arena with me!\n'
        'Room code: $roomCode\n'
        'Rounds: $roundCount\n'
        'Maps: $maps\n'
        'Bet: $betEn';
  }
}

// ── Localizations delegate ─────────────────────────────────────────────────

class AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const AppL10nDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppL10n> load(Locale locale) =>
      SynchronousFuture<AppL10n>(AppL10n(locale.languageCode));

  @override
  bool shouldReload(AppL10nDelegate old) => false;
}
