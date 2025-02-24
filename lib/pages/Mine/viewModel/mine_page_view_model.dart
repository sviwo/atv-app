import 'dart:async';

import 'package:atv/archs/base/base_view_model.dart';
import 'package:atv/archs/base/event_manager.dart';
import 'package:atv/archs/data/err/http_error_exception.dart';
import 'package:atv/archs/utils/bluetooth/blue_tooth_util.dart';
import 'package:atv/archs/utils/log_util.dart';
import 'package:atv/config/conf/app_conf.dart';
import 'package:atv/config/conf/app_event.dart';
import 'package:atv/config/conf/app_icons.dart';
import 'package:atv/config/conf/route/app_route_settings.dart';
import 'package:atv/config/data/entity/User/user_basic_info.dart';
import 'package:atv/config/data/entity/vehicle/vehicle_list_model.dart';
import 'package:atv/config/net/api_home_page.dart';
import 'package:atv/config/net/api_vehicle.dart';
import 'package:atv/generated/locale_keys.g.dart';
import 'package:atv/widgetLibrary/complex/loading/lw_loading.dart';
import 'package:atv/widgetLibrary/complex/toast/lw_toast.dart';
import 'package:atv/widgetLibrary/utils/size_util.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:easy_localization/easy_localization.dart';

class MinePageViewModel extends BaseViewModel {
  UserBasicInfo? userInfo;

  List<VehicleListModel> vehicleList = [];

  Timer? _timer;

  final List<String> itemNames = [
    LocaleKeys.account.tr(),
    LocaleKeys.help.tr(),
    LocaleKeys.multi_language.tr(),
    LocaleKeys.authentication_center.tr(),
    LocaleKeys.quit.tr()
  ];
  final List<String> itemImageNames = [
    AppIcons.imgMinePageAccount,
    AppIcons.imgMinePageHelp,
    AppIcons.imgMinePageLanguage,
    AppIcons.imgMinePageAC,
    AppIcons.imgMinePageQuit,
  ];
  final List<double> itemImageWidths = [
    16.67.dp,
    20.67.dp,
    21.dp,
    18.dp,
    19.67.dp,
  ];
  final List<double> itemImageHeights = [
    16.67.dp,
    20.67.dp,
    21.dp,
    19.67.dp,
    20.67.dp,
  ];

  String get verifiedString {
    var string = '${LocaleKeys.unverified.tr()}!';
    if (userInfo?.authStatus == 2) {
      string = '${LocaleKeys.authenticated.tr()}!';
    } else if (userInfo?.authStatus == 1) {
      string = '${LocaleKeys.inAuthenticate.tr()}!';
    }

    return string;
  }

  String currentLauguage = '';

  String? get languageString {
    var map = {
      'zh': LocaleKeys.zh.tr(),
      'en': LocaleKeys.en.tr(),
      'fr': LocaleKeys.fr.tr(),
      'es': LocaleKeys.es.tr()
    };
    return map[currentLauguage];
  }

  final List<String> productImageNames = [
    AppIcons.imgMinePageCarIcon,
    AppIcons.imgMinePageChargingIcon,
    AppIcons.imgMinePageMallIcon
  ];

  final List<String> productTitles = [
    LocaleKeys.vehicle.tr(),
    LocaleKeys.charge.tr(),
    LocaleKeys.mall.tr(),
  ];

  final List<String> productDescrips = [
    LocaleKeys.vehicle_describe.tr(),
    LocaleKeys.charge_describe.tr(),
    LocaleKeys.mall_describe.tr(),
  ];

  getAllData() async {
    String? newErrorMsg;
    try {
      //
      // try {
      //   await LWLoading.showLoading2();
      // } catch (e) {}

      //
      var res = await Future.wait(
          [ApiHomePage.getUserBasicInfo(), ApiVehicle.getVehicleList()]);
      // await LWLoading.dismiss(animation: false);

      userInfo = res.first.data as UserBasicInfo?;
      vehicleList = (res[1].data as List<VehicleListModel>?) ?? [];

      pageRefresh();

      return res;
    } on HttpErrorException catch (e) {
      // await LWLoading.dismiss(animation: false);
      newErrorMsg = e.message;
      if (e.code == '-1') {
        newErrorMsg = newErrorMsg ?? LocaleKeys.network_access_error.tr();
      } else {
        newErrorMsg = newErrorMsg ?? LocaleKeys.network_data_unknown_error.tr();
      }
      LWToast.show(newErrorMsg);
    } on Exception catch (e) {
      // await LWLoading.dismiss(animation: false);

      newErrorMsg = e.toString();
      LWToast.show(newErrorMsg);
    } finally {}
  }

  getUserData() {
    loadApiData<UserBasicInfo>(
      ApiHomePage.getUserBasicInfo(),
      handlePageState: false,
      showLoading: false,
      dataSuccess: (data) {
        userInfo = data;
        pageRefresh();
      },
    );
  }

  deleteCar(VehicleListModel carModel) {
    if (StringUtils.isNullOrEmpty(carModel.deviceId) == false) {
      loadApiData(
        ApiVehicle.unbindCar(),
        handlePageState: false,
        showLoading: true,
        voidSuccess: () async {
          //: 这里要主动断开手机蓝牙与设备的连接，会在首页拉取到数据后连接新设备
          await BlueToothUtil.getInstance().onDisconnectPressed();
          EventManager.post(AppEvent.vehicleInfoChange);
        },
      );
    }
  }

  getVehicleList() {
    loadApiData<List<VehicleListModel>>(
      ApiVehicle.getVehicleList(),
      handlePageState: false,
      showLoading: true,
      dataSuccess: (data) {
        vehicleList = data;

        pageRefresh();
      },
    );
  }

  changeCar(VehicleListModel carModel) {
    if (StringUtils.isNullOrEmpty(carModel.deviceId) == false) {
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 1, milliseconds: 500), () {
        loadApiData(
          ApiVehicle.changeSelectVehicle(carModel.deviceId ?? ''),
          handlePageState: false,
          showLoading: true,
          voidSuccess: () async {
            //: 这里要主动断开手机蓝牙与设备的连接，会在首页拉取到数据后连接新设备
            await BlueToothUtil.getInstance().onDisconnectPressed();
            EventManager.post(AppEvent.vehicleInfoChange);
          },
        );
      });
    }
  }

  String get fullName {
    var full = '';
    if (StringUtils.isNotNullOrEmpty(userInfo?.lastName)) {
      full += userInfo?.lastName ?? '';
    }
    if (StringUtils.isNotNullOrEmpty(userInfo?.firstName)) {
      full += userInfo?.firstName ?? '';
    }
    return full;
  }

  void logout() {
    AppConf.logout();
    pagePushAndRemoveUtil(AppRoute.loginMain);
  }

  @override
  void initialize(args) async {
    // TODO: implement initialize
    currentLauguage = await AppConf.getLauguage();
    getAllData();
  }

  @override
  void release() {
    // TODO: implement release
    _timer?.cancel();
  }
}
