import 'dart:io';

import 'package:atv/archs/base/base_app.dart';
import 'package:atv/archs/base/route_manager.dart';
import 'package:atv/archs/utils/log_util.dart';
import 'package:atv/config/conf/app_conf.dart';
import 'package:atv/config/conf/route/app_route_settings.dart';
import 'package:atv/generated/codegen_loader.g.dart';
import 'package:atv/pages/Login/splash_page.dart';
import 'package:atv/pages/MainPage/map_navi_page.dart';
import 'package:atv/pages/page_route.dart';
import 'package:atv/widgetLibrary/lw_widget.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:dio_log/interceptor/dio_log_interceptor.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
// import 'package:sentry_flutter/sentry_flutter.dart';

import 'archs/lw_arch.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class TestInheritedWidget extends InheritedWidget {
  const TestInheritedWidget({super.key, required this.child}) : super(child: child);

  final Widget child;

  static TestInheritedWidget? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TestInheritedWidget>();
  }

  @override
  bool updateShouldNotify(TestInheritedWidget oldWidget) {
    return true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // 网络日志配置
  DioLogInterceptor.enablePrintLog = false;

  var env = await AppConf.environment();
  bool mixDevelop = await AppConf.mixDevelop();
  var localLanguage = await AppConf.getLauguage();

  // 初始化架构库
  LWArch.init(
    env: env,
    token: (await AppConf.getHttpAuthorization()),
    baseUrl: (await AppConf.baseUrl),
    httpSuccessCodes: [
      '1',
      '200',
    ],
    mixDevelop: mixDevelop,
  );

  // 初始化谷歌地图
  _initMap();

  EasyLocalization.logger.printer = (object, {level, name, stackTrace}) {};
  return runApp(EasyLocalization(
    supportedLocales: const [
      Locale('zh'), // 汉语
      Locale('en'), // 英语
      Locale('es'), // 西班牙语
      Locale('fr'), // 法语
    ],
    path: 'resources/langs',
    fallbackLocale: const Locale('zh'), //TODO: 这里要改成en
    saveLocale: true, // 保存当前的local到本地
    useOnlyLangCode: true, // 只用语言标签，不用区域标签
    // assetLoader: const CodegenLoader(), //TODO: 等所有的key定义完成后再来生成这个
    assetLoader: const RootBundleAssetLoader(),
    useFallbackTranslations: true,
    child: MyApp(
      mixDevelop: mixDevelop,
      env: env,
      localLanguage: localLanguage,
    ),
  ));
  // // sentry为性能与BUG监听库
  // await SentryFlutter.init((options) async {
  //   options.dsn = '';
  //   options.tracesSampleRate = 1.0;
  //   options.environment = await AppConf.environment();
  //   options.anrEnabled = true;
  // }, appRunner: () async {
  //   // 网络日志配置
  //   DioLogInterceptor.enablePrintLog = false;

  //   var env = await AppConf.environment();
  //   bool mixDevelop = await AppConf.mixDevelop();
  //   var localLanguage = await AppConf.getLauguage();

  //   // 初始化架构库
  //   LWArch.init(
  //     env: env,
  //     token: (await AppConf.getHttpAuthorization()),
  //     baseUrl: (await AppConf.baseUrl),
  //     httpSuccessCodes: [
  //       '1',
  //       '200',
  //     ],
  //     mixDevelop: mixDevelop,
  //   );

  //   // 初始化谷歌地图
  //   _initMap();

  //   EasyLocalization.logger.printer = (object, {level, name, stackTrace}) {};
  //   return runApp(EasyLocalization(
  //     supportedLocales: const [
  //       Locale('zh'), // 汉语
  //       Locale('en'), // 英语
  //       Locale('es'), // 西班牙语
  //       Locale('fr'), // 法语
  //     ],
  //     path: 'resources/langs',
  //     fallbackLocale: const Locale('zh'), //TODO: 这里要改成en
  //     saveLocale: true, // 保存当前的local到本地
  //     useOnlyLangCode: true, // 只用语言标签，不用区域标签
  //     // assetLoader: const CodegenLoader(), //TODO: 等所有的key定义完成后再来生成这个
  //     assetLoader: const RootBundleAssetLoader(),
  //     useFallbackTranslations: true,
  //     child: MyApp(
  //       mixDevelop: mixDevelop,
  //       env: env,
  //       localLanguage: localLanguage,
  //     ),
  //   ));
  // });
}

_initMap() {}

class MyApp extends BaseApp {
  const MyApp({
    super.key,
    required this.mixDevelop,
    required this.env,
    required this.localLanguage,
  });

  final bool mixDevelop;

  final String env;

  final String localLanguage;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, Widget page) {
    LogUtil.d("++++++++++++++++++++++++++++");
    var environment0 = 'prod';
    if (env.isNotEmpty) {
      environment0 = env;
    }

    // 根据环境设置app名
    var appName = 'atv';
    if (StringUtils.isNotNullOrEmpty(environment0) && environment0 != 'prod') {
      appName += '.$environment0';
    }
    // 设置多语言
    var localeString =
        localLanguage.isNotEmpty ? localLanguage : context.locale.languageCode;
    if (StringUtils.isNullOrEmpty(localLanguage) == true) {
      AppConf.setLauguage(localeString);
    }
    LogUtil.d(
        '--------_environment:$environment0,appName:$appName,Lauguage:$localeString,_locale:$localeString');
    LWArch.setLanguage(localeString);
    var locale = Locale(localeString);
    return MaterialApp(
      title: appName,
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [
        _MyNavigator(),
        // SentryNavigatorObserver(),
      ],
      onGenerateRoute: RouteManager.instance.getRouteFactory(),
      color: Colors.white,
      theme: ThemeData(
        // platform: TargetPlatform.iOS,
        // primarySwatch: Color(0xFFE60044),
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSwatch()
            .copyWith(secondary: const Color(0x01FFFFFF)),
      ),
      //国际化配置
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: locale,
      home: mixDevelop ? page : SplashPage(route: AppRoute.splash),
      // home: MapNaviPage(),
      builder: EasyLoading.init(
        builder: (context, widget) {
          LWWidget.init(context, designWidth: 375, designHeight: 812);
          return GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: MediaQuery(
              //Setting font does not change with system font size
              data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
              child: widget ??
                  Container(
                    color: Colors.white,
                  ),
            ),
          );
        },
      ),
    );
  }

  @override
  void registerRoutes() {
    globalRegisterRoutes();
  }
}

class _MyNavigator extends NavigatorObserver {
  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    // LogUtil.d("didPop ${navigator?.widget.pages}");
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    // LogUtil.d("didPush ${navigator?.widget.pages}");
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    super.didRemove(route, previousRoute);
    // LogUtil.d("didRemove ${navigator?.widget.pages}");
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    // LogUtil.d("didReplace ${navigator?.widget.pages}");
  }

  @override
  void didStartUserGesture(Route route, Route? previousRoute) {
    super.didStartUserGesture(route, previousRoute);
    // LogUtil.d("didStartUserGesture ${navigator?.widget.pages}");
  }

  @override
  void didStopUserGesture() {
    super.didStopUserGesture();
    // LogUtil.d("didStopUserGesture ${navigator?.widget.pages}");
  }
}
