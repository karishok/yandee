import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/models/sound_credit.dart';

/// Kept in docs/, next to animal-sounds-credits.md, and bundled from there,
/// so the About screen can never disagree with the credits document.
const soundCreditsAsset = 'docs/animal-sounds-credits.json';

/// One row of the About screen's sound credits: the object's name as the
/// child hears it, and who recorded its sound.
class SoundCreditLine {
  const SoundCreditLine({required this.label, required this.credit});

  final String label;
  final SoundCredit credit;
}

/// The bundled sound credits, each named after the object whose `sound` it
/// is in its scene's bundled scene.json (or by its id, if none is).
Future<List<SoundCreditLine>> loadSoundCredits(AssetBundle bundle) async {
  final credits = SoundCredit.listFromJson(
    jsonDecode(await bundle.loadString(soundCreditsAsset)) as Map<String, dynamic>,
  );
  final labelsByScene = <String, Map<String, String>>{};
  final lines = <SoundCreditLine>[];
  for (final credit in credits) {
    final labels = labelsByScene[credit.scene] ??= await _soundLabels(bundle, credit.scene);
    lines.add(SoundCreditLine(label: labels['${credit.id}_sound.wav'] ?? credit.id, credit: credit));
  }
  return lines;
}

/// sound file name -> object label, for one bundled scene.
Future<Map<String, String>> _soundLabels(AssetBundle bundle, String sceneId) async {
  try {
    final json = jsonDecode(await bundle.loadString('assets/demo_content/$sceneId/scene.json')) as Map<String, dynamic>;
    return {
      for (final object in (json['objects'] as List<dynamic>).cast<Map<String, dynamic>>())
        if (object['sound'] != null) object['sound'] as String: object['label'] as String,
    };
  } catch (_) {
    return const {};
  }
}
