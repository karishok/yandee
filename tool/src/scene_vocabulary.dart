/// One tappable object in a scene: its content-facing id/label (the real,
/// agreed-on vocabulary for that scene). Shared between
/// `generate_placeholder_assets.dart` (art) and `generate_voiceover.dart`
/// (audio) so the word list lives in exactly one place.
class ObjectSpec {
  const ObjectSpec(this.id, this.label);
  final String id;
  final String label;
}

class SceneSpec {
  const SceneSpec(this.id, this.title, this.backgroundRgb, this.objects);
  final String id;
  final String title;
  final List<int> backgroundRgb;
  final List<ObjectSpec> objects;
}

// The app's first 5 real content scenes (see
// docs/superpowers/plans/2026-08-11-yandee-interactive-scenes.md).
const scenes = [
  SceneSpec('home', 'Дом', [235, 222, 200], [
    ObjectSpec('bed', 'Кровать'),
    ObjectSpec('table', 'Стол'),
    ObjectSpec('chair', 'Стул'),
    ObjectSpec('lamp', 'Лампа'),
    ObjectSpec('book', 'Книга'),
    ObjectSpec('clock', 'Часы'),
    ObjectSpec('window', 'Окно'),
    ObjectSpec('door', 'Дверь'),
    ObjectSpec('sofa', 'Диван'),
    ObjectSpec('rug', 'Ковёр'),
  ]),
  SceneSpec('kitchen', 'Кухня', [255, 240, 200], [
    ObjectSpec('plate', 'Тарелка'),
    ObjectSpec('cup', 'Чашка'),
    ObjectSpec('spoon', 'Ложка'),
    ObjectSpec('fork', 'Вилка'),
    ObjectSpec('fridge', 'Холодильник'),
    ObjectSpec('stove', 'Плита'),
    ObjectSpec('kettle', 'Чайник'),
    ObjectSpec('apple', 'Яблоко'),
    ObjectSpec('bread', 'Хлеб'),
    ObjectSpec('pot', 'Кастрюля'),
  ]),
  SceneSpec('farm', 'Ферма', [200, 230, 180], [
    ObjectSpec('cow', 'Корова'),
    ObjectSpec('pig', 'Свинья'),
    ObjectSpec('chicken', 'Курица'),
    ObjectSpec('rooster', 'Петух'),
    ObjectSpec('horse', 'Лошадь'),
    ObjectSpec('sheep', 'Овца'),
    ObjectSpec('goat', 'Коза'),
    ObjectSpec('duck', 'Утка'),
    ObjectSpec('dog', 'Собака'),
    ObjectSpec('tractor', 'Трактор'),
  ]),
  SceneSpec('street', 'Улица', [210, 215, 220], [
    ObjectSpec('car', 'Машина'),
    ObjectSpec('bus', 'Автобус'),
    ObjectSpec('bicycle', 'Велосипед'),
    ObjectSpec('traffic_light', 'Светофор'),
    ObjectSpec('tree', 'Дерево'),
    ObjectSpec('bench', 'Скамейка'),
    ObjectSpec('lamppost', 'Фонарь'),
    ObjectSpec('scooter', 'Самокат'),
    ObjectSpec('truck', 'Грузовик'),
    ObjectSpec('road_sign', 'Дорожный знак'),
  ]),
  SceneSpec('bathroom', 'Ванная', [210, 235, 245], [
    ObjectSpec('soap', 'Мыло'),
    ObjectSpec('toothbrush', 'Зубная щётка'),
    ObjectSpec('toothpaste', 'Зубная паста'),
    ObjectSpec('towel', 'Полотенце'),
    ObjectSpec('bathtub', 'Ванна'),
    ObjectSpec('sink', 'Раковина'),
    ObjectSpec('shampoo', 'Шампунь'),
    ObjectSpec('duck_toy', 'Уточка'),
    ObjectSpec('mirror', 'Зеркало'),
    ObjectSpec('comb', 'Расчёска'),
  ]),
];
