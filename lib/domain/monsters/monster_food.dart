import 'monster_color.dart';

/// A kind of treat, with the noun and its gender (which decides the ending
/// of the colour word in front of it).
enum FoodKind {
  strawberry('strawberry', 'клубника', Gender.feminine),
  tomato('tomato', 'помидор', Gender.masculine),
  apple('apple', 'яблоко', Gender.neuter),
  cherry('cherry', 'вишня', Gender.feminine),
  blueberry('blueberry', 'черника', Gender.feminine),
  plum('plum', 'слива', Gender.feminine),
  banana('banana', 'банан', Gender.masculine),
  cheese('cheese', 'сыр', Gender.masculine),
  lemon('lemon', 'лимон', Gender.masculine),
  corn('corn', 'кукуруза', Gender.feminine),
  cucumber('cucumber', 'огурец', Gender.masculine),
  pear('pear', 'груша', Gender.feminine),
  peas('peas', 'горошек', Gender.masculine),
  broccoli('broccoli', 'брокколи', Gender.feminine),
  orangeFruit('orange_fruit', 'апельсин', Gender.masculine),
  carrot('carrot', 'морковка', Gender.feminine),
  pumpkin('pumpkin', 'тыква', Gender.feminine),
  mandarin('mandarin', 'мандарин', Gender.masculine),
  grapes('grapes', 'виноград', Gender.masculine),
  eggplant('eggplant', 'баклажан', Gender.masculine),
  donut('donut', 'пончик', Gender.masculine),
  marshmallow('marshmallow', 'зефир', Gender.masculine),
  cottonCandy('cotton_candy', 'сахарная вата', Gender.feminine),
  chocolate('chocolate', 'шоколадка', Gender.feminine),
  cookie('cookie', 'печенье', Gender.neuter),
  nut('nut', 'орех', Gender.masculine),
  mushroom('mushroom', 'гриб', Gender.masculine),
  egg('egg', 'яйцо', Gender.neuter),
  milk('milk', 'молоко', Gender.neuter),
  rice('rice', 'рис', Gender.masculine),
  garlic('garlic', 'чеснок', Gender.masculine),
  blackberry('blackberry', 'ежевика', Gender.feminine),
  olive('olive', 'оливка', Gender.feminine),
  bread('bread', 'хлеб', Gender.masculine),
  currant('currant', 'смородина', Gender.feminine),
  candy('candy', 'конфета', Gender.feminine),
  lollipop('lollipop', 'леденец', Gender.masculine),
  iceCream('ice_cream', 'мороженое', Gender.neuter);

  const FoodKind(this.fileId, this.noun, this.gender);

  /// Latin name used in audio file names.
  final String fileId;
  final String noun;
  final Gender gender;
}

/// What a monster of each colour eats: real food of that colour wherever
/// there is some, and a sweet only where there isn't — blue and purple
/// have few foods of their own, and nothing you'd give a child is truly
/// light blue except sweets.
const Map<MonsterColor, List<FoodKind>> foodsByColor = {
  MonsterColor.red: [FoodKind.strawberry, FoodKind.tomato, FoodKind.apple, FoodKind.cherry],
  MonsterColor.blue: [FoodKind.blueberry, FoodKind.plum, FoodKind.candy],
  MonsterColor.yellow: [FoodKind.banana, FoodKind.cheese, FoodKind.lemon, FoodKind.corn],
  MonsterColor.green: [FoodKind.cucumber, FoodKind.pear, FoodKind.peas, FoodKind.broccoli],
  MonsterColor.orange: [FoodKind.orangeFruit, FoodKind.carrot, FoodKind.pumpkin, FoodKind.mandarin],
  MonsterColor.purple: [FoodKind.grapes, FoodKind.eggplant, FoodKind.lollipop],
  MonsterColor.pink: [FoodKind.donut, FoodKind.marshmallow, FoodKind.cottonCandy, FoodKind.iceCream],
  MonsterColor.brown: [FoodKind.chocolate, FoodKind.cookie, FoodKind.nut, FoodKind.mushroom],
  MonsterColor.lightblue: [FoodKind.cottonCandy, FoodKind.iceCream, FoodKind.lollipop],
  MonsterColor.white: [FoodKind.egg, FoodKind.milk, FoodKind.rice, FoodKind.garlic],
  MonsterColor.black: [FoodKind.blackberry, FoodKind.olive, FoodKind.bread, FoodKind.currant],
};

/// One treat lying in the tray: a kind of food in a colour.
class MonsterFood {
  const MonsterFood(this.kind, this.color);

  final FoodKind kind;
  final MonsterColor color;

  /// «красная клубника» — the colour word agrees with the food's gender.
  String get name => '${color.adjective(kind.gender)} ${kind.noun}';

  @override
  bool operator ==(Object other) => other is MonsterFood && other.kind == kind && other.color == color;

  @override
  int get hashCode => Object.hash(kind, color);

  @override
  String toString() => 'MonsterFood($name)';
}

/// Every treat a monster of [color] eats. A random treat for that colour is
/// drawn from this list, each one equally likely.
List<MonsterFood> foodsFor(MonsterColor color) =>
    [for (final kind in foodsByColor[color]!) MonsterFood(kind, color)];

/// Every treat in the game, colour by colour.
List<MonsterFood> get allFoods => [for (final color in MonsterColor.values) ...foodsFor(color)];
