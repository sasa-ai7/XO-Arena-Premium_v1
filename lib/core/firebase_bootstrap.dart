class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<void> _ready = Future<void>.value();

  static Future<void> get ready => _ready;

  static void configure(Future<void> readyFuture) {
    _ready = readyFuture;
  }
}
