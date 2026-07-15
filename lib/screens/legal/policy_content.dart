/// Which legal document a [PolicyPage] renders.
enum PolicyDoc { accountDeletion, terms, privacy }

/// A single titled section of a policy document.
class PolicySection {
  final String heading;
  final String body;
  const PolicySection({required this.heading, required this.body});
}

/// A full policy document ready to render.
class PolicyDocData {
  final String appBarTitle;
  final String title;
  final String lastUpdated;
  final List<PolicySection> sections;

  const PolicyDocData({
    required this.appBarTitle,
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });
}

/// In-app legal content for XO Arena in English and Arabic.
///
/// This is the single source of truth for the Account Deletion, Terms of
/// Service and Privacy Policy pages — no external Google Sites links are used.
/// Copy is intentionally plain-language and can be edited by the project owner.
class PolicyContent {
  PolicyContent._();

  static PolicyDocData forDoc(PolicyDoc doc, bool isAr) {
    switch (doc) {
      case PolicyDoc.accountDeletion:
        return isAr ? _accountDeletionAr : _accountDeletionEn;
      case PolicyDoc.terms:
        return isAr ? _termsAr : _termsEn;
      case PolicyDoc.privacy:
        return isAr ? _privacyAr : _privacyEn;
    }
  }

  // ═══════════════════════════ ACCOUNT DELETION ═══════════════════════════

  static const _accountDeletionEn = PolicyDocData(
    appBarTitle: 'ACCOUNT DELETION',
    title: 'Account and Data Deletion for XO Arena',
    lastUpdated: 'Last updated: May 20, 2026',
    sections: [
      PolicySection(
        heading: '',
        body:
            'XO Arena allows users to request deletion of their account and associated data.',
      ),
      PolicySection(
        heading: 'In-App Deletion Method',
        body: 'You can request account deletion inside the app:\n'
            '1. Open XO Arena\n'
            '2. Go to Settings\n'
            '3. Tap Delete Account\n'
            '4. Confirm your request',
      ),
      PolicySection(
        heading: 'Web Deletion Request',
        body: 'If you cannot access the app, you can request deletion by email.\n\n'
            'Send an email to:\n'
            'xandomanger@gmail.com\n\n'
            'Email subject:\n'
            'XO Arena Account Deletion Request\n\n'
            'Please include:\n'
            '- Your account email\n'
            '- Your in-game name, if available\n'
            '- Your user ID, if available\n'
            '- A clear request to delete your XO Arena account',
      ),
      PolicySection(
        heading: 'What Data May Be Deleted',
        body:
            'We will delete or anonymize account-related data where reasonably possible, including:\n'
            '- Account profile data\n'
            '- Game progress\n'
            '- Coins balance\n'
            '- Unlocked cosmetic items\n'
            '- Referral data\n'
            '- Online match history linked to your account',
      ),
      PolicySection(
        heading: 'Data That May Be Retained',
        body: 'Some data may be retained if needed for:\n'
            '- Fraud prevention\n'
            '- Purchase verification\n'
            '- Security logs\n'
            '- Legal obligations\n'
            '- Abuse investigation\n'
            '- Financial transaction records',
      ),
      PolicySection(
        heading: 'Processing Time',
        body:
            'We aim to process deletion requests within a reasonable time after verifying the request.',
      ),
      PolicySection(
        heading: 'Contact',
        body: 'For account deletion questions, contact:\n'
            'adminarena77@gmail.com',
      ),
    ],
  );

  static const _accountDeletionAr = PolicyDocData(
    appBarTitle: 'حذف الحساب',
    title: 'حذف الحساب والبيانات في XO Arena',
    lastUpdated: 'آخر تحديث: 20 مايو 2026',
    sections: [
      PolicySection(
        heading: '',
        body:
            'يتيح تطبيق XO Arena للمستخدمين طلب حذف حساباتهم والبيانات المرتبطة بها.',
      ),
      PolicySection(
        heading: 'الحذف من داخل التطبيق',
        body: 'يمكنك طلب حذف الحساب من داخل التطبيق:\n'
            '1. افتح XO Arena\n'
            '2. اذهب إلى الإعدادات\n'
            '3. اضغط على حذف الحساب\n'
            '4. أكِّد طلبك',
      ),
      PolicySection(
        heading: 'طلب الحذف عبر الويب',
        body: 'إذا تعذّر عليك الوصول إلى التطبيق، يمكنك طلب الحذف عبر البريد الإلكتروني.\n\n'
            'أرسل بريدًا إلى:\n'
            'xandomanger@gmail.com\n\n'
            'عنوان الرسالة:\n'
            'XO Arena Account Deletion Request\n\n'
            'يرجى تضمين:\n'
            '- بريد حسابك الإلكتروني\n'
            '- اسمك داخل اللعبة، إن وُجد\n'
            '- معرّف المستخدم الخاص بك، إن وُجد\n'
            '- طلب واضح بحذف حسابك في XO Arena',
      ),
      PolicySection(
        heading: 'البيانات التي قد تُحذف',
        body: 'سنحذف أو نُخفي هوية البيانات المرتبطة بالحساب قدر الإمكان، وتشمل:\n'
            '- بيانات ملف الحساب\n'
            '- تقدّم اللعب\n'
            '- رصيد العملات\n'
            '- العناصر التجميلية المفتوحة\n'
            '- بيانات الإحالة\n'
            '- سجل المباريات المرتبط بحسابك',
      ),
      PolicySection(
        heading: 'البيانات التي قد تُحتفظ بها',
        body: 'قد يتم الاحتفاظ ببعض البيانات إذا لزم الأمر من أجل:\n'
            '- منع الاحتيال\n'
            '- التحقق من المشتريات\n'
            '- سجلات الأمان\n'
            '- الالتزامات القانونية\n'
            '- التحقيق في إساءة الاستخدام\n'
            '- سجلات المعاملات المالية',
      ),
      PolicySection(
        heading: 'مدة المعالجة',
        body:
            'نهدف إلى معالجة طلبات الحذف خلال مدة معقولة بعد التحقق من الطلب.',
      ),
      PolicySection(
        heading: 'التواصل',
        body: 'للاستفسارات حول حذف الحساب، تواصل مع:\n'
            'adminarena77@gmail.com',
      ),
    ],
  );

  // ═══════════════════════════════ TERMS ══════════════════════════════════

  static const _termsEn = PolicyDocData(
    appBarTitle: 'TERMS OF SERVICE',
    title: 'Terms of Service for XO Arena',
    lastUpdated: 'Last updated: May 20, 2026',
    sections: [
      PolicySection(
        heading: '1. About XO Arena',
        body:
            'XO Arena is a tic-tac-toe arena game where users can play online matches, create rooms, join rooms, use coins, unlock cosmetic items, use avatar frames, and invite friends.',
      ),
      PolicySection(
        heading: '2. User Accounts',
        body: 'Users may need to sign in to use online features.\n'
            'You are responsible for keeping your account secure. Do not share your account with others.\n'
            'We may suspend or restrict accounts that abuse the app, cheat, exploit bugs, manipulate coins, or violate these Terms.',
      ),
      PolicySection(
        heading: '3. Fair Play',
        body: 'Users must not:\n'
            '- Cheat\n'
            '- Use modified versions of the app\n'
            '- Abuse bugs\n'
            '- Manipulate coins or rewards\n'
            '- Use automation or bots\n'
            '- Harass other users\n'
            "- Attempt to access another user's account\n"
            '- Attempt to damage or overload our systems',
      ),
      PolicySection(
        heading: '4. Coins and Virtual Items',
        body:
            'XO Arena may include virtual coins, skins, avatar frames, emojis, and other virtual items.\n'
            'Coins and virtual items:\n'
            '- Are for use only inside XO Arena\n'
            '- Do not represent real money\n'
            '- Cannot be sold, traded, or exchanged outside the app\n'
            '- May be changed, limited, or removed if abuse or fraud is detected',
      ),
      PolicySection(
        heading: '5. In-App Purchases',
        body: 'XO Arena may offer in-app purchases through Google Play.\n'
            'Purchases are processed by Google Play. Refunds are handled according to Google Play policies.\n'
            'If a purchase does not appear in your account, contact us with your purchase details.',
      ),
      PolicySection(
        heading: '6. Referral Rewards',
        body: 'XO Arena may offer referral rewards.\n'
            'Referral rewards may be limited to one use per account or device. We may reject or remove rewards if fraud, fake accounts, abuse, or suspicious behavior is detected.',
      ),
      PolicySection(
        heading: '7. Online Rooms',
        body: 'Users can create and join online rooms.\n'
            'Room data may include player IDs, names, profile photos, selected cosmetics, moves, scores, and results.\n'
            'Leaving a match may count as a loss or forfeit depending on the game rules.',
      ),
      PolicySection(
        heading: '8. Account Deletion',
        body:
            'Users can request account deletion from inside the app or through the Account Deletion page.\n'
            'Some records may be retained where required for fraud prevention, purchase verification, security, or legal reasons.',
      ),
      PolicySection(
        heading: '9. App Changes',
        body: 'We may update, modify, add, or remove features at any time.\n'
            'We may also change balancing, coin rewards, item prices, or game rules to improve the app and prevent abuse.',
      ),
      PolicySection(
        heading: '10. No Warranty',
        body:
            'XO Arena is provided as-is. We try to keep the app stable and secure, but we do not guarantee that the app will always be available, error-free, or uninterrupted.',
      ),
      PolicySection(
        heading: '11. Limitation of Liability',
        body:
            'To the maximum extent allowed by law, we are not responsible for indirect losses, lost progress caused by unauthorized account access, device issues, network problems, or third-party service interruptions.',
      ),
      PolicySection(
        heading: '12. Contact',
        body: 'For support or questions, contact:\n'
            'adminarena77@gmail.com',
      ),
    ],
  );

  static const _termsAr = PolicyDocData(
    appBarTitle: 'شروط الخدمة',
    title: 'شروط الخدمة لتطبيق XO Arena',
    lastUpdated: 'آخر تحديث: 20 مايو 2026',
    sections: [
      PolicySection(
        heading: '1. عن XO Arena',
        body:
            'XO Arena هي لعبة ساحة إكس-أو (تيك-تاك-تو) حيث يمكن للمستخدمين لعب مباريات أونلاين، وإنشاء الغرف، والانضمام إليها، واستخدام العملات، وفتح العناصر التجميلية، واستخدام إطارات الصور الرمزية، ودعوة الأصدقاء.',
      ),
      PolicySection(
        heading: '2. حسابات المستخدمين',
        body: 'قد يحتاج المستخدمون لتسجيل الدخول لاستخدام الميزات الأونلاين.\n'
            'أنت مسؤول عن الحفاظ على أمان حسابك. لا تشارك حسابك مع الآخرين.\n'
            'قد نوقف أو نقيّد الحسابات التي تسيء استخدام التطبيق، أو تغش، أو تستغل الأخطاء، أو تتلاعب بالعملات، أو تخالف هذه الشروط.',
      ),
      PolicySection(
        heading: '3. اللعب النزيه',
        body: 'يجب على المستخدمين عدم:\n'
            '- الغش\n'
            '- استخدام نسخ معدّلة من التطبيق\n'
            '- استغلال الأخطاء\n'
            '- التلاعب بالعملات أو المكافآت\n'
            '- استخدام الأتمتة أو الروبوتات\n'
            '- مضايقة المستخدمين الآخرين\n'
            '- محاولة الوصول إلى حساب مستخدم آخر\n'
            '- محاولة إلحاق الضرر بأنظمتنا أو إثقالها',
      ),
      PolicySection(
        heading: '4. العملات والعناصر الافتراضية',
        body:
            'قد يتضمن XO Arena عملات افتراضية، وسكِنات، وإطارات صور رمزية، وإيموجي، وعناصر افتراضية أخرى.\n'
            'العملات والعناصر الافتراضية:\n'
            '- مخصّصة للاستخدام داخل XO Arena فقط\n'
            '- لا تمثّل أموالًا حقيقية\n'
            '- لا يمكن بيعها أو تداولها أو استبدالها خارج التطبيق\n'
            '- قد تُغيَّر أو تُقيَّد أو تُزال عند اكتشاف إساءة استخدام أو احتيال',
      ),
      PolicySection(
        heading: '5. المشتريات داخل التطبيق',
        body: 'قد يقدّم XO Arena مشتريات داخل التطبيق عبر Google Play.\n'
            'تتم معالجة المشتريات بواسطة Google Play. وتُعالَج عمليات الاسترداد وفقًا لسياسات Google Play.\n'
            'إذا لم تظهر عملية شراء في حسابك، تواصل معنا مع تفاصيل الشراء.',
      ),
      PolicySection(
        heading: '6. مكافآت الإحالة',
        body: 'قد يقدّم XO Arena مكافآت إحالة.\n'
            'قد تقتصر مكافآت الإحالة على استخدام واحد لكل حساب أو جهاز. وقد نرفض أو نزيل المكافآت عند اكتشاف احتيال أو حسابات وهمية أو إساءة استخدام أو سلوك مريب.',
      ),
      PolicySection(
        heading: '7. الغرف الأونلاين',
        body: 'يمكن للمستخدمين إنشاء الغرف الأونلاين والانضمام إليها.\n'
            'قد تتضمن بيانات الغرفة معرّفات اللاعبين، والأسماء، وصور الملف، والعناصر التجميلية المختارة، والحركات، والنتائج.\n'
            'قد يُحتسب مغادرة المباراة خسارة أو انسحابًا حسب قواعد اللعبة.',
      ),
      PolicySection(
        heading: '8. حذف الحساب',
        body:
            'يمكن للمستخدمين طلب حذف الحساب من داخل التطبيق أو من صفحة حذف الحساب.\n'
            'قد يتم الاحتفاظ ببعض السجلات عند الحاجة لمنع الاحتيال، أو التحقق من المشتريات، أو الأمان، أو لأسباب قانونية.',
      ),
      PolicySection(
        heading: '9. تغييرات التطبيق',
        body: 'قد نقوم بتحديث أو تعديل أو إضافة أو إزالة الميزات في أي وقت.\n'
            'وقد نغيّر أيضًا التوازن، أو مكافآت العملات، أو أسعار العناصر، أو قواعد اللعبة لتحسين التطبيق ومنع إساءة الاستخدام.',
      ),
      PolicySection(
        heading: '10. إخلاء الضمان',
        body:
            'يُقدَّم XO Arena "كما هو". نحاول إبقاء التطبيق مستقرًا وآمنًا، لكننا لا نضمن أن يكون التطبيق متاحًا دائمًا أو خاليًا من الأخطاء أو دون انقطاع.',
      ),
      PolicySection(
        heading: '11. حدود المسؤولية',
        body:
            'إلى أقصى حد يسمح به القانون، لسنا مسؤولين عن الخسائر غير المباشرة، أو فقدان التقدّم الناتج عن وصول غير مصرّح به للحساب، أو مشاكل الجهاز، أو مشاكل الشبكة، أو انقطاع خدمات الأطراف الثالثة.',
      ),
      PolicySection(
        heading: '12. التواصل',
        body: 'للدعم أو الاستفسارات، تواصل مع:\n'
            'adminarena77@gmail.com',
      ),
    ],
  );

  // ══════════════════════════════ PRIVACY ═════════════════════════════════

  static const _privacyEn = PolicyDocData(
    appBarTitle: 'PRIVACY POLICY',
    title: 'Privacy Policy for XO Arena',
    lastUpdated: 'Last updated: May 20, 2026',
    sections: [
      PolicySection(
        heading: '',
        body:
            'This Privacy Policy explains what information XO Arena collects, how we use it, and the choices you have. By using XO Arena, you agree to the practices described here.',
      ),
      PolicySection(
        heading: 'Information We Collect',
        body:
            'We collect only the information needed to run the game, keep it fair, and support online features. The main categories are described below.',
      ),
      PolicySection(
        heading: 'Account Information',
        body:
            'When you sign in, we may collect your email address, display name, sign-in provider (such as Google), a user ID, and an optional profile photo. We never store your password — sign-in is handled securely by the authentication provider.',
      ),
      PolicySection(
        heading: 'Game Data',
        body:
            'We store game-related data such as your coins balance, wins, losses, draws, level progress, unlocked cosmetics (avatars, colors, skins, emojis), and equipped items so your profile stays consistent across sessions and devices.',
      ),
      PolicySection(
        heading: 'Referral Data',
        body:
            'If you use the invite/referral feature, we store your referral code, who referred you, how many friends you referred, and related reward records. This is used to grant rewards and prevent abuse.',
      ),
      PolicySection(
        heading: 'Device and Technical Data',
        body:
            'We may process basic technical data such as device type, app version, language, and general diagnostic information needed to keep the app stable and secure.',
      ),
      PolicySection(
        heading: 'Payment and Purchase Data',
        body:
            'In-app purchases are processed by Google Play. We do not receive or store your full payment card details. We may store a purchase/transaction record (such as a product id and a transaction id) to verify purchases and grant items.',
      ),
      PolicySection(
        heading: 'How We Use Information',
        body: 'We use the information to:\n'
            '- Provide and maintain the game and online features\n'
            '- Save your progress, coins, and cosmetics\n'
            '- Grant purchases and referral rewards\n'
            '- Prevent cheating, fraud, and abuse\n'
            '- Improve stability, balance, and performance',
      ),
      PolicySection(
        heading: 'Firebase and Third-Party Services',
        body:
            'XO Arena uses Google Firebase services (such as Authentication, Realtime Database, Cloud Firestore, and related tools) to run accounts, online rooms, and data storage, and Google Play for purchases. These providers process data on our behalf under their own terms and security practices.',
      ),
      PolicySection(
        heading: 'Online Rooms and Match Data',
        body:
            'When you create or join an online room, other players in that room may see your in-game name, profile photo, selected cosmetics, moves, scores, and match results. This is required for online play to work.',
      ),
      PolicySection(
        heading: 'Coins, Rewards, and Virtual Items',
        body:
            'Coins and virtual items exist only inside XO Arena, have no real-world monetary value, and cannot be exchanged outside the app. Balances and ownership are stored with your account so they persist across devices.',
      ),
      PolicySection(
        heading: 'Data Sharing',
        body:
            'We do not sell your personal information. We share data only with service providers (such as Firebase and Google Play) that help operate the app, or where required by law, or to prevent fraud and abuse.',
      ),
      PolicySection(
        heading: 'Data Security',
        body:
            'We use reasonable technical and organizational measures to protect your data, including secure authentication and access rules. No method of storage or transmission is 100% secure, but we work to keep your data protected.',
      ),
      PolicySection(
        heading: 'Data Retention',
        body:
            'We keep account and game data while your account is active. Some records (such as purchase, security, and fraud-prevention logs) may be retained longer where needed for legal or safety reasons.',
      ),
      PolicySection(
        heading: 'Account and Data Deletion',
        body:
            'You can request deletion of your account and associated data from inside the app (Settings → Delete Account) or via the Account Deletion page. Some data may be retained where required for fraud prevention, purchase verification, security, or legal reasons.',
      ),
      PolicySection(
        heading: "Children's Privacy",
        body:
            'XO Arena is not directed to children under the age required by your local law. We do not knowingly collect personal information from children. If you believe a child has provided personal data, please contact us so we can remove it.',
      ),
      PolicySection(
        heading: 'User Rights and Choices',
        body:
            'Depending on your region, you may have rights to access, correct, or delete your personal data. You can manage much of your data in-app, and you can contact us for additional requests.',
      ),
      PolicySection(
        heading: 'Changes to This Privacy Policy',
        body:
            'We may update this Privacy Policy from time to time. Significant changes will be reflected by updating the "Last updated" date, and continued use of the app means you accept the updated policy.',
      ),
      PolicySection(
        heading: 'Contact Us',
        body: 'For privacy questions or requests, contact:\n'
            'adminarena77@gmail.com',
      ),
    ],
  );

  static const _privacyAr = PolicyDocData(
    appBarTitle: 'سياسة الخصوصية',
    title: 'سياسة الخصوصية لتطبيق XO Arena',
    lastUpdated: 'آخر تحديث: 20 مايو 2026',
    sections: [
      PolicySection(
        heading: '',
        body:
            'توضّح سياسة الخصوصية هذه المعلومات التي يجمعها XO Arena، وكيفية استخدامها، والخيارات المتاحة لك. باستخدامك XO Arena فإنك توافق على الممارسات الموضّحة هنا.',
      ),
      PolicySection(
        heading: 'المعلومات التي نجمعها',
        body:
            'نجمع فقط المعلومات اللازمة لتشغيل اللعبة، والحفاظ على نزاهتها، ودعم الميزات الأونلاين. الفئات الرئيسية موضّحة أدناه.',
      ),
      PolicySection(
        heading: 'معلومات الحساب',
        body:
            'عند تسجيل الدخول، قد نجمع بريدك الإلكتروني، واسم العرض، ومزوّد تسجيل الدخول (مثل Google)، ومعرّف المستخدم، وصورة ملف اختيارية. لا نخزّن كلمة مرورك أبدًا — يتم تسجيل الدخول بأمان عبر مزوّد المصادقة.',
      ),
      PolicySection(
        heading: 'بيانات اللعب',
        body:
            'نخزّن البيانات المتعلقة باللعب مثل رصيد العملات، والانتصارات، والخسائر، والتعادلات، وتقدّم المستويات، والعناصر التجميلية المفتوحة (الصور الرمزية، والألوان، والسكِنات، والإيموجي)، والعناصر المجهّزة لتبقى بياناتك متسقة عبر الجلسات والأجهزة.',
      ),
      PolicySection(
        heading: 'بيانات الإحالة',
        body:
            'إذا استخدمت ميزة الدعوة/الإحالة، فإننا نخزّن رمز الإحالة الخاص بك، ومن قام بإحالتك، وعدد الأصدقاء الذين أحلتهم، وسجلات المكافآت المرتبطة. يُستخدم ذلك لمنح المكافآت ومنع إساءة الاستخدام.',
      ),
      PolicySection(
        heading: 'بيانات الجهاز والبيانات التقنية',
        body:
            'قد نعالج بيانات تقنية أساسية مثل نوع الجهاز، وإصدار التطبيق، واللغة، ومعلومات تشخيصية عامة لازمة للحفاظ على استقرار التطبيق وأمانه.',
      ),
      PolicySection(
        heading: 'بيانات الدفع والشراء',
        body:
            'تتم معالجة المشتريات داخل التطبيق بواسطة Google Play. لا نتلقّى أو نخزّن تفاصيل بطاقة الدفع الكاملة الخاصة بك. وقد نخزّن سجل شراء/معاملة (مثل معرّف المنتج ومعرّف المعاملة) للتحقق من المشتريات ومنح العناصر.',
      ),
      PolicySection(
        heading: 'كيف نستخدم المعلومات',
        body: 'نستخدم المعلومات من أجل:\n'
            '- توفير اللعبة والميزات الأونلاين وصيانتها\n'
            '- حفظ تقدّمك وعملاتك وعناصرك التجميلية\n'
            '- منح المشتريات ومكافآت الإحالة\n'
            '- منع الغش والاحتيال وإساءة الاستخدام\n'
            '- تحسين الاستقرار والتوازن والأداء',
      ),
      PolicySection(
        heading: 'Firebase وخدمات الأطراف الثالثة',
        body:
            'يستخدم XO Arena خدمات Google Firebase (مثل المصادقة، وقاعدة البيانات اللحظية، وCloud Firestore، والأدوات المرتبطة) لتشغيل الحسابات والغرف الأونلاين وتخزين البيانات، ويستخدم Google Play للمشتريات. تعالج هذه الجهات البيانات نيابةً عنا وفق شروطها وممارساتها الأمنية.',
      ),
      PolicySection(
        heading: 'الغرف الأونلاين وبيانات المباريات',
        body:
            'عند إنشاء غرفة أونلاين أو الانضمام إليها، قد يرى اللاعبون الآخرون في تلك الغرفة اسمك داخل اللعبة، وصورة ملفك، والعناصر التجميلية المختارة، وحركاتك، والنتائج. هذا ضروري لعمل اللعب الأونلاين.',
      ),
      PolicySection(
        heading: 'العملات والمكافآت والعناصر الافتراضية',
        body:
            'توجد العملات والعناصر الافتراضية داخل XO Arena فقط، وليست لها قيمة نقدية حقيقية، ولا يمكن استبدالها خارج التطبيق. تُخزَّن الأرصدة والملكية مع حسابك لتبقى عبر الأجهزة.',
      ),
      PolicySection(
        heading: 'مشاركة البيانات',
        body:
            'نحن لا نبيع معلوماتك الشخصية. نشارك البيانات فقط مع مزوّدي الخدمة (مثل Firebase وGoogle Play) الذين يساعدون في تشغيل التطبيق، أو عند طلب القانون، أو لمنع الاحتيال وإساءة الاستخدام.',
      ),
      PolicySection(
        heading: 'أمان البيانات',
        body:
            'نستخدم تدابير تقنية وتنظيمية معقولة لحماية بياناتك، بما في ذلك مصادقة آمنة وقواعد وصول. لا توجد طريقة تخزين أو نقل آمنة بنسبة 100%، لكننا نعمل على حماية بياناتك.',
      ),
      PolicySection(
        heading: 'الاحتفاظ بالبيانات',
        body:
            'نحتفظ ببيانات الحساب واللعب طالما كان حسابك نشطًا. قد يتم الاحتفاظ ببعض السجلات (مثل سجلات الشراء والأمان ومنع الاحتيال) لمدة أطول عند الحاجة لأسباب قانونية أو أمنية.',
      ),
      PolicySection(
        heading: 'حذف الحساب والبيانات',
        body:
            'يمكنك طلب حذف حسابك والبيانات المرتبطة به من داخل التطبيق (الإعدادات ← حذف الحساب) أو من صفحة حذف الحساب. قد يتم الاحتفاظ ببعض البيانات عند الحاجة لمنع الاحتيال، أو التحقق من المشتريات، أو الأمان، أو لأسباب قانونية.',
      ),
      PolicySection(
        heading: 'خصوصية الأطفال',
        body:
            'XO Arena ليس موجّهًا للأطفال دون السن الذي يقتضيه قانونك المحلي. نحن لا نجمع عن قصد معلومات شخصية من الأطفال. إذا كنت تعتقد أن طفلًا قدّم بيانات شخصية، فيرجى التواصل معنا لإزالتها.',
      ),
      PolicySection(
        heading: 'حقوق المستخدم وخياراته',
        body:
            'بحسب منطقتك، قد تتمتّع بحقوق للوصول إلى بياناتك الشخصية أو تصحيحها أو حذفها. يمكنك إدارة كثير من بياناتك داخل التطبيق، ويمكنك التواصل معنا للطلبات الإضافية.',
      ),
      PolicySection(
        heading: 'تغييرات على سياسة الخصوصية',
        body:
            'قد نحدّث سياسة الخصوصية هذه من وقت لآخر. ستنعكس التغييرات المهمة عبر تحديث تاريخ "آخر تحديث"، ويعني استمرارك في استخدام التطبيق قبولك للسياسة المحدّثة.',
      ),
      PolicySection(
        heading: 'تواصل معنا',
        body: 'لأسئلة أو طلبات الخصوصية، تواصل مع:\n'
            'adminarena77@gmail.com',
      ),
    ],
  );
}
