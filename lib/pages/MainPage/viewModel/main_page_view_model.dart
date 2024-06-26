import 'dart:async';

import 'package:atv/archs/base/base_view_model.dart';
import 'package:atv/archs/base/event_manager.dart';
import 'package:atv/archs/conf/arch_event.dart';
import 'package:atv/archs/utils/log_util.dart';
import 'package:atv/config/conf/app_conf.dart';
import 'package:atv/config/conf/app_event.dart';
import 'package:atv/config/data/entity/mainPage/main_page_model.dart';
import 'package:atv/config/net/api_home_page.dart';
import 'package:atv/config/net/api_vehicle.dart';
import 'package:atv/generated/locale_keys.g.dart';
import 'package:atv/tools/map/lw_map_tool.dart';
import 'package:atv/widgetLibrary/complex/toast/lw_toast.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class MainPageViewModel extends BaseViewModel {
  var clipboardText = '';

  HomePageModel? dataModel;
  Timer? timer;
  bool _isShowLoading = true;

  /// 是否有车
  bool get haveCar => dataModel?.isHavingCar ?? false;

  /// 是否车主
  bool get isOwnerCar => dataModel?.userDeviceType == 0;

  @override
  void initialize(args) {
    // TODO: implement initialize

    loadData();
  }

  @override
  Future<void> loadData({isRefresh = true, bool showLoading = false}) async {
    _isShowLoading = true;

    await signalRequestData(
      completion: () {
        try {
          if (timer == null) {
            // requestData();
          }
        } catch (e) {
          LogUtil.d(e.toString());
        }
      },
    );
  }

  @override
  void release() {
    // LogUtil.d("!!!!!!!!!!!!!!!!!!!timer cancelled");
    timer?.cancel();
  }

  Future<bool> needsUpgrade() async {
    var appVersion = await AppConf.appVersion();
    var a = dataModel?.version.any((model) {
      if (model.versionType == 0) {
        // app更新
        if (appVersion.compareTo(model.versionCode ?? '') < 0) {
          return true;
        }
      } else if (model.versionType == 1) {
        // 固件更新
      }
      return false;
    });
    return false;
  }

  requestData() {
    timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      return signalRequestData();
    });
  }

  signalRequestData({VoidCallback? completion}) async {
    return await loadApiData(
      ApiHomePage.getHomeData(),
      handlePageState: false,
      showLoading: _isShowLoading,
      dataSuccess: (data) async {
        _isShowLoading = false;
        dataModel = data;

        if (completion != null) {
          completion();
        }
        dataRefreshFinished();
        pageRefresh();
      },
      onFailed: (errorMsg) {
        _isShowLoading = false;
        if (completion != null) {
          completion();
        }
        dataRefreshFinished();
        pageRefresh();
      },
    );
  }

  Future<String> reverseGeocodingString() async {
    if (dataModel?.geoLocation?.locationString?.isNotEmpty == true &&
        dataModel?.geoLocation?.locationString != '-') {
      return dataModel?.geoLocation?.locationString ?? '-';
    }
    if (dataModel?.geoLocation != null) {
      dataModel?.geoLocation?.locationString =
          await LWMapTool.reverseGeocoding((dataModel?.geoLocation)!);
    }
    return dataModel?.geoLocation?.locationString ?? '-';
  }

  /// 绑定车辆
  inviteBindVehicle(String carKey, Function(bool isSuccess)? callback) {
    if (carKey.isEmpty) {
      if (callback != null) {
        callback(false);
      }
      return;
    }
    loadApiData(
      ApiVehicle.inviteBindCar(carKey),
      handlePageState: false,
      showLoading: true,
      voidSuccess: () {
        if (callback != null) {
          callback(true);
        }
      },
      onFailed: (errorMsg) {
        if (errorMsg?.isNotEmpty == true) {
          LWToast.show(errorMsg!);
          Future.delayed(const Duration(seconds: 2), () {
            if (callback != null) {
              callback(false);
            }
          });
        } else {
          if (callback != null) {
            callback(false);
          }
        }
      },
    );
  }

  /// 控制车辆
  controlVehicle(int instructions) {
    if ([0, 1].contains(instructions) == false) {
      LWToast.show(LocaleKeys.illegal_operation.tr());
      return;
    }
    loadApiData(
      ApiVehicle.controlVehicle(instructions: instructions),
      handlePageState: false,
      showLoading: true,
      voidSuccess: () {},
    );
  }
}
