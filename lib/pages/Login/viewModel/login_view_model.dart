import 'package:atv/archs/base/base_view_model.dart';
import 'package:atv/config/conf/app_conf.dart';
import 'package:atv/config/conf/route/app_route_settings.dart';
import 'package:atv/config/data/entity/Login/login_response.dart';
import 'package:atv/config/net/api_login.dart';
import 'package:atv/generated/locale_keys.g.dart';
import 'package:atv/widgetLibrary/complex/toast/lw_toast.dart';
import 'package:easy_localization/easy_localization.dart';

class LoginViewModel extends BaseViewModel {
  /// 是否选中了同意协议
  var isSelectedProtocol = false;

  /// 登录的邮箱名
  String emailName = '';

  /// 登录的密码
  String password = '';

  bool judgeEmailAndPassword() {
    return emailName.isNotEmpty && password.isNotEmpty;
  }

  void userNameLogin() async {
    if (judgeEmailAndPassword()) {
      if (isSelectedProtocol == false) {
        LWToast.show(LocaleKeys.agree_regist_or_login_tips.tr());
        return;
      }
      await loadApiData<LoginResponse>(
        ApiLogin.login(username: emailName, password: password),
        showLoading: true,
        handlePageState: false,
        dataSuccess: (data) {
          AppConf.afterLoginSuccess(
              Authorization: data.Authorization, Publickey: data.Publickey);
          // pagePush(AppRoute.main, needReplace: true, fullscreenDialog: true);
          pagePushAndRemoveUtil(
            AppRoute.main,
          );
        },
      );
    }
  }

  @override
  void initialize(args) {
    // TODO: implement initialize
  }

  @override
  void release() {
    // TODO: implement release
  }
}
