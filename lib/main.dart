import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:draw_over_image/painter_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

//import 'package:path_provider/path_provider.dart';
//import 'package:simple_permissions/simple_permissions.dart';

const directoryName = 'Signature';

void main() {
  runApp(MaterialApp(
    home: ExamplePage(),
    debugShowCheckedModeBanner: false,
  ));
}

class ImageEditor extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return ImageEditorState();
  }
}

class ImageEditorState extends State<ImageEditor> {
  GlobalKey<CustomDrawViewState> signatureKey = GlobalKey();
  var image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomDrawView(key: signatureKey),
      persistentFooterButtons: <Widget>[
        IconButton(
          icon: Icon(Icons.slideshow),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.color_lens),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.clear),
          onPressed: () {
            signatureKey.currentState.clearPoints();
          },
        ),
        IconButton(
          icon: Icon(Icons.save),
          onPressed: () {
            // Future will resolve later
            // so setState @image here and access in #showImage
            // to avoid @null Checks
            setRenderedImage(context);
          },
        )
      ],
    );
  }

  setRenderedImage(BuildContext context) async {
    ui.Image renderedImage = await signatureKey.currentState.rendered;

    setState(() {
      image = renderedImage;
    });
    var pngBytes =
        await renderedImage.toByteData(format: ui.ImageByteFormat.png);
    Navigator.of(context).push(MaterialPageRoute(
        builder: (BuildContext context) => FullScreenImage(
              pngBytes: pngBytes,
            )));
  }
}

class CustomDrawView extends StatefulWidget {
  CustomDrawView({Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return CustomDrawViewState();
  }
}

class CustomDrawViewState extends State<CustomDrawView> {
  // [CustomDrawViewState] responsible for receives drag/touch events by draw/user
  // @_points stores the path drawn which is passed to
  // [CustomDrawViewPainter]#contructor to draw canvas
  List<Offset> _points = <Offset>[];
  ui.Image image;
  bool isImageloaded = false;
  var paintController;
  Color activeColor = Color(0xFFFF0000);
  double strokeHeight = 5.0;

  void initState() {
    super.initState();
    init();
  }

  Future<Null> init() async {
    final ByteData data = await rootBundle.load('images/dummy.jpg');
    image = await loadImage(new Uint8List.view(data.buffer));
    _initiatePaintController();
  }

  void _initiatePaintController() {
    paintController = Paint()
      ..color = activeColor
      ..strokeCap = StrokeCap.square
      ..strokeWidth = strokeHeight;
  }

  Future<ui.Image> loadImage(List<int> img) async {
    final Completer<ui.Image> completer = new Completer();
    ui.decodeImageFromList(img, (ui.Image img) {
      setState(() {
        isImageloaded = true;
      });
      return completer.complete(img);
    });
    return completer.future;
  }

  Future<ui.Image> get rendered {
    // [CustomPainter] has its own @canvas to pass our
    // [ui.PictureRecorder] object must be passed to [Canvas]#contructor
    // to capture the Image. This way we can pass @recorder to [Canvas]#contructor
    // using @painter[CustomDrawViewPainter] we can call [CustomDrawViewPainter]#paint
    // with the our newly created @canvas
    ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas canvas = Canvas(recorder);
    CustomDrawViewPainter painter = CustomDrawViewPainter(
        points: _points, image: image, paintController: paintController);
    var size = context.size;
    painter.paint(canvas, size);
    return recorder
        .endRecording()
        .toImage(size.width.floor(), size.height.floor());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: GestureDetector(
          onPanUpdate: (DragUpdateDetails details) {
            setState(() {
              RenderBox _object = context.findRenderObject();
              Offset _locationPoints =
                  _object.localToGlobal(details.globalPosition);
              _points = new List.from(_points)..add(_locationPoints);
            });
          },
          onPanEnd: (DragEndDetails details) {
            setState(() {
              _points.add(null);
            });
          },
          child: isImageloaded
              ? CustomPaint(
                  painter: CustomDrawViewPainter(
                      points: _points,
                      image: image,
                      paintController: paintController),
                  size: Size.infinite,
                )
              : new Center(child: new Text('loading')),
        ),
      ),
    );
  }

  // clearPoints method used to reset the canvas
  // method can be called using
  //   key.currentState.clearPoints();
  void clearPoints() {
    setState(() {
      _points.clear();
    });
  }

  void openColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          titlePadding: const EdgeInsets.all(0.0),
          contentPadding: const EdgeInsets.all(0.0),
          content: SingleChildScrollView(
//            child: ColorPicker(
//              pickerColor: activeColor,
//              onColorChanged: (Color chosenColor) {
//                setState(() {
//                  activeColor = chosenColor;
//                });
//              },
//              colorPickerWidth: 300.0,
//              pickerAreaHeightPercent: 0.7,
//              enableAlpha: true,
//              displayThumbColor: true,
//              showLabel: true,
//              paletteType: PaletteType.hsv,
//              pickerAreaBorderRadius: const BorderRadius.only(
//                topLeft: const Radius.circular(2.0),
//                topRight: const Radius.circular(2.0),
//              ),
//            ),
            child: ColorPicker(
              pickerColor: activeColor,
              onColorChanged: (Color chosenColor) {
                setState(() {
                  activeColor = chosenColor;
                });
                _initiatePaintController();
              },
              showLabel: true,
              pickerAreaHeightPercent: 0.9,
            ),
          ),
        );
      },
    );
  }
}

class CustomDrawViewPainter extends CustomPainter {
  // [CustomDrawViewPainter] receives points through constructor
  // @points holds the drawn path in the form (x,y) offset;
  // This class responsible for drawing only
  // It won't receive any drag/touch events by draw/user.
  List<Offset> points = <Offset>[];
  ui.Image image;
  var paintController;

  CustomDrawViewPainter({this.points, this.image, this.paintController});

  @override
  void paint(Canvas canvas, Size size) {
    final outputRect =
        Rect.fromPoints(ui.Offset.zero, ui.Offset(size.width, size.height));
    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());
    final FittedSizes sizes =
        applyBoxFit(BoxFit.contain, imageSize, outputRect.size);
    final Rect inputSubrect =
        Alignment.center.inscribe(sizes.source, Offset.zero & imageSize);
    final Rect outputSubrect =
        Alignment.center.inscribe(sizes.destination, outputRect);
    canvas.drawImageRect(image, inputSubrect, outputSubrect, paintController);

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i], points[i + 1], paintController);
      }
    }
  }

  @override
  bool shouldRepaint(CustomDrawViewPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class FullScreenImage extends StatelessWidget {
  final dynamic pngBytes;

  const FullScreenImage({Key key, this.pngBytes}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        body: Container(
      child: Image.memory(Uint8List.view(pngBytes.buffer)),
    ));
  }
}
