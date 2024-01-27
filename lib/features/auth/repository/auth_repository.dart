import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_vahak/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());
final authStateChangesProvider = StreamProvider<User?>((ref) {
  final authController = ref.watch(authRepositoryProvider);
  return authController.authStateChanges;
});

// Provider for UserModel. It uses StateProvider to manage the state of the user.
final userIdprovider = StateProvider<String>((ref) => '');
final userProvider = StateProvider<UserModel?>((ref) => null);

class AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  User? get currentUser => _firebaseAuth.currentUser;

  CollectionReference users = FirebaseFirestore.instance.collection('users');

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
    required WidgetRef ref,
  }) async {
    try {
      //use userCredential to get the user's uid
      //add that to the ticket aswell

      UserCredential userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);
      UserModel userModel = await getUserData(userCredential.user!.uid).first;
      ref.read(userIdprovider.notifier).update((state) => userModel.uid);
      ref.read(userProvider.notifier).update((state) => userModel);


      // Save the sign-in state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('signedIn', true);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<void> createUserWithEmailAndPassword({
    required WidgetRef ref,
    required String email,
    required String password,
    required int adharNumber,
  }) async {
    try {
      if (adharNumber.toString().length != 12) {
        throw Exception('Adhar number should be 12 digits');
      }
      UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user?.uid??'';
      UserModel userModel = UserModel(
        name: 'name',
        email: email,
        password: password,
        uid: uid,
        adharNumber: adharNumber,
      );
      CollectionReference users =
          FirebaseFirestore.instance.collection('users');

      // Add the user model to Firestore
      await users.doc(uid).set(userModel.toMap());
      ref.read(userIdprovider.notifier).update((state) => uid);
      ref.read(userProvider.notifier).update((state) => userModel);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        if (kDebugMode) {
          print('The password provided is too weak.');
        }
      } else if (e.code == 'email-already-in-use') {
        if (kDebugMode) {
          print('The account already exists for that email.');
        }
      } else {
        if (kDebugMode) {
          print(e);
        }
      }
    }
  }

  Future<void> signOut(WidgetRef ref) async {
    await _firebaseAuth.signOut();
    ref.read(userIdprovider.notifier).update((state) => '');
    // Clear the sign-in state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('signedIn', false);
  }

  Future<bool> isSignedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('signedIn') ?? false;
  }

  // This method retrieves a user's data from Firestore and maps it to a UserModel object.
  // It returns a Stream<UserModel>, which means it provides the user model in a stream that updates whenever the user's data changes in Firestore.
  Stream<UserModel> getUserData(String uid) {
    return users.doc(uid).snapshots().map(
        (event) => UserModel.fromMap(event.data() as Map<String, dynamic>));
  }
}
