class GameAvatar {
  final int id;
  final String name;
  final String assetPath;
  final int price;
  final bool isGif;
  final double profileSizeRatio;
  final double verticalOffset;

  const GameAvatar({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.price,
    required this.isGif,
    this.profileSizeRatio = 0.80,
    this.verticalOffset = 0.0,
  });
}

const List<GameAvatar> kGameAvatars = [
  GameAvatar(id: 1, name: 'Classic', assetPath: 'assets/avatar/Avatar__1.png', price: 0, isGif: false),
  GameAvatar(id: 4, name: 'Frost', assetPath: 'assets/avatar/Avatar__4.png', price: 1000, isGif: false),
  GameAvatar(id: 6, name: 'Phantom', assetPath: 'assets/avatar/Avatar__6.png', price: 1000, isGif: false),
  GameAvatar(id: 7, name: 'Inferno', assetPath: 'assets/avatar/Avatar__7.gif', price: 2500, isGif: true, profileSizeRatio: 0.58, verticalOffset: 8.0),
  GameAvatar(id: 8, name: 'Celestial', assetPath: 'assets/avatar/Avatar__8.gif', price: 2500, isGif: true, profileSizeRatio: 0.60),
  GameAvatar(id: 10, name: 'Apex', assetPath: 'assets/avatar/Avatar__10.gif', price: 2500, isGif: true, verticalOffset: 12.0),
];

GameAvatar gameAvatarById(int id) {
  return kGameAvatars.firstWhere(
    (a) => a.id == id,
    orElse: () => kGameAvatars.first,
  );
}
