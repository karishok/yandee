/// One tappable object in a scene: its content-facing id/label (the real,
/// agreed-on vocabulary for that scene). Shared between
/// `generate_placeholder_assets.dart` (art) and the voiceover tooling
/// (`voiceover_tasks.dart`, `record_voiceover.dart`) so the word list lives
/// in exactly one place.
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
// docs/superpowers/plans/2026-08-11-yandee-interactive-scenes.md), followed
// by the smaller scenes added later.
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
    // Added to match the new objects drawn into the updated background art.
    ObjectSpec('flower', 'Цветок'),
    ObjectSpec('pillow', 'Подушка'),
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
    // Added to match the new objects drawn into the updated background art.
    ObjectSpec('window', 'Окно'),
    ObjectSpec('table', 'Стол'),
    ObjectSpec('chair', 'Стул'),
    ObjectSpec('hood', 'Вытяжка'),
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
    // Added to match the new objects drawn into the updated background art.
    ObjectSpec('house', 'Дом'),
    ObjectSpec('barn', 'Сарай'),
    ObjectSpec('pond', 'Пруд'),
    ObjectSpec('doghouse', 'Будка'),
    // The scene actually draws one apple tree and three clouds; scene.json
    // gives each cloud its own tap zone ("cloud_1".."cloud_3") but they all
    // reuse this one recording, so only one word is listed here.
    ObjectSpec('tree', 'Дерево'),
    ObjectSpec('cloud', 'Облако'),
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
    // Added to match the new objects drawn into the updated background art.
    ObjectSpec('house', 'Дом'),
    ObjectSpec('road', 'Дорога'),
    // The background actually draws three houses and three clouds;
    // "house_2"/"house_3" in scene.json reuse the "house" recording above,
    // and "cloud_1"/"cloud_2"/"cloud_3" all reuse this one recording.
    ObjectSpec('cloud', 'Облако'),
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
    // Added to match the new objects drawn into the updated background art.
    // "Полотенце" and "Ванна" were requested too, but both already exist
    // above with recorded audio, so they're not duplicated here.
    ObjectSpec('shower', 'Душ'),
    ObjectSpec('curtain', 'Занавеска'),
    ObjectSpec('bath_mat', 'Коврик'),
    // Added to match the laundry basket drawn into the background art.
    ObjectSpec('basket', 'Корзина'),
  ]),
  // Scenes added after the first five are deliberately smaller: at most 7
  // objects each, so the youngest children aren't overwhelmed ('forest' and
  // 'sea' are the agreed exceptions, see below).
  SceneSpec('playground', 'Площадка', [200, 225, 170], [
    ObjectSpec('swing', 'Качели'),
    ObjectSpec('slide', 'Горка'),
    ObjectSpec('carousel', 'Карусель'),
    ObjectSpec('sandbox', 'Песочница'),
    // The bucket and shovel are drawn inside the sandbox; they come after
    // it so that, in scene.json's same order, their tap zones win over it.
    ObjectSpec('bucket', 'Ведёрко'),
    ObjectSpec('shovel', 'Лопатка'),
    ObjectSpec('ball', 'Мяч'),
  ]),
  SceneSpec('zoo', 'Зоопарк', [215, 230, 170], [
    ObjectSpec('elephant', 'Слон'),
    ObjectSpec('giraffe', 'Жираф'),
    ObjectSpec('lion', 'Лев'),
    ObjectSpec('monkey', 'Обезьяна'),
    ObjectSpec('zebra', 'Зебра'),
    ObjectSpec('tiger', 'Тигр'),
    ObjectSpec('hippo', 'Бегемот'),
  ]),
  SceneSpec('forest', 'Лес', [190, 220, 160], [
    ObjectSpec('fir_tree', 'Ёлка'),
    ObjectSpec('mushroom', 'Гриб'),
    ObjectSpec('hare', 'Заяц'),
    ObjectSpec('fox', 'Лиса'),
    ObjectSpec('hedgehog', 'Ёж'),
    ObjectSpec('squirrel', 'Белка'),
    ObjectSpec('bear', 'Медведь'),
    // Agreed exception to the 7-object cap: the art draws these three so
    // prominently that a child would tap them, so they are named too.
    // scene.json gives the two leafy trees ("tree_1", "tree_2") and the
    // winding path ("path_1".."path_6") several tap zones each; every zone
    // of a word reuses that word's single recording.
    ObjectSpec('stump', 'Пень'),
    ObjectSpec('tree', 'Дерево'),
    ObjectSpec('path', 'Тропинка'),
  ]),
  SceneSpec('toys', 'Игрушки', [245, 230, 200], [
    ObjectSpec('teddy_bear', 'Мишка'),
    ObjectSpec('doll', 'Кукла'),
    ObjectSpec('blocks', 'Кубики'),
    ObjectSpec('pyramid', 'Пирамидка'),
    ObjectSpec('toy_car', 'Машинка'),
    ObjectSpec('spinning_top', 'Юла'),
    ObjectSpec('drum', 'Барабан'),
  ]),
  // The second agreed exception to the 7-object cap: the beach looked
  // empty with 7, so five more objects were drawn into the art. scene.json
  // gives the sea itself ("sea_1".."sea_5") and the umbrella ("umbrella_1"
  // canopy, "umbrella_2" pole) several tap zones each, reusing one recording.
  SceneSpec('sea', 'Море', [150, 210, 230], [
    ObjectSpec('sea', 'Море'),
    ObjectSpec('sun', 'Солнце'),
    ObjectSpec('seashell', 'Ракушка'),
    ObjectSpec('crab', 'Краб'),
    ObjectSpec('fish', 'Рыбка'),
    ObjectSpec('boat', 'Лодка'),
    ObjectSpec('umbrella', 'Зонтик'),
    ObjectSpec('seagull', 'Чайка'),
    ObjectSpec('cloud', 'Облако'),
    ObjectSpec('sandcastle', 'Замок'),
    ObjectSpec('starfish', 'Морская звезда'),
    ObjectSpec('turtle', 'Черепаха'),
  ]),
];
