import 'package:flutter/material.dart';
import 'dart:io';
import 'face_auth_service.dart';

class SetUpFacePage extends StatefulWidget {
  const SetUpFacePage({super.key});

  @override
  State<SetUpFacePage> createState() =>
      _SetUpFacePageState();
}

class _SetUpFacePageState
    extends State<SetUpFacePage> {

  /// =====================================================
  /// REGISTER FACE
  /// =====================================================
  Future<void> scanAndRegisterFace() async {

    try {

      /// 1️⃣ Capture
      File? image =
      await FaceAuthService.captureFace();

      if (image == null) {
        showFailDialog();
        return;
      }

      /// 2️⃣ Detect
      String? faceToken =
      await FaceAuthService.detectFace(
          image);

      if (faceToken == null) {
        showFailDialog();
        return;
      }

      /// 3️⃣ Add to FaceSet
      await FaceAuthService.addFaceToSet(
          faceToken);

      /// 4️⃣ Save DB
      await FaceAuthService.saveFaceToDatabase(
        faceToken: faceToken,
        imagePath: image.path,
      );

      /// SUCCESS
      showSuccessDialog();

    } catch (e) {
      debugPrint("Register Error: $e");
      showFailDialog();
    }
  }

  /// =====================================================
  /// LOGIN WITH FACE
  /// =====================================================
  Future<void> loginWithFace() async {

    String? userId =
    await FaceAuthService.loginWithFace();

    if (userId != null) {

      showLoginSuccessDialog(userId);

    } else {

      showLoginFailDialog();
    }
  }


  /// =====================================================
  /// SUCCESS REGISTER DIALOG
  /// =====================================================
  void showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(20),
          ),
          child: Container(
            padding:
            const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color:
              const Color(0xFFF6F3D6),
              borderRadius:
              BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [

                const CircleAvatar(
                  radius: 30,
                  backgroundColor:
                  Colors.green,
                  child: Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 35,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Set up Successfully!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 25),

                /// LOGIN BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                          context);
                      loginWithFace();
                    },
                    style:
                    ElevatedButton
                        .styleFrom(
                      backgroundColor:
                      const Color(
                          0xFFA7E399),
                      padding:
                      const EdgeInsets
                          .symmetric(
                          vertical:
                          14),
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius
                            .circular(
                            30),
                      ),
                    ),
                    child: const Text(
                      "Login With Face ID",
                      style: TextStyle(
                          color:
                          Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// =====================================================
  /// FAIL DIALOG
  /// =====================================================
  void showFailDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(20),
          ),
          child: Container(
            padding:
            const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color:
              const Color(0xFFF6F3D6),
              borderRadius:
              BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [

                const CircleAvatar(
                  radius: 30,
                  backgroundColor:
                  Colors.red,
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 35,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Fail to Set up Face ID",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                /// TIPS
                Column(
                  children: [

                    /// TIP 1
                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [

                        Container(
                          width: 28,
                          height: 28,
                          decoration:
                          const BoxDecoration(
                            color:
                            Colors.green,
                            shape: BoxShape
                                .circle,
                          ),
                          alignment:
                          Alignment.center,
                          child:
                          const Text(
                            "1",
                            style:
                            TextStyle(
                              color: Colors
                                  .white,
                              fontWeight:
                              FontWeight
                                  .bold,
                            ),
                          ),
                        ),

                        const SizedBox(
                            width: 12),

                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [

                              Text(
                                "Good Lighting",
                                style:
                                TextStyle(
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                ),
                              ),

                              SizedBox(
                                  height: 4),

                              Text(
                                "Make sure you are in a well lit area and both ears are uncovered.",
                                style: TextStyle(
                                    fontSize:
                                    13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    /// TIP 2
                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [

                        Container(
                          width: 28,
                          height: 28,
                          decoration:
                          const BoxDecoration(
                            color:
                            Colors.green,
                            shape: BoxShape
                                .circle,
                          ),
                          alignment:
                          Alignment.center,
                          child:
                          const Text(
                            "2",
                            style:
                            TextStyle(
                              color: Colors
                                  .white,
                              fontWeight:
                              FontWeight
                                  .bold,
                            ),
                          ),
                        ),

                        const SizedBox(
                            width: 12),

                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [

                              Text(
                                "Look straight",
                                style:
                                TextStyle(
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                ),
                              ),

                              SizedBox(
                                  height: 4),

                              Text(
                                "Hold your phone at eye level and look straight to the camera.",
                                style: TextStyle(
                                    fontSize:
                                    13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                        context);
                    scanAndRegisterFace();
                  },
                  style:
                  ElevatedButton
                      .styleFrom(
                    backgroundColor:
                    const Color(
                        0xFFA7E399),
                  ),
                  child: const Text(
                    "Scan My Face",
                    style: TextStyle(
                        color:
                        Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// =====================================================
  /// LOGIN SUCCESS DIALOG
  /// =====================================================
  void showLoginSuccessDialog(
      String userId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(20),
          ),
          child: Container(
            padding:
            const EdgeInsets.all(24),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [

                const CircleAvatar(
                  radius: 30,
                  backgroundColor:
                  Colors.green,
                  child: Icon(
                    Icons.lock_open,
                    color: Colors.white,
                    size: 30,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Login Successful",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "User ID: $userId",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);

                    Navigator
                        .pushReplacementNamed(
                        context,
                        "/home");
                  },
                  child: const Text(
                      "Enter"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showLoginFailDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(20),
          ),
          child: Container(
            padding:
            const EdgeInsets.all(24),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [

                const CircleAvatar(
                  radius: 30,
                  backgroundColor:
                  Colors.red,
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 30,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Face Login Failed",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Face not recognized.\nPlease try again.",
                  textAlign:
                  TextAlign.center,
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                        context);
                    loginWithFace();
                  },
                  child:
                  const Text("Retry"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  /// =====================================================
  /// UI
  /// =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFFEFFD3),

      appBar: AppBar(
        backgroundColor:
        const Color(0xFFFEFFD3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),

      body: Padding(
        padding:
        const EdgeInsets.symmetric(
            horizontal: 24),
        child: Column(
          children: [

            const SizedBox(height: 10),

            const Text(
              "Set up Face ID",
              style: TextStyle(
                fontSize: 23,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(height: 35),

            const Text(
              "Unlock with your FaceID, quick and secured.",
              textAlign:
              TextAlign.center,
            ),

            const SizedBox(height: 60),

            Image.asset(
              "assets/images/facialId.png",
              width: 250,
              height: 250,
            ),

            const SizedBox(height: 110),

            Row(
              children: [

                Expanded(
                  flex: 1,
                  child:
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                          context);
                    },
                    style:
                    ElevatedButton
                        .styleFrom(
                      backgroundColor:
                      Colors.grey,
                      foregroundColor:
                      Colors.white,
                    ),
                    child:
                    const Text(
                        "Skip"),
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  flex: 2,
                  child:
                  ElevatedButton(
                    onPressed: () {
                      scanAndRegisterFace();
                    },
                    style:
                    ElevatedButton
                        .styleFrom(
                      backgroundColor:
                      const Color(
                          0xFFA7E399),
                      foregroundColor:
                      Colors.white,
                    ),
                    child: const Text(
                        "Scan My Face"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// LOGIN DIRECT BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await loginWithFace();
                },
                icon: const Icon(
                  Icons.face,
                  color: Colors.white,
                ),
                label: const Text(
                  "Login With Face ID",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6EC6FF),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
