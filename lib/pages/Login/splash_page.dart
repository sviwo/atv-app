import 'package:atv/archs/base/base_mvvm_page.dart';
import 'package:atv/archs/base/base_page.dart';
import 'package:atv/archs/utils/log_util.dart';
import 'package:atv/config/conf/app_conf.dart';
import 'package:atv/config/conf/app_icons.dart';
import 'package:atv/config/conf/route/app_route_settings.dart';
import 'package:atv/pages/Login/viewModell/login_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';

class SplashPage extends BaseMvvmPage {
  SplashPage({super.key, super.route});

  @override
  State<StatefulWidget> createState() => _SplashPageState();
}

class _SplashPageState extends BaseMvvmPageState<SplashPage, LoginViewModel> {
  @override
  void initState() {
    super.initState();
    AppConf.loginSuccess().then((value) {
      LogUtil.d(value);
      if (value) {
        pagePush(AppRouteSettings.main, needReplace: true);
      } else {
        pagePush(AppRouteSettings.loginMain, needReplace: true);
      }
    });
  }

  @override
  Widget? headerBackgroundWidget() {
    // TODO: implement headerBackgroundWidget
    return Image.asset(
      AppIcons.imgLoginBg,
      fit: BoxFit.cover,
    );
  }

  @override
  void releaseVM() {}

  @override
  Widget buildBody(BuildContext context) {
    return Container();
  }

  @override
  LoginViewModel viewModelProvider() => LoginViewModel();
}
