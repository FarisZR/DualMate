import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/dualis/ui/viewmodels/study_grades_view_model.dart';
import 'package:dualmate/dualis/ui/widgets/login_form_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DualisLoginPage extends StatelessWidget {
  const DualisLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    StudyGradesViewModel viewModel = Provider.of<StudyGradesViewModel>(context);
    return buildLoginPage(context, viewModel);
  }

  Widget buildLoginPage(BuildContext context, StudyGradesViewModel model) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(32),
            child: Container(
              constraints: BoxConstraints(maxWidth: 500),
              child: LoginForm(
                loginFailedText: L.of(context).dualisLoginFailed,
                title: Text(
                  L.of(context).dualisLogin,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                onLogin: model.login,
                onLoadCredentials: model.loadCredentials,
                onSaveCredentials: model.saveCredentials,
                onClearCredentials: model.clearCredentials,
                getDoSaveCredentials: model.getDoSaveCredentials,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
