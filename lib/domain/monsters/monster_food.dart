import 'monster_color.dart';

/// A kind of treat, with the noun and its gender (which decides the ending
/// of the colour word in front of it).
enum FoodKind {
  strawberry('strawberry', 'клубника', Gender.feminine),
  tomato('tomato', 'помидор', Gender.masculine),
  blueberry('blueberry', 'черника', Gender.feminine),
  banana('banana', 'банан', Gender.masculine),
  cheese('cheese', 'сыр', Gender.masculine),
  cucumber('cucumber', 'огурец', Gender.masculine),
  pear('pear', 'груша', Gender.feminine),
  orangeFruit('orange_fruit', 'апельсин', Gender.masculine),
  carrot('carrot', 'морковка', Gender.feminine),
  grapes('grapes', 'виноград', Gender.masculine),
  eggplant('eggplant', 'баклажан', Gender.masculine),
  donut('donut', 'пончик', Gender.masculine),
  chocolate('chocolate', 'шоколадка', Gender.feminine),
  cookie('cookie', 'печенье', Gender.neuter),
  egg('egg', 'яйцо', Gender.neuter),
  milk('milk', 'молоко', Gender.neuter),
  blackberry('blackberry', 'ежевика', Gender.feminine),
  candy('candy', 'конфета', Gender.feminine),
  lollipop('lollipop', 'леденец', Gender.masculine),
  iceCream('ice_cream', 'мороженое', Gender.neuter);

  const FoodKind(this.fileId, this.noun, this.gender);

  /// Latin name used in audio file names.
  final String fileId;
  final String noun;
  final Gender gender;
}

/// Real foods that only come in one colour. A colour with no entry (light
/// blue) is fed sweets only.
const Map<MonsterColor, List<FoodKind>> naturalFoods = {
  MonsterColor.red: [FoodKind.strawberry, FoodKind.tomato],
  MonsterColor.blue: [FoodKind.blueberry],
  MonsterColor.yellow: [FoodKind.banana, FoodKind.cheese],
  MonsterColor.green: [FoodKind.cucumber, FoodKind.pear],
  MonsterColor.orange: [FoodKind.orangeFruit, FoodKind.carrot],
  MonsterColor.purple: [FoodKind.grapes, FoodKind.eggplant],
  MonsterColor.pink: [FoodKind.donut],
  MonsterColor.brown: [FoodKind.chocolate, FoodKind.cookie],
  MonsterColor.white: [FoodKind.egg, FoodKind.milk],
  MonsterColor.black: [FoodKind.blackberry],
};

/// Sweets exist in every colour, so every monster can always be fed.
const List<FoodKind> sweets = [FoodKind.candy, FoodKind.lollipop, FoodKind.iceCream];

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

/// Every treat a monster of [color] eats, without repeats: its real foods,
/// then the three sweets.
List<MonsterFood> foodsFor(MonsterColor color) => [
      for (final kind in naturalFoods[color] ?? const <FoodKind>[]) MonsterFood(kind, color),
      for (final kind in sweets) MonsterFood(kind, color),
    ];

/// The hat a random treat for [color] is drawn from. Real foods are in it
/// twice, so they turn up more often than the same three sweets.
List<MonsterFood> menuFor(MonsterColor color) {
  final natural = [for (final kind in naturalFoods[color] ?? const <FoodKind>[]) MonsterFood(kind, color)];
  return [...natural, ...natural, for (final kind in sweets) MonsterFood(kind, color)];
}

/// Every treat in the game, colour by colour.
List<MonsterFood> get allFoods => [for (final color in MonsterColor.values) ...foodsFor(color)];
