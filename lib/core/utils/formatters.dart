class Formatters {
  Formatters._();

  static String currency(int amount) {
    return '₹${amount.toStringAsFixed(0)}';
  }

  static String currencyDecimal(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  static String pricePerSqFt(double price) {
    return '₹${price.toStringAsFixed(0)}/sqft';
  }

  static String phoneNumber(String phone) {
    if (phone.length == 10) {
      return '+91 ${phone.substring(0, 5)} ${phone.substring(5)}';
    }
    return phone;
  }

  static String dateShort(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '$d ${months[date.month]} ${date.year}';
  }

  static String dateLong(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '$d ${months[date.month]} ${date.year}';
  }

  static String dateWithTime(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = date.hour > 12 ? date.hour - 12 : date.hour;
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    final m = date.minute.toString().padLeft(2, '0');
    return '$d ${months[date.month]} ${date.year}, $h:$m $amPm';
  }

  static String ordinal(int number) {
    if (number >= 11 && number <= 13) return '${number}th';
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  static String compact(int number) {
    if (number >= 10000000) {
      return '${(number / 10000000).toStringAsFixed(1)}Cr';
    } else if (number >= 100000) {
      return '${(number / 100000).toStringAsFixed(1)}L';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
