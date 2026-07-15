import 'package:flutter/material.dart';

class TitleListTile extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const TitleListTile({Key? key, required this.title, this.trailing})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodySmall ?? const TextStyle(),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
