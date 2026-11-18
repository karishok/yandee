/// Grammatical gender of a Russian noun. The colour word in front of a food
/// has to agree with it: «красная клубника», «красный помидор», «красное
/// мороженое».
enum Gender { masculine, feminine, neuter }

/// The colours the "Монстрики" game teaches, in the order a child meets
/// them: the first [startingCount] are on screen from the start, each later
/// one arrives when a fed monster leaves.
///
/// Every word form the voice needs is spelled out rather than derived —
/// Russian colour adjectives don't share one ending pattern («синий/синяя»,
/// «голубой/голубая», «красный/красная»).
enum MonsterColor {
  red(masculine: 'красный', feminine: 'красная', neuter: 'красное', dative: 'красному'),
  blue(masculine: 'синий', feminine: 'синяя', neuter: 'синее', dative: 'синему'),
  yellow(masculine: 'жёлтый', feminine: 'жёлтая', neuter: 'жёлтое', dative: 'жёлтому'),
  green(masculine: 'зелёный', feminine: 'зелёная', neuter: 'зелёное', dative: 'зелёному'),
  orange(masculine: 'оранжевый', feminine: 'оранжевая', neuter: 'оранжевое', dative: 'оранжевому'),
  purple(masculine: 'фиолетовый', feminine: 'фиолетовая', neuter: 'фиолетовое', dative: 'фиолетовому'),
  pink(masculine: 'розовый', feminine: 'розовая', neuter: 'розовое', dative: 'розовому'),
  brown(masculine: 'коричневый', feminine: 'коричневая', neuter: 'коричневое', dative: 'коричневому'),
  lightblue(masculine: 'голубой', feminine: 'голубая', neuter: 'голубое', dative: 'голубому'),
  white(masculine: 'белый', feminine: 'белая', neuter: 'белое', dative: 'белому'),
  black(masculine: 'чёрный', feminine: 'чёрная', neuter: 'чёрное', dative: 'чёрному');

  const MonsterColor({
    required this.masculine,
    required this.feminine,
    required this.neuter,
    required this.dative,
  });

  /// «красный» — also how a monster names itself: «Я красный!».
  final String masculine;
  final String feminine;
  final String neuter;

  /// «красному» — "it is for the red one".
  final String dative;

  /// How many colours are on screen when a game starts.
  static const startingCount = 4;

  /// The colour word agreeing with a noun of [gender].
  String adjective(Gender gender) => switch (gender) {
        Gender.masculine => masculine,
        Gender.feminine => feminine,
        Gender.neuter => neuter,
      };
}
