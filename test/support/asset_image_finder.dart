import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds every [Image] showing the bundled picture at [path]. Pass
/// `skipOffstage: false` to count hidden ones too, such as a monster's
/// faces that are loaded but not shown.
Finder findAssetImage(String path, {bool skipOffstage = true}) => find.byWidgetPredicate(
      (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == path,
      description: 'image $path',
      skipOffstage: skipOffstage,
    );
