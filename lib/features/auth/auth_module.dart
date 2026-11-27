import 'package:flutter/material.dart';

import 'presentation/screens/auth_gate_screen.dart';
import 'presentation/screens/profile_screen.dart';
import 'presentation/screens/sign_in_screen.dart';
import 'presentation/screens/sign_up_screen.dart';

export 'data/auth_repository.dart' show AuthModuleException, AuthRepository;
export 'data/models/user_profile.dart';
export 'presentation/providers/auth_providers.dart';

/// Public entry points for MOD-05: account, authentication, and profile.
///
/// Initialize Firebase before mounting this module. Applications can mount
/// [buildGate] at startup and provide their own authenticated app shell, or
/// place [buildProfileScreen] in the account tab of their navigation shell.
class AuthModule {
  const AuthModule._();

  static const String gateRoute = '/auth';
  static const String signInRoute = '/auth/sign-in';
  static const String signUpRoute = '/auth/sign-up';
  static const String profileRoute = '/auth/profile';

  static Map<String, WidgetBuilder> get routes => {
        gateRoute: (_) => const AuthGateScreen(),
        signInRoute: (_) => const SignInScreen(),
        signUpRoute: (_) => const SignUpScreen(),
        profileRoute: (_) => const ProfileScreen(),
      };

  static Widget buildGate({WidgetBuilder? authenticatedBuilder}) =>
      AuthGateScreen(authenticatedBuilder: authenticatedBuilder);

  static Widget buildSignInScreen() => const SignInScreen();

  static Widget buildSignUpScreen() => const SignUpScreen();

  static Widget buildProfileScreen() => const ProfileScreen();

  static Future<void> openProfile(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
    );
  }
}
