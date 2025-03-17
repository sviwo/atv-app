import 'package:atv/archs/base/base_mvvm_page.dart';
import 'package:atv/archs/base/base_page.dart';
import 'package:atv/archs/utils/log_util.dart';
import 'package:atv/config/conf/app_conf.dart';
import 'package:atv/config/conf/app_icons.dart';
import 'package:atv/config/conf/route/app_route_settings.dart';
import 'package:atv/pages/Login/viewModel/login_view_model.dart';
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
    Future.delayed(Duration(seconds: 0), () {
      pagePush(AppRoute.main, needReplace: true, fullscreenDialog: true);
    });
    // AppConf.loginSuccess().then((value) {
    //   LogUtil.d('登录状态为$value');
    //   if (value) {
    //     pagePush(AppRoute.main, needReplace: true, fullscreenDialog: true);
    //   } else {
    //     pagePush(AppRoute.loginMain, needReplace: true, fullscreenDialog: true);
    //   }
    // });
  }

  @override
  Widget? headerBackgroundWidget() {
    // TODO: implement headerBackgroundWidget
    return Image.asset(
      AppIcons.imgLauchImageIcon,
      fit: BoxFit.cover,
    );
  }

  @override
  Widget buildBody(BuildContext context) {
    return Container(
      color: Colors.transparent,
    );
  }

  @override
  LoginViewModel viewModelProvider() => LoginViewModel();
}
