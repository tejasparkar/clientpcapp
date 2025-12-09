import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ["email", "profile"],
  );

  Future<String?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;

      // Send token to backend
      final res = await http.post(
        Uri.parse("https://yourserver.com/auth/oauth/google"),
        body: {"id_token": googleAuth.idToken},
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data["session_token"]; // return backend auth token
      }

      return null;
    } catch (e) {
      print("Google OAuth Error: $e");
      return null;
    }
  }
}
