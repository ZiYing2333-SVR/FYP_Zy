import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FaceAuthService {

  /// ==============================
  /// FACE++ CONFIG
  /// ==============================
  static const String apiKey =
      "7ebd9lOz3FbTvbYwp3O1uvHfsiawC8Yo";

  static const String apiSecret =
      "t-LckgF61-Pe96Lrn0tdia0_n915Qimy";

  /// FaceSet ID (your face database)
  static const String faceSetId =
      "app_users_set";

  static final supabase =
      Supabase.instance.client;

  /// ==============================
  /// CAPTURE FACE
  /// ==============================
  static Future<File?> captureFace() async {
    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,

      /// 👇 Compress image
      imageQuality: 80,   // 0–100
      maxWidth: 800,
      maxHeight: 800,
    );

    if (image == null) return null;

    File file = File(image.path);

    print("Image size: ${await file.length()} bytes");

    return file;
  }


  /// ==============================
  /// DETECT FACE → Get face_token
  /// ==============================
  static Future<String?> detectFace(
      File imageFile) async {

    var request = http.MultipartRequest(
      'POST',
      Uri.parse(
        "https://api-us.faceplusplus.com/facepp/v3/detect",
      ),
    );

    request.fields['api_key'] = apiKey;
    request.fields['api_secret'] = apiSecret;

    request.files.add(
      await http.MultipartFile.fromPath(
        'image_file',
        imageFile.path,
      ),
    );

    var response = await request.send();
    var res =
    await http.Response.fromStream(response);

    print("Face++ Response: ${res.body}");


    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      if (data["faces"] != null &&
          data["faces"].isNotEmpty) {

        return data["faces"][0]["face_token"];
      }
    }

    return null;
  }

  /// ==============================
  /// CREATE FACESET (Run once)
  /// ==============================
  static Future<void> createFaceSet() async {

    final response = await http.post(
      Uri.parse(
        "https://api-us.faceplusplus.com/facepp/v3/faceset/create",
      ),
      body: {
        "api_key": apiKey,
        "api_secret": apiSecret,
        "display_name": "App Users",
        "outer_id": faceSetId,
      },
    );

    final data = jsonDecode(response.body);

    if (data["error_message"] != null) {

      if (data["error_message"] ==
          "FACESET_EXIST") {

        print("FaceSet already exists ✅");

      } else {

        print("Create FaceSet Error:");
        print(data);
      }

    } else {

      print("FaceSet created successfully ✅");
    }
  }



  /// ==============================
  /// ADD FACE TO FACESET
  /// ==============================
  static Future<void> addFaceToSet(
      String faceToken,
      String userId,
      ) async {

    final response = await http.post(
      Uri.parse(
        "https://api-us.faceplusplus.com/facepp/v3/faceset/addface",
      ),
      body: {
        "api_key": apiKey,
        "api_secret": apiSecret,
        "outer_id": faceSetId,
        "face_tokens": faceToken,
        "user_id": userId,
      },
    );

    print("AddFace Response:");
    print(response.body);
  }


  /// ==============================
  /// SEARCH FACE (LOGIN)
  /// ==============================
  static Future<bool> searchFace(
      String faceToken) async {

    final response = await http.post(
      Uri.parse(
        "https://api-us.faceplusplus.com/facepp/v3/search",
      ),
      body: {
        "api_key": apiKey,
        "api_secret": apiSecret,
        "face_token": faceToken,
        "outer_id": faceSetId,
      },
    );

    final data = jsonDecode(response.body);

    if (data["results"] != null &&
        data["results"].isNotEmpty) {

      double confidence =
      data["results"][0]["confidence"];

      return confidence > 80; // threshold
    }

    return false;
  }

  /// ==============================
  /// GENERATE FaceAuthId
  /// ==============================
  static Future<String> generateFaceAuthId() async {

    final supabase =
        Supabase.instance.client;

    /// Get last record
    final response = await supabase
        .from('FaceAuth')
        .select('faceAuthId')
        .order('faceAuthId',
        ascending: false)
        .limit(1);

    /// Default first ID
    String newId = "FA00001";

    if (response.isNotEmpty) {

      String lastId =
      response[0]['faceAuthId'];

      /// Extract number part
      int number =
      int.parse(lastId.substring(2));

      /// Increment
      number++;

      /// Rebuild ID
      newId =
      "FA${number.toString().padLeft(5, '0')}";
    }

    return newId;
  }


  /// ==============================
  /// SAVE DATABASE
  /// ==============================
  static Future<void> saveFaceToDatabase({
    required String faceToken,
    required String imagePath,
    required String userId,
  }) async {

    final supabase =
        Supabase.instance.client;

    /// 1️⃣ Generate ID
    String faceAuthId =
    await generateFaceAuthId();

    /// 2️⃣ Insert
    await supabase.from('FaceAuth').insert({

      'faceAuthId': faceAuthId,
      'faceToken': faceToken,
      'faceImagePath': imagePath,
      'createdAt':
      DateTime.now().toIso8601String(),
      'userId': userId,
    });

    print("Inserted ID: $faceAuthId");
  }

  static Future<String?> loginWithFace() async {

    /// 1️⃣ Capture
    File? image = await captureFace();
    if (image == null) return null;

    /// 2️⃣ Detect
    String? token = await detectFace(image);
    if (token == null) return null;

    /// 3️⃣ Search
    final response = await http.post(
      Uri.parse("https://api-us.faceplusplus.com/facepp/v3/search"),
      body: {
        "api_key": apiKey,
        "api_secret": apiSecret,
        "face_token": token,
        "outer_id": faceSetId,
      },
    );

    final data = jsonDecode(response.body);

    if (data["results"] == null || data["results"].isEmpty) {
      print("❌ No match");
      return null;
    }

    double confidence = data["results"][0]["confidence"];

    if (confidence < 75) return null;

    /// ✅ USE THIS INSTEAD OF user_id
    String matchedToken = data["results"][0]["face_token"];

    print("Matched Token: $matchedToken");

    /// 4️⃣ QUERY SUPABASE
    final record = await supabase
        .from('FaceAuth')
        .select()
        .eq('faceToken', matchedToken)
        .maybeSingle();

    if (record == null) {
      print("❌ No user found for token");
      return null;
    }

    String userId = record['userId'];

    print("✅ Login success for user: $userId");

    return userId;
  }

  /// ==============================
  /// DELETE FACESET (RESET)
  /// ==============================
  static Future<void> deleteFaceSet() async {

    final response = await http.post(
      Uri.parse(
        "https://api-us.faceplusplus.com/facepp/v3/faceset/delete",
      ),
      body: {
        "api_key": apiKey,
        "api_secret": apiSecret,
        "outer_id": faceSetId,
      },
    );

    print("Delete FaceSet Response:");
    print(response.body);
  }

  /// ==============================
  /// REMOVE ALL FACES
  /// ==============================
  static Future<void> removeAllFaces() async {

    final response = await http.post(
      Uri.parse(
        "https://api-us.faceplusplus.com/facepp/v3/faceset/removeface",
      ),
      body: {
        "api_key": apiKey,
        "api_secret": apiSecret,
        "outer_id": faceSetId,
        "face_tokens": "RemoveAllFaceTokens",
      },
    );

    print("Remove All Faces Response:");
    print(response.body);
  }



}
