import 'package:dualmate/common/util/cancellation_token.dart';
import 'package:dualmate/dualis/service/dualis_service.dart';
import 'package:dualmate/dualis/service/dualis_website_model.dart';
import 'package:dualmate/dualis/service/parsing/access_denied_extract.dart';
import 'package:dualmate/dualis/service/parsing/login_redirect_url_extract.dart';
import 'package:dualmate/dualis/service/parsing/timeout_extract.dart';
import 'package:dualmate/dualis/service/parsing/urls_from_main_page_extract.dart';
import 'package:dualmate/dualis/service/session.dart';
import 'package:dualmate/schedule/service/schedule_source.dart';
import 'package:http/http.dart';

///
/// This class handles the dualis authentication. To make api calls first login
/// with the username and password and then use the [authenticatedGet] method.
///
class DualisAuthentication {
  final RegExp _tokenRegex = RegExp("ARGUMENTS=-N([0-9]{15})");

  late String _username;
  late String _password;

  late DualisUrls _dualisUrls;
  DualisUrls get dualisUrls => _dualisUrls;

  String _authToken = "";
  late Session _session;

  LoginResult _loginState = LoginResult.LoggedOut;
  LoginResult get loginState => _loginState;

  Future<LoginResult> login(
    String username,
    String password,
    CancellationToken cancellationToken,
  ) async {
    _dualisUrls = DualisUrls();

    this._username = username;
    this._password = password;

    _session = Session();

    var loginResponse = await _makeLoginRequest(
      username,
      password,
      cancellationToken,
    );

    if (loginResponse == null ||
        loginResponse.statusCode != 200 ||
        !loginResponse.headers.containsKey("refresh")) {
      _loginState = LoginResult.LoginFailed;
      return loginState;
    }

    // TODO: Test for login failed page

    var refreshHeader = loginResponse.headers['refresh'];
    if (refreshHeader == null) {
      _loginState = LoginResult.LoginFailed;
      return loginState;
    }

    var redirectUrl = LoginRedirectUrlExtract().getUrlFromHeader(
      refreshHeader,
      dualisEndpoint,
    );

    if (redirectUrl == null) {
      _loginState = LoginResult.LoginFailed;
      return loginState;
    }

    var redirectPage = await _session.get(
      redirectUrl,
      cancellationToken,
    );

    var mainPageUrl = LoginRedirectUrlExtract().readRedirectUrl(
      redirectPage,
      dualisEndpoint,
    );

    if (mainPageUrl == null || mainPageUrl.isEmpty) {
      _loginState = LoginResult.LoginFailed;
      return loginState;
    }

    dualisUrls.mainPageUrl = mainPageUrl;

    _updateAccessToken(dualisUrls.mainPageUrl);

    var mainPage = await _session.get(
      dualisUrls.mainPageUrl,
      cancellationToken,
    );

    UrlsFromMainPageExtract().parseMainPage(
      mainPage,
      dualisUrls,
      dualisEndpoint,
    );

    _loginState = LoginResult.LoggedIn;
    return loginState;
  }

  Future<Response?> _makeLoginRequest(
    String user,
    String password, [
    CancellationToken? cancellationToken,
  ]) async {
    var loginUrl = dualisEndpoint + "/scripts/mgrqispi.dll";

    var data = {
      "usrname": user,
      "pass": password,
      "APPNAME": "CampusNet",
      "PRGNAME": "LOGINCHECK",
      "ARGUMENTS": "clino,usrname,pass,menuno,menu_type,browser,platform",
      "clino": "000000000000001",
      "menuno": "000324",
      "menu_type": "classic",
      "browser": "",
      "platform": "",
    };

    try {
      var loginResponse = await _session.rawPost(
        loginUrl,
        data,
        cancellationToken ?? CancellationToken(),
      );
      return loginResponse;
    } on ServiceRequestFailed {
      return null;
    }
  }

  ///
  /// Use this method to make GET requests to the dualis service.
  ///
  /// This method handles the authentication cookie and token. If the session
  /// timed out, it will renew the session by logging in again
  ///
  Future<String> authenticatedGet(
    String url,
    CancellationToken cancellationToken,
  ) async {
    var result = await _session.get(
      _fillUrlWithAuthToken(url),
      cancellationToken,
    );

    cancellationToken.throwIfCancelled();

    if (!TimeoutExtract().isTimeoutErrorPage(result) &&
        !AccessDeniedExtract().isAccessDeniedPage(result)) {
      return result;
    }

    var loginResult = await login(_username, _password, cancellationToken);

    if (loginResult == LoginResult.LoggedIn) {
      return await _session.get(
        _fillUrlWithAuthToken(url),
        cancellationToken,
      );
    }

    return "";
  }

  Future<void> logout([
    CancellationToken? cancellationToken,
  ]) async {
    var logoutRequest = _session.get(
      dualisUrls.logoutUrl,
      cancellationToken ?? CancellationToken(),
    );

    _session = Session();
    _dualisUrls = DualisUrls();
    _loginState = LoginResult.LoggedOut;

    await logoutRequest;
  }

  ///
  /// After the login sequence call this method with an url which contains the
  /// new authentication token. The url of every subsequent api call must be
  /// wrapped in a [fillUrlWithAuthToken()] call
  ///
  void _updateAccessToken(String urlWithNewToken) {
    var tokenMatch = _tokenRegex.firstMatch(urlWithNewToken);

    if (tokenMatch == null) return;

    _authToken = tokenMatch.group(1) ?? _authToken;
  }

  ///
  /// The dualis urls contain an authentication token which changes with every new login.
  /// When an api call is made with an old authentication token it will result in a
  /// permission denied error. So before every api call you have to fill in the
  /// updated api token
  ///
  String _fillUrlWithAuthToken(String url) {
    var match = _tokenRegex.firstMatch(url);
    if (match != null) {
      return url.replaceRange(
          match.start, match.end, "ARGUMENTS=-N$_authToken");
    }

    return url;
  }

  void setLoginCredentials(String username, String password) {
    _username = username;
    _password = password;
  }

  Future<LoginResult> loginWithPreviousCredentials(
      CancellationToken cancellationToken) async {
    return await login(_username, _password, cancellationToken);
  }
}
