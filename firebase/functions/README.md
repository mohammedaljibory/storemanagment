# Firebase Cloud Functions - مراقبة ساعات العمل

هذه الدوال تعمل على السيرفر بشكل مستقل عن التطبيق.

## المميزات

### 1. مراقبة نهاية الشفت (`checkShiftEndAutoCheckout`)
- تعمل كل **5 دقائق**
- تفحص الموظفين الذين لم يسجلوا خروجهم
- تسجل خروج تلقائي بعد **30 دقيقة** من انتهاء الشفت
- ترسل إشعار للموظف والأدمن

### 2. مراقبة الزمنيات (`checkTimeOffGracePeriod`)
- تعمل كل **دقيقة**
- تفحص الموظفين في زمنية نشطة
- تحظر الموظف وتسجل خروجه بعد **15 دقيقة** من انتهاء الزمنية
- ترسل إشعار للموظف والأدمن

### 3. مراقبة الاستراحات (`checkBreakOvertime`)
- تعمل كل **5 دقائق**
- تفحص الموظفين في استراحة
- ترسل تنبيه للأدمن إذا تجاوزت **60 دقيقة**

## التثبيت والنشر

### 1. تثبيت Firebase CLI
```bash
npm install -g firebase-tools
```

### 2. تسجيل الدخول
```bash
firebase login
```

### 3. اختيار المشروع
```bash
firebase use YOUR_PROJECT_ID
```

### 4. تثبيت المكتبات
```bash
cd functions
npm install
```

### 5. نشر الدوال
```bash
firebase deploy --only functions
```

## اختبار الدوال

### اختبار يدوي عبر HTTP:
```bash
# فحص نهاية الشفت
curl https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/manualShiftEndCheck

# فحص الزمنيات
curl https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/manualTimeOffCheck

# حالة المراقبة
curl https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/getMonitoringStatus
```

### اختبار محلي:
```bash
firebase emulators:start --only functions
```

## الإعدادات

يمكن تعديل الإعدادات في `index.js`:

```javascript
const CONFIG = {
  SHIFT_END_GRACE_MINUTES: 30,      // دقائق السماح بعد نهاية الشفت
  TIME_OFF_GRACE_MINUTES: 15,        // دقائق السماح بعد نهاية الزمنية
  BREAK_MAX_MINUTES: 60,             // الحد الأقصى للاستراحة
  CHECK_INTERVAL_MINUTES: 5,         // فترة الفحص
};
```

## السجلات (Logs)

لمشاهدة السجلات:
```bash
firebase functions:log
```

أو من Firebase Console:
https://console.firebase.google.com/project/YOUR_PROJECT/functions/logs

## التكلفة

- **Blaze Plan** مطلوب لاستخدام Scheduled Functions
- التكلفة تعتمد على عدد التشغيلات
- تقريباً: ~$0.40 لكل مليون تشغيل
