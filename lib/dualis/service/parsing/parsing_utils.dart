import 'package:html/dom.dart';
import 'package:html/parser.dart' show parseFragment;

String trimAndEscapeString(String htmlString) {
  return parseFragment(htmlString).text?.trim() ?? '';
}

Element getElementByTagName(
  Document document,
  String localName, [
  int index = 0,
]) {
  var list = document.getElementsByTagName(localName);

  if (index >= list.length) throw ElementNotFoundParseException(localName);

  return list[index];
}

Element getElementByClassName(
  Document document,
  String className, [
  int index = 0,
]) {
  var list = document.getElementsByClassName(className);

  if (index >= list.length) throw ElementNotFoundParseException(className);

  return list[index];
}

Element getElementById(
  Document document,
  String id,
) {
  var element = document.getElementById(id);

  if (element == null) throw ElementNotFoundParseException(id);

  return element;
}

class ParseException implements Exception {
  Object innerException;
  StackTrace trace;

  ParseException.withInner(this.innerException, this.trace);

  @override
  String toString() {
    return "Parse exception: $innerException \n$trace";
  }
}

class ElementNotFoundParseException implements ParseException {
  @override
  late Object innerException;

  @override
  late StackTrace trace;

  final String elementDescription;

  ElementNotFoundParseException(this.elementDescription);

  @override
  String toString() {
    return "Did not find: $elementDescription";
  }
}
