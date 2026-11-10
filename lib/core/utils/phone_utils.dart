// phone_utils.dart
// تنظيف + validation + توحيد صيغة رقم التليفون (E.164)

class PhoneInfo {
  final bool isValid;

  /// بالشكل الدولي: +971501234567 (للاتصال)
  final String e164;

  /// أرقام بس من غير +: 971501234567 (لـ wa.me)
  final String digits;

  /// سبب الرفض لو الرقم مش صالح
  final String? error;

  const PhoneInfo._(this.isValid, this.e164, this.digits, this.error);

  factory PhoneInfo.invalid(String error) =>
      PhoneInfo._(false, '', '', error);

  factory PhoneInfo.valid(String digits) =>
      PhoneInfo._(true, '+$digits', digits, null);
}

class PhoneUtils {
  PhoneUtils._();

  /// الحالات اللي بيتعامل معاها:
  ///  +971501234567      -> international
  ///  00971501234567     -> international (00)
  ///  0501234567 + cc    -> local بصفر (الصفر بيتشال)
  ///  501234567 + cc     -> local من غير صفر
  ///  971501234567 + cc  -> الكود موجود فعلاً (مش بيتكرر)
  ///  +9710501234567     -> صفر زيادة بعد الكود (بيتشال)
  static PhoneInfo parse(String? phone, {String? countryCode}) {
    var raw = _toLatinDigits((phone ?? '').trim());
    if (raw.isEmpty) return PhoneInfo.invalid('Phone number is empty');

    if (RegExp(r'[^\d+\s\-().]').hasMatch(raw)) {
      return PhoneInfo.invalid('Phone contains invalid characters');
    }
    // + مسموح بس في الأول
    if ('+'.allMatches(raw).length > 1 ||
        (raw.contains('+') && !raw.startsWith('+'))) {
      return PhoneInfo.invalid('Invalid "+" position');
    }

    final hasPlus = raw.startsWith('+');
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return PhoneInfo.invalid('Phone number is empty');

    final cc = (countryCode ?? '').replaceAll(RegExp(r'\D'), '');

    if (hasPlus) {
      // international — بنثق في الرقم زي ما هو
    } else if (digits.startsWith('00')) {
      digits = digits.substring(2);
    } else {
      // local
      if (cc.isEmpty) return PhoneInfo.invalid('Missing country code');
      if (_alreadyHasCc(digits, cc)) {
        // الكود موجود، سيبه
      } else {
        digits = '$cc${digits.replaceFirst(RegExp(r'^0+'), '')}';
      }
    }

    // صفر زيادة بعد كود الدولة: 9710501234567 -> 971501234567
    if (cc.isNotEmpty && digits.startsWith('${cc}0')) {
      digits = cc + digits.substring(cc.length).replaceFirst(RegExp(r'^0+'), '');
    }

    if (digits.startsWith('0')) {
      return PhoneInfo.invalid('Invalid country code');
    }
    if (digits.length < 8 || digits.length > 15) {
      return PhoneInfo.invalid('Phone number length is invalid');
    }
    return PhoneInfo.valid(digits);
  }

  /// للاستخدام في TextFormField(validator: ...)
  static String? validator(String? v, {String? countryCode}) =>
      parse(v, countryCode: countryCode).error;

  // heuristic: الرقم بيبدأ بكود الدولة وطوله منطقي وما بيبدأش بصفر
  static bool _alreadyHasCc(String digits, String cc) =>
      !digits.startsWith('0') &&
      digits.startsWith(cc) &&
      digits.length >= cc.length + 8;

  // أرقام عربية/هندية -> لاتينية
  static String _toLatinDigits(String s) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = ar.indexOf(ch);
      final j = fa.indexOf(ch);
      b.write(i >= 0 ? '$i' : (j >= 0 ? '$j' : ch));
    }
    return b.toString();
  }
}