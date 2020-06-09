import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

//import 'package:path_provider/path_provider.dart';
//import 'package:simple_permissions/simple_permissions.dart';

const directoryName = 'Signature';

void main() {
  runApp(MaterialApp(
    home: SignApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class SignApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return SignAppState();
  }
}

class SignAppState extends State<SignApp> {
  GlobalKey<SignatureState> signatureKey = GlobalKey();
  var image;
  String _platformVersion = 'Unknown';

//  Permission _permission = Permission.WriteExternalStorage;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Signature(key: signatureKey),
      persistentFooterButtons: <Widget>[
        FlatButton(
          child: Text('Clear'),
          onPressed: () {
            signatureKey.currentState.clearPoints();
          },
        ),
        FlatButton(
          child: Text('Save'),
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

    print('image ${renderedImage.toString()}');
    setState(() {
      image = renderedImage;
    });
    var pngBytes =
        await renderedImage.toByteData(format: ui.ImageByteFormat.png);
    Navigator.of(context).push(MaterialPageRoute(
        builder: (BuildContext context) => FullScreenImage(
              pngBytes: pngBytes,
            )));
//    showImage(context);
  }

  Future<Null> showImage(BuildContext context) async {
    var pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
//    if(!(await checkPermission())) await requestPermission();
//    // Use plugin [path_provider] to export image to storage
//    Directory directory = await getExternalStorageDirectory();
//    String path = directory.path;
//    print(path);
//    await Directory('$path/$directoryName').create(recursive: true);
//    File('$path/$directoryName/${formattedDate()}.png')
//        .writeAsBytesSync(pngBytes.buffer.asInt8List());
//    return showDialog<Null>(
//        context: context,
//        builder: (BuildContext context) {
//          return AlertDialog(
//            title: Text(
//              'Please check your device\'s Signature folder',
//              style: TextStyle(
//                  fontFamily: 'Roboto',
//                  fontWeight: FontWeight.w300,
//                  color: Theme.of(context).primaryColor,
//                  letterSpacing: 1.1
//              ),
//            ),
//            content: Image.memory(Uint8List.view(pngBytes.buffer)),
//          );
//        }
//    );
  }

  String formattedDate() {
    DateTime dateTime = DateTime.now();
    String dateTimeString = 'Signature_' +
        dateTime.year.toString() +
        dateTime.month.toString() +
        dateTime.day.toString() +
        dateTime.hour.toString() +
        ':' +
        dateTime.minute.toString() +
        ':' +
        dateTime.second.toString() +
        ':' +
        dateTime.millisecond.toString() +
        ':' +
        dateTime.microsecond.toString();
    return dateTimeString;
  }

//  requestPermission() async {
//    bool result = await SimplePermissions.requestPermission(_permission);
//    return result;
//  }
//
//  checkPermission() async {
//    bool result = await SimplePermissions.checkPermission(_permission);
//    return result;
//  }
//
//  getPermissionStatus() async {
//    final result = await SimplePermissions.getPermissionStatus(_permission);
//    print("permission status is " + result.toString());
//  }

}

class Signature extends StatefulWidget {
  Signature({Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return SignatureState();
  }
}

class SignatureState extends State<Signature> {
  // [SignatureState] responsible for receives drag/touch events by draw/user
  // @_points stores the path drawn which is passed to
  // [SignaturePainter]#contructor to draw canvas
  List<Offset> _points = <Offset>[];
  ui.Image image;
  bool isImageloaded = false;

  void initState() {
    super.initState();
    init();
  }

  Future<Null> init() async {
    final ByteData data = await rootBundle.load('images/dummy.jpg');
    image = await loadImage(new Uint8List.view(data.buffer));
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
    // using @painter[SignaturePainter] we can call [SignaturePainter]#paint
    // with the our newly created @canvas
    ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas canvas = Canvas(recorder);
    SignaturePainter painter = SignaturePainter(points: _points, image: image);
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
                  painter: SignaturePainter(points: _points, image: image),
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
}

class SignaturePainter extends CustomPainter {
  // [SignaturePainter] receives points through constructor
  // @points holds the drawn path in the form (x,y) offset;
  // This class responsible for drawing only
  // It won't receive any drag/touch events by draw/user.
  List<Offset> points = <Offset>[];
  ui.Image image;

  SignaturePainter({this.points, this.image});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.blue
      ..strokeCap = StrokeCap.square
      ..strokeWidth = 5.0;

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
    canvas.drawImageRect(image, inputSubrect, outputSubrect, paint);

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) {
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


