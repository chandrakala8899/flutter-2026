// cart_request.dart
class CartCreateRequest {
  final List<CartItemRequest> items;

  CartCreateRequest({required this.items});

  Map<String, dynamic> toJson() => {
    'items': items.map((item) => item.toJson()).toList(),
  };

  factory CartCreateRequest.fromJson(Map<String, dynamic> json) => 
    CartCreateRequest(items: (json['items'] as List)
        .map((item) => CartItemRequest.fromJson(item))
        .toList());
}

// cart_item_request.dart
class CartItemRequest {
  final String variantId;
  final int quantity;

  CartItemRequest({
    required this.variantId,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
    'variantId': variantId,
    'quantity': quantity,
  };

  factory CartItemRequest.fromJson(Map<String, dynamic> json) => 
    CartItemRequest(
      variantId: json['variantId'],
      quantity: json['quantity'],
    );
}

// product_node.dart (Your existing model)
class ProductNode {
  final String id;
  final String title;
  final double price;
  final String? imageUrl;

  ProductNode({
    required this.id,
    required this.title,
    required this.price,
    this.imageUrl,
  });

  factory ProductNode.fromJson(Map<String, dynamic> json) => ProductNode(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    price: (json['price'] ?? 0).toDouble(),
    imageUrl: json['featuredImage']?['url'],
  );
}
