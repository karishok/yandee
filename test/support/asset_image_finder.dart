import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds every [Image] showing the bundled picture at [path].
Finder findAssetImage(String path) => find.byWidgetPredicate(
      (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == path,
      description: 'image $path',
    );
