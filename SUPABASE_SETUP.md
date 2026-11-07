# ربط Supabase لاحقاً

1. أنشئ مشروعاً في Supabase.
2. افتح SQL Editor وشغّل `supabase/schema.sql` بعد مراجعته.
3. أنشئ المستخدم الأول من Authentication → Users.
4. أضف صفاً له في `public.profiles` واجعل role = `admin`.
5. أنشئ حسابات العمال من واجهة آمنة على الخادم أو Supabase Edge Function باستخدام Admin API.
6. لا تضع Service Role Key في ملفات المتصفح أو GitHub.
7. أضف واختبر سياسات RLS الإضافية لكل عملية، ثم انقل التطبيق من localStorage إلى Supabase client.

هذا الملف إرشادي؛ النسخة الحالية لا تتصل بسوبابيس بعد.
