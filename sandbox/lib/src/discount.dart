/// Deliberately under-tested business logic. Mutations here should survive.
class DiscountService {
  /// Percentage discount for an order.
  ///
  /// Orders above 100 get 10%, above 500 get 20%. VIP customers always get
  /// at least 15%. Null totals are treated as zero.
  double discountFor({num? total, bool isVip = false}) {
    final effectiveTotal = total ?? 0;
    var discount = 0.0;
    if (effectiveTotal > 100) {
      discount = 10.0;
    }
    if (effectiveTotal > 500) {
      discount = 20.0;
    }
    if (isVip && discount < 15.0) {
      discount = 15.0;
    }
    return discount;
  }

  /// Applies the discount to a total, never returning a negative price.
  double apply(double total, double discountPercent) {
    final price = total * (1 - discountPercent / 100);
    return price < 0 ? 0 : price;
  }
}
