import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/auth_repository.dart';

class SignInWithGoogle {
  final AuthRepository repository;
  SignInWithGoogle(this.repository);

  Future<User?> call() async {
    return await repository.signInWithGoogle();
  }
}

class SignOut {
  final AuthRepository repository;
  SignOut(this.repository);

  Future<void> call() async {
    return await repository.signOut();
  }
}

class GetUserStream {
  final AuthRepository repository;
  GetUserStream(this.repository);

  Stream<User?> call() {
    return repository.user;
  }
}
