import 'dart:async';
import 'package:flutter/material.dart';

import 'request/authorization_request.dart';
import 'model/config.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RequestCode {
  final Config _config;
  final AuthorizationRequest _authorizationRequest;
  final _redirectUriHost;
  late NavigationDelegate _navigationDelegate;
  String? _code;

  RequestCode(Config config)
      : _config = config,
        _authorizationRequest = AuthorizationRequest(config),
        _redirectUriHost = Uri.parse(config.redirectUri).host {
    _navigationDelegate = NavigationDelegate(
      onNavigationRequest: _onNavigationRequest,
    );
  }

  Future<String?> requestCode() async {
    _code = null;

    final urlParams = _constructUrlParams();
    final launchUri = Uri.parse('${_authorizationRequest.url}?$urlParams');
    final controller = WebViewController();
    await controller.setNavigationDelegate(_navigationDelegate);
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);

    await controller.setBackgroundColor(Colors.white);
    await controller.setUserAgent(_config.userAgent);
    await controller.loadRequest(launchUri);

    final webView = WebViewWidget(controller: controller);

    await _config.navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
            appBar: AppBar(
                leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                if (await controller.canGoBack()) {
                  controller.goBack();
                } else {
                  _config.navigatorKey.currentState!.pop();
                }
              },
            )),
            body: Container(
              color: Colors.white,
              child: SafeArea(
                  child: Stack(
                children: [
                  _config.loader,
                  webView,
                ],
              )),
            )),
      ),
    );
    return _code;
  }

  Future<NavigationDecision> _onNavigationRequest(
      NavigationRequest request) async {
    try {
      var uri = Uri.parse(request.url);

      if (uri.queryParameters['error'] != null) {
        _config.navigatorKey.currentState!.pop();
      }

      var checkHost = uri.host == _redirectUriHost;

      if (uri.queryParameters['code'] != null && checkHost) {
        _code = uri.queryParameters['code'];
        _config.navigatorKey.currentState!.pop();
      }
    } catch (_) {}
    return NavigationDecision.navigate;
  }

  Future<void> clearCookies() async {
    await WebViewCookieManager().clearCookies();
  }

  String _constructUrlParams() =>
      _mapToQueryParams(_authorizationRequest.parameters);

  String _mapToQueryParams(Map<String, String> params) {
    final queryParams = <String>[];
    params.forEach((String key, String value) =>
        queryParams.add('$key=${Uri.encodeQueryComponent(value)}'));
    return queryParams.join('&');
  }
}
