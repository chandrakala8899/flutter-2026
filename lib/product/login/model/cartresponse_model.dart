class CartresponseModel {
  final String cartId;
  final String checkoutUrl;

  CartresponseModel({
    required this.cartId,
    required this.checkoutUrl,
  });

  factory CartresponseModel.fromJson(Map<String, dynamic> json) {
    final cartData = json['data']?['cartCreate']?['cart'];

    return CartresponseModel(
      cartId: cartData?['id'] ?? '',
      checkoutUrl: cartData?['checkoutUrl'] ?? '',
    );
  }
}
