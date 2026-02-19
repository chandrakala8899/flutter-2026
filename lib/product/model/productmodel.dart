// models/product_model.dart - ✅ 100% NULL SAFE
class ProductQuery {
  final Products? data;

  ProductQuery.fromJson(Map<String, dynamic> json)
      : data = json['data'] != null ? Products.fromJson(json['data']) : null;
}

class Products {
  final List<ProductEdge>? edges;

  Products.fromJson(Map<String, dynamic> json)
      : edges = json['edges'] != null
            ? (json['edges'] as List)
                .map((e) => ProductEdge.fromJson(e))
                .toList()
            : null;
}

class ProductEdge {
  final ProductNodeModel? node;

  ProductEdge.fromJson(Map<String, dynamic> json)
      : node = json['node'] != null
            ? ProductNodeModel.fromJson(json['node'])
            : null;
}

class ProductNodeModel {
  final String id;
  final String title;
  final String description;
  final ProductImage? images;
  final ProductVariant? variants;

  ProductNodeModel({
    required this.id,
    required this.title,
    required this.description,
    this.images,
    this.variants,
  });

  ProductNodeModel.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        title = json['title'] ?? '',
        description = json['description'] ?? '',
        images = json['images'] != null
            ? ProductImage.fromJson(json['images'])
            : null,
        variants = json['variants'] != null
            ? ProductVariant.fromJson(json['variants'])
            : null;

  // ✅ FIXED NULL SAFE GETTERS
  String get imageUrl {
    final imageEdges = images?.edges;
    if (imageEdges == null || imageEdges.isEmpty) return '';
    final firstEdge = imageEdges[0];
    return firstEdge.node?.url ?? '';
  }

  String get price {
    final variantEdges = variants?.edges;
    if (variantEdges == null || variantEdges.isEmpty) return '0';
    final firstVariant = variantEdges[0].node;
    return firstVariant?.price?.amount ?? '0';
  }

  String get currency {
    final variantEdges = variants?.edges;
    if (variantEdges == null || variantEdges.isEmpty) return 'INR';
    final firstVariant = variantEdges[0].node;
    return firstVariant?.price?.currencyCode ?? 'INR';
  }
}

class ProductImage {
  final List<ProductImageEdge>? edges;

  ProductImage.fromJson(Map<String, dynamic> json)
      : edges = json['edges'] != null
            ? (json['edges'] as List)
                .map((e) => ProductImageEdge.fromJson(e))
                .toList()
            : null;
}

class ProductImageEdge {
  final ProductImageNode? node;

  ProductImageEdge.fromJson(Map<String, dynamic> json)
      : node = json['node'] != null
            ? ProductImageNode.fromJson(json['node'])
            : null;
}

class ProductImageNode {
  final String url;

  ProductImageNode.fromJson(Map<String, dynamic> json)
      : url = json['url'] ?? '';
}

class ProductVariant {
  final List<ProductVariantEdge>? edges;

  ProductVariant.fromJson(Map<String, dynamic> json)
      : edges = json['edges'] != null
            ? (json['edges'] as List)
                .map((e) => ProductVariantEdge.fromJson(e))
                .toList()
            : null;
}

class ProductVariantEdge {
  final ProductVariantNode? node;

  ProductVariantEdge.fromJson(Map<String, dynamic> json)
      : node = json['node'] != null
            ? ProductVariantNode.fromJson(json['node'])
            : null;
}

class ProductVariantNode {
  final String id;
  final MoneyPrice? price;

  ProductVariantNode({required this.id, this.price});

  ProductVariantNode.fromJson(Map<String, dynamic> json)
      : id = json['id'] ?? '',
        price =
            json['price'] != null ? MoneyPrice.fromJson(json['price']) : null;
}

class MoneyPrice {
  final String amount;
  final String currencyCode;

  MoneyPrice({required this.amount, required this.currencyCode});

  MoneyPrice.fromJson(Map<String, dynamic> json)
      : amount = json['amount'] ?? '0',
        currencyCode = json['currencyCode'] ?? '';
}
