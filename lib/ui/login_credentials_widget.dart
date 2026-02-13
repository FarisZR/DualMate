import 'package:dualmate/common/i18n/localizations.dart';
import 'package:flutter/material.dart';

const String _dualisAutofillHost = "dualis.dhbw.de";
const String _dualisAutofillUrl = "https://dualis.dhbw.de/";

class LoginCredentialsWidget extends StatefulWidget {
  final TextEditingController usernameEditingController;
  final TextEditingController passwordEditingController;
  final VoidCallback onSubmitted;

  const LoginCredentialsWidget({
    Key? key,
    required this.usernameEditingController,
    required this.passwordEditingController,
    required this.onSubmitted,
  }) : super(key: key);

  @override
  _LoginCredentialsWidgetState createState() => _LoginCredentialsWidgetState(
        usernameEditingController,
        passwordEditingController,
        onSubmitted,
      );
}

class _LoginCredentialsWidgetState extends State<LoginCredentialsWidget> {
  final TextEditingController _usernameEditingController;
  final TextEditingController _passwordEditingController;
  final VoidCallback _onSubmitted;

  final _focus = FocusNode();

  _LoginCredentialsWidgetState(
    this._usernameEditingController,
    this._passwordEditingController,
    this._onSubmitted,
  );

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Column(
        children: <Widget>[
          TextField(
            controller: _usernameEditingController,
            decoration: InputDecoration(
              hintText: L.of(context).loginUsername,
              icon: Icon(Icons.alternate_email),
            ),
            autofillHints: const [
              AutofillHints.username,
              _dualisAutofillHost,
              _dualisAutofillUrl,
            ],
            onSubmitted: (v) {
              FocusScope.of(context).requestFocus(_focus);
            },
            textInputAction: TextInputAction.next,
          ),
          TextField(
            controller: _passwordEditingController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: L.of(context).loginPassword,
              icon: Icon(Icons.lock_outline),
            ),
            autofillHints: const [
              AutofillHints.password,
              _dualisAutofillHost,
              _dualisAutofillUrl,
            ],
            focusNode: _focus,
            onSubmitted: (v) {
              _onSubmitted();
            },
          ),
        ],
      ),
    );
  }
}
