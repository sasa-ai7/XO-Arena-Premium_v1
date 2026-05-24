# إصلاحات Arena + Referral

## الملفات المعدلة
- database.rules.json
- firestore.rules
- lib/services/referral/referral_service.dart
- lib/screens/arena/arena_game_page.dart

## سبب Permission denied عند إنشاء الروم
- expiresAt rule كانت تستخدم data.parent().child('createdAt') وقت إنشاء روم جديدة؛ data القديمة فاضية فالفاليديشن يقع.
- selectedAvatar في rules كان String فقط، بينما الكود يكتبه int.
- board rule كان يمنع تصفير الخانات بين الراوندات.
- status rule ناقصة حالات مستخدمة في الكود.

## سبب الدعوة not-found
- التطبيق ينادي Cloud Function اسمها redeemReferralCode.
- اللوج أظهر: CF error code=not-found msg=NOT_FOUND.
- تم إضافة fallback مؤقت في ReferralService عندما تكون الدالة غير منشورة.

## بعد النسخ
نفذ:
firebase deploy --only database,firestore
flutter clean
flutter pub get
flutter run

ثم اختبر:
- إنشاء روم Arena
- دخول Guest
- ظهور Avatar/X Skin
- إدخال كود دعوة من حساب آخر
