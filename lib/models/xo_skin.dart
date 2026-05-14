/// XO image-based skin model and catalogs.
class XOSkin {
  final String id;         // "default" | "x5" | "o3" etc.
  final String type;       // "x" or "o"
  final String assetPath;  // "" for default, "assets/x/x5.png" for images
  final int price;         // 0 for default

  const XOSkin({
    required this.id,
    required this.type,
    required this.assetPath,
    required this.price,
  });

  bool get isLegendary => price >= 9000;
  bool get isDefault => id == 'default';
}

/// X skin catalog — "default" first, then sorted by price ascending.
final List<XOSkin> xSkinCatalog = [
  const XOSkin(id: 'default', type: 'x', assetPath: '', price: 0),
  const XOSkin(id: 'x5',  type: 'x', assetPath: 'assets/x/x5.png',  price: 2500),
  const XOSkin(id: 'x1',  type: 'x', assetPath: 'assets/x/x1.png',  price: 3000),
  const XOSkin(id: 'x22', type: 'x', assetPath: 'assets/x/x22.png', price: 3000),
  const XOSkin(id: 'x2',  type: 'x', assetPath: 'assets/x/x2.png',  price: 3500),
  const XOSkin(id: 'x6',  type: 'x', assetPath: 'assets/x/x6.png',  price: 3500),
  const XOSkin(id: 'x7',  type: 'x', assetPath: 'assets/x/x7.png',  price: 4000),
  const XOSkin(id: 'x8',  type: 'x', assetPath: 'assets/x/x8.png',  price: 4000),
  const XOSkin(id: 'x23', type: 'x', assetPath: 'assets/x/x23.png', price: 4000),
  const XOSkin(id: 'x3',  type: 'x', assetPath: 'assets/x/x3.png',  price: 4500),
  const XOSkin(id: 'x19', type: 'x', assetPath: 'assets/x/x19.png', price: 4500),
  const XOSkin(id: 'x4',  type: 'x', assetPath: 'assets/x/x4.png',  price: 5000),
  const XOSkin(id: 'x14', type: 'x', assetPath: 'assets/x/x14.png', price: 5000),
  const XOSkin(id: 'x16', type: 'x', assetPath: 'assets/x/x16.png', price: 5000),
  const XOSkin(id: 'x10', type: 'x', assetPath: 'assets/x/x10.png', price: 6000),
  const XOSkin(id: 'x13', type: 'x', assetPath: 'assets/x/x13.png', price: 6000),
  const XOSkin(id: 'x15', type: 'x', assetPath: 'assets/x/x15.png', price: 6000),
  const XOSkin(id: 'x24', type: 'x', assetPath: 'assets/x/x24.png', price: 7000),
  const XOSkin(id: 'x20', type: 'x', assetPath: 'assets/x/x20.png', price: 8000),
  const XOSkin(id: 'x21', type: 'x', assetPath: 'assets/x/x21.png', price: 8000),
  const XOSkin(id: 'x17', type: 'x', assetPath: 'assets/x/x17.png', price: 9000),
  const XOSkin(id: 'x12', type: 'x', assetPath: 'assets/x/x12.png', price: 9500),
  const XOSkin(id: 'x18', type: 'x', assetPath: 'assets/x/x18.png', price: 10000),
  const XOSkin(id: 'x11', type: 'x', assetPath: 'assets/x/x11.png', price: 15000),
];

/// O skin catalog — "default" first, then sorted by price ascending.
final List<XOSkin> oSkinCatalog = [
  const XOSkin(id: 'default', type: 'o', assetPath: '', price: 0),
  const XOSkin(id: 'o21', type: 'o', assetPath: 'assets/o/o21.png', price: 2500),
  const XOSkin(id: 'o13', type: 'o', assetPath: 'assets/o/o13.png', price: 3000),
  const XOSkin(id: 'o20', type: 'o', assetPath: 'assets/o/o20.png', price: 3000),
  const XOSkin(id: 'o24', type: 'o', assetPath: 'assets/o/o24.png', price: 3000),
  const XOSkin(id: 'o22', type: 'o', assetPath: 'assets/o/o22.png', price: 4000),
  const XOSkin(id: 'o15', type: 'o', assetPath: 'assets/o/o15.png', price: 4500),
  const XOSkin(id: 'o3',  type: 'o', assetPath: 'assets/o/o3.png',  price: 5000),
  const XOSkin(id: 'o7',  type: 'o', assetPath: 'assets/o/o7.png',  price: 5000),
  const XOSkin(id: 'o14', type: 'o', assetPath: 'assets/o/o14.png', price: 5000),
  const XOSkin(id: 'o23', type: 'o', assetPath: 'assets/o/o23.png', price: 5000),
  const XOSkin(id: 'o4',  type: 'o', assetPath: 'assets/o/o4.png',  price: 7000),
  const XOSkin(id: 'o16', type: 'o', assetPath: 'assets/o/o16.png', price: 7000),
  const XOSkin(id: 'o1',  type: 'o', assetPath: 'assets/o/o1.png',  price: 8000),
  const XOSkin(id: 'o6',  type: 'o', assetPath: 'assets/o/o6.png',  price: 8000),
  const XOSkin(id: 'o2',  type: 'o', assetPath: 'assets/o/o2.png',  price: 9000),
  const XOSkin(id: 'o5',  type: 'o', assetPath: 'assets/o/o5.png',  price: 9000),
  const XOSkin(id: 'o12', type: 'o', assetPath: 'assets/o/o12.png', price: 9000),
  const XOSkin(id: 'o19', type: 'o', assetPath: 'assets/o/o19.png', price: 9000),
  const XOSkin(id: 'o9',  type: 'o', assetPath: 'assets/o/o9.png',  price: 9500),
  const XOSkin(id: 'o8',  type: 'o', assetPath: 'assets/o/o8.png',  price: 10000),
  const XOSkin(id: 'o11', type: 'o', assetPath: 'assets/o/o11.png', price: 10000),
  const XOSkin(id: 'o18', type: 'o', assetPath: 'assets/o/o18.png', price: 10000),
  const XOSkin(id: 'o10', type: 'o', assetPath: 'assets/o/o10.png', price: 15000),
  const XOSkin(id: 'o17', type: 'o', assetPath: 'assets/o/o17.png', price: 15000),
];
