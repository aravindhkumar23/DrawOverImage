import 'dart:typed_data';

import 'package:flutter/material.dart';

class ImagePreview extends StatelessWidget {
  final dynamic pngBytes;

  const ImagePreview({Key key, this.pngBytes}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
          title: Text('Image preview'),
        ),
        body: Container(
          alignment: Alignment.center,
          child: Image.memory(pngBytes),
        ));
  }
}
