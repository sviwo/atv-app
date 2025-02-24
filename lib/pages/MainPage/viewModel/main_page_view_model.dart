import 'dart:async';

import 'package:atv/archs/base/base_view_model.dart';
import 'package:atv/archs/base/event_manager.dart';
import 'package:atv/archs/conf/arch_event.dart';
import 'package:atv/archs/utils/bluetooth/blue_tooth_util.dart';
import 'package:atv/archs/utils/log_util.dart';
import 'package:atv/config/conf/app_conf.dart';
import 'package:atv/config/conf/app_event.dart';
import 'package:atv/config/data/entity/mainPage/main_page_model.dart';
import 'package:atv/config/net/api_device_.dart';
import 'package:atv/config/net/api_home_page.dart';
import 'package:atv/config/net/api_public.dart';
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

  /// 喇叭是否打开
  bool bornIsOn = false;

  /// 灯光是否打开
  bool lightIsOn = false;

  @override
  void initialize(args) {
    // TODO: implement initialize
    // LogUtil.d('---------------!!!!!!!!!!!!!!!!!!----------------------');

    loadData();
  }

  @override
  Future<void> loadData({isRefresh = true, bool showLoading = false}) async {
    _isShowLoading = true;
    // LogUtil.d('---------------4444444444444----------------------');

    timer?.cancel();
    await signalRequestData(
      completion: () {
        try {
          if (timer == null || timer?.isActive == false) {
            requestData();
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
    // LogUtil.d('---------------55555555555----------------------');

    // timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      // LogUtil.d('---------------66666666666----------------------');
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

        // LogUtil.d('---------------111111111111----------------------');
        // LogUtil.d(
        //     'blueToothIsOpen: ${BlueToothUtil.getInstance().blueToothIsOpen()},getBlueConnectStatus:${BlueToothUtil.getInstance().getBlueConnectStatus()}');

        if (BlueToothUtil.getInstance().blueToothIsOpen() &&
            !BlueToothUtil.getInstance().getBlueConnectStatus()) {
          // LogUtil.d('--------------222222222222-----------------------');

          //解析数据，初始化蓝牙中数据模型
          BlueToothUtil.getInstance().blueDataVO = BlueDataVO.fromInitial(data);

          // 连接蓝牙
          if (dataModel != null &&
              dataModel!.bluetoothAddress != null &&
              dataModel!.bluetoothSecretKey != null &&
              dataModel!.bluetoothAddress!.isNotEmpty &&
              dataModel!.bluetoothSecretKey!.isNotEmpty) {
            // LogUtil.d('--------------333333333333-----------------------');

            BlueToothUtil.getInstance().speedConnectBlue(
                dataModel!.bluetoothAddress!,
                dataModel!.bluetoothSecretKey!,
                dataModel!.productKey);
          }
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
      showLoading: false,
      voidSuccess: () {},
    );
  }

  /// 车辆绑定前置判断车架号是否合法
  checkDeviceName({String deviceName = '', VoidCallback? callback}) {
    loadApiData(
      ApiDevice.checkVehicleRegisterValid(deviceName),
      handlePageState: false,
      showLoading: true,
      voidSuccess: () {
        if (callback != null) {
          callback();
        }
      },
    );
  }
}
