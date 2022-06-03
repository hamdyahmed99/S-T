import 'dart:io';
import 'dart:core';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farfromhome/ui/page_house_detail.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:multi_image_picker/multi_image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:multi_image_picker/src/asset.dart';
import 'package:path_provider/path_provider.dart';

var _status=true;
var _uploadStatus = false;
var _isImageSelected=false;

// class AddImages extends StatelessWidget{

//   var path;
//   AddImages(this.path);
//    @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Add House Images',
//       theme: ThemeData(brightness: Brightness.light),
//       home: MultiImage(path),
//     );
//   }
// }

class Choice {
  const Choice({this.title, this.icon});

  final String? title;
  final IconData? icon;
}

const List<Choice> choices = const <Choice>[
  const Choice(title: 'Upload', icon: Icons.cloud_upload),
  const Choice(title: 'Post House Deal', icon: Icons.check)
];

class ChoiceCard extends StatelessWidget {
  const ChoiceCard({this.choice});

  final Choice? choice;

  @override
  Widget build(BuildContext context) {
    final TextStyle? textStyle = Theme.of(context).textTheme.headline1;
    return Card(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(choice!.icon, size: 128.0, color: textStyle!.color),
            Text(choice!.title!, style: textStyle),
          ],
        ),
      ),
    );
  }
}

class MultiImage extends StatefulWidget {
  String? path;
  DocumentSnapshot? docSnap;
  MultiImage(this.path,this.docSnap);
  @override
  _MultiImageState createState() => new _MultiImageState(path,docSnap);
}

class _MultiImageState extends State<MultiImage> {
    List<Asset> images = [];
    List <String> imagePaths = [];
   String _error = 'No Error Dectected';
   String? path;
  DocumentSnapshot? docSnap;
   _MultiImageState(this.path, this.docSnap);
   @override
   void initState() {
     super.initState();
    _status=true;
    _uploadStatus = false;
    _isImageSelected=false;
   }

  String? filePath;
  Widget buildGridView() {
    return GridView.count(
      crossAxisCount: 3,
      children: List.generate(images.length, (index) {
        Asset asset = images[index];
        return AssetThumb(
          asset: asset,
          width: 300,
          height: 300,
        );
      }),
    );
  }
    Future<File> getImageFileFromAssets(Asset asset) async {
      final byteData = await asset.getByteData();

      final tempFile =
      File("${(await getTemporaryDirectory()).path}/${asset.name}");
      final file = await tempFile.writeAsBytes(
        byteData.buffer
            .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );

      return file;
    }

  List<String> imageDataPath = <String>[];
  late int i=0,len;
  Future<Null> _addImages(Asset pic) async {
      File file= await getImageFileFromAssets(pic);
      filePath = '${DateTime.now()}.png';
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference ref = storage.refFromURL('gs://sakan-talaba-c6f0f.appspot.com/').child(filePath!);
      UploadTask task = ref.putFile(file);
      TaskSnapshot storageTaskSnapshot = await task.whenComplete(() => null);
      String url = await storageTaskSnapshot.ref.getDownloadURL();
      
      //print("\nUploaded: "+url);
      //Download URL's 
      setState((){
        imageDataPath.add(url);
        i++;
      });
      if(len==i){
        setState(() {
          _status=!_status;
          _uploadStatus=!_uploadStatus;
          print('Upload State Changed');
        });
      }
  }

  //Uploading images
  Future<void> _uploadImages()async {
    setState(() {
      len = images.length;
      _uploadStatus=!_uploadStatus;
    });
    images.forEach((pic) {
      _addImages(pic);
    });
  }

  Future<void> loadAssets() async {
    List<Asset> resultList = [];
    String error = 'No Error Dectected';

    try {
      resultList = await MultiImagePicker.pickImages(
        maxImages: 300,
        enableCamera: true,
        selectedAssets: images,
        cupertinoOptions: CupertinoOptions(takePhotoIcon: "chat"),
        materialOptions: MaterialOptions(
          actionBarColor: "#1972d2",
          actionBarTitle: "Select Images",
          allViewTitle: "All Photos",
          useDetailsView: false,
          selectCircleStrokeColor: "#000000",
        ),
      );

      for (var r in resultList) {
        var t = r.name;
        //print(t);
      }
      if(resultList.isNotEmpty){
        setState(() {
          _isImageSelected = true;
        });
      }else{
        setState(() {
          _isImageSelected = false;
        });
      }
    } on Exception catch (e) {
      error = e.toString();
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      images = resultList;
      _error = error;
    });
  }
  var complete=0;
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      debugShowCheckedModeBanner: false,
      home: new Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
           title: Text("Add House Images"),
           backgroundColor: Colors.blue[700],
           actions: _isImageSelected ? <Widget>[
              // action button
              _status ? IconButton(
                icon: Icon(choices[0].icon),
                onPressed: () {
                  _uploadImages();
                },
              )
              : IconButton(
                icon: Icon(choices[1].icon),
                onPressed: () {
                  print('Saved');
                  FirebaseFirestore.instance.collection('House').doc(path).update({
                    'ReviewImage' : FieldValue.arrayUnion(imageDataPath) ,
                  }).whenComplete((){
                      print('Data Upload Complete');
                      Navigator.pushReplacement(context,MaterialPageRoute(builder: (_)=> HouseDetail(docSnap!)));
                  });
                },
              ),
           ] : null,
         ),
        body: _uploadStatus ? Center(child:new CircularProgressIndicator()) : new Column( 
          children: <Widget>[
            Expanded(
              child: buildGridView(),
            ),
          ],
        ),
        floatingActionButton: _status ? FloatingActionButton(
        onPressed: () {
          loadAssets();
        },
        child: Icon(Icons.add_a_photo),
        backgroundColor: Colors.blue[700],
      ): null,
      ),
    );
  }
}