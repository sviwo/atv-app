import 'package:atv/archs/base/base_mvvm_page.dart';
import 'package:atv/archs/base/event_manager.dart';
import 'package:atv/archs/utils/bluetooth/blue_tooth_util.dart';
import 'package:atv/archs/utils/log_util.dart';
import 'package:atv/config/conf/app_event.dart';
import 'package:atv/config/conf/app_icons.dart';
import 'package:atv/generated/locale_keys.g.dart';
import 'package:atv/pages/MainPage/viewModel/energy_model_page_view_model.dart';
import 'package:atv/widgetLibrary/utils/size_util.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_switch/flutter_switch.dart';

class EnergyModelPage extends BaseMvvmPage {
  @override
  State<StatefulWidget> createState() => _EnergyModelPageState();
}

class _EnergyModelPageState
    extends BaseMvvmPageState<EnergyModelPage, EnergyModelPageViewModel> {
  @override
  EnergyModelPageViewModel viewModelProvider() => EnergyModelPageViewModel();
  // bool isSupportScrollView() => true;
  @override
  Widget? headerBackgroundWidget() {
    return Image.asset(
      AppIcons.imgCommonBgUpStar,
      fit: BoxFit.cover,
    );
  }

  @override
  String? titleName() => LocaleKeys.kinetic_energy_model.tr();
  @override
  Widget buildBody(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 40.dp,
        ),
        Center(
          child: Image.asset(
            AppIcons.imgMainPageCarIcon,
            width: 203.dp,
            height: 158.dp,
          ),
        ),
        SizedBox(
          height: 70.dp,
        ),
        _buildEcoModel(),
        _buildSportModel(),
        _buildRageModel(),
        _buildRecoveryModel(),
      ],
    );
  }

  tt() {
    // 判断手机蓝牙是否打开
    var isBluetoothOpen = BlueToothUtil.getInstance().blueToothIsOpen();
    //: 判断蓝牙是否已经连接了车辆
    var isConnectBluetooth = BlueToothUtil.getInstance().getBlueConnectStatus();
    if (isBluetoothOpen && isConnectBluetooth) {
      //: 控制ECO模式的开启与关闭 value true：开启  false：关闭
      BlueToothUtil.getInstance().modelSwitch(0, successBlock: () {
        viewModel.changeDriveMode(0);
      });
    } else {
      viewModel.changeDriveMode(0);
    }
  }

  Widget _buildEcoModel() {
    return SizedBox(
      height: 80.dp,
      child: Row(
        children: [
          SizedBox(
            width: 26.dp,
          ),
          SizedBox(
            width: 71.dp,
            child: Center(
              child: Image.asset(
                AppIcons.imgEnergyECOModel,
                width: 43.67.dp,
                height: 15.dp,
              ),
            ),
          ),
          Expanded(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocaleKeys.eco_model.tr(),
                style: TextStyle(fontSize: 14.sp, color: Colors.white),
              ),
              SizedBox(
                height: 7.3.dp,
              ),
              Text(
                LocaleKeys.eco_model_describe.tr(),
                style: TextStyle(fontSize: 9.3.sp, color: Colors.white),
              )
            ],
          )),
          _buildSwitch(
            isOn: viewModel.ecoIsOn,
            enable: true,
            callback: (value) {
              // 判断手机蓝牙是否打开
              var isBluetoothOpen =
                  BlueToothUtil.getInstance().blueToothIsOpen();
              //: 判断蓝牙是否已经连接了车辆
              var isConnectBluetooth =
                  BlueToothUtil.getInstance().getBlueConnectStatus();
              if (isBluetoothOpen && isConnectBluetooth) {
                //: 控制ECO模式的开启与关闭 value true：开启  false：关闭
                BlueToothUtil.getInstance().modelSwitch(0, successBlock: () {
                  // viewModel.homeModel?.drivingMode = 0;
                  viewModel.changeDriveMode(0);
                  // dataRefresh();

                  // EventManager.post(AppEvent.vehicleInfoChange);
                });

                // viewModel.changeDriveMode(0);
              } else {
                viewModel.changeDriveMode(0);
              }
            },
          ),
          SizedBox(
            width: 40.dp,
          )
        ],
      ),
    );
  }

  Widget _buildSportModel() {
    return SizedBox(
      height: 80.dp,
      child: Row(
        children: [
          SizedBox(
            width: 26.dp,
          ),
          SizedBox(
            width: 71.dp,
            child: Center(
              child: Image.asset(
                AppIcons.imgEnergySportModel,
                width: 28.67.dp,
                height: 27.dp,
              ),
            ),
          ),
          Expanded(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocaleKeys.sport_model.tr(),
                style: TextStyle(fontSize: 14.sp, color: Colors.white),
              ),
              SizedBox(
                height: 7.3.dp,
              ),
              Text(
                LocaleKeys.sport_model_describe.tr(),
                style: TextStyle(fontSize: 9.3.sp, color: Colors.white),
              )
            ],
          )),
          _buildSwitch(
            isOn: viewModel.sportIsOn,
            enable: true,
            callback: (value) {
              // 判断手机蓝牙是否打开
              var isBluetoothOpen =
                  BlueToothUtil.getInstance().blueToothIsOpen();
              //: 判断蓝牙是否已经连接了车辆
              var isConnectBluetooth =
                  BlueToothUtil.getInstance().getBlueConnectStatus();
              if (isBluetoothOpen && isConnectBluetooth) {
                //: 控制运动模式的开启与关闭 value true：开启  false：关闭
                BlueToothUtil.getInstance().modelSwitch(1, successBlock: () {
                  // viewModel.homeModel?.drivingMode = 1;
                  viewModel.changeDriveMode(1);
                  // dataRefresh();
                  // EventManager.post(AppEvent.vehicleInfoChange);
                });
                //viewModel.changeDriveMode(1);
              } else {
                viewModel.changeDriveMode(1);
              }
            },
          ),
          SizedBox(
            width: 40.dp,
          )
        ],
      ),
    );
  }

  Widget _buildRageModel() {
    return SizedBox(
      height: 80.dp,
      child: Row(
        children: [
          SizedBox(
            width: 26.dp,
          ),
          SizedBox(
            width: 71.dp,
            child: Center(
              child: Image.asset(
                AppIcons.imgEnergyRageModel,
                width: 27.67.dp,
                height: 24.dp,
              ),
            ),
          ),
          Expanded(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocaleKeys.rage_model.tr(),
                style: TextStyle(fontSize: 14.sp, color: Colors.white),
              ),
              SizedBox(
                height: 7.3.dp,
              ),
              Text(
                LocaleKeys.rage_model_describe.tr(),
                style: TextStyle(fontSize: 9.3.sp, color: Colors.white),
              )
            ],
          )),
          _buildSwitch(
            isOn: viewModel.rageIson,
            enable: true,
            callback: (value) {
              // 判断手机蓝牙是否打开
              var isBluetoothOpen =
                  BlueToothUtil.getInstance().blueToothIsOpen();
              //: 判断蓝牙是否已经连接了车辆
              var isConnectBluetooth =
                  BlueToothUtil.getInstance().getBlueConnectStatus();
              if (isBluetoothOpen && isConnectBluetooth) {
                //: 控制狂暴模式的开启与关闭 value true：开启  false：关闭
                BlueToothUtil.getInstance().modelSwitch(2, successBlock: () {
                  // viewModel.homeModel?.drivingMode = 2;
                  viewModel.changeDriveMode(2);
                  // dataRefresh();
                  // EventManager.post(AppEvent.vehicleInfoChange);
                });
                //viewModel.changeDriveMode(2);
              } else {
                viewModel.changeDriveMode(2);
              }
            },
          ),
          SizedBox(
            width: 40.dp,
          )
        ],
      ),
    );
  }

  Widget _buildRecoveryModel() {
    return SizedBox(
      height: 90.dp,
      child: Row(
        children: [
          SizedBox(
            width: 26.dp,
          ),
          SizedBox(
            width: 71.dp,
            child: Center(
              child: Image.asset(
                AppIcons.imgEnergyRecoveryModel,
                width: 26.67.dp,
                height: 27.67.dp,
              ),
            ),
          ),
          Expanded(
            child: Text(
              LocaleKeys.kinetic_energy_recovery.tr(),
              style: TextStyle(fontSize: 14.sp, color: Colors.white),
            ),
          ),
          Padding(
              padding: EdgeInsets.only(top: 20.dp),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                        trackHeight: 7.dp, // 调整进度条轨道的高度
                        valueIndicatorColor: const Color(0xff36BCB3),
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: 8.dp, // 调整滑块的大小
                        ),
                        tickMarkShape: const RoundSliderTickMarkShape(
                            tickMarkRadius: 0), // 调整刻度标记的大小
                        trackShape:
                            const RoundedRectSliderTrackShape(), // 使用圆角矩形轨道形状

                        // trackMargin: EdgeInsets.all(0), // 设置轨道的内边距为0
                        activeTrackColor: const Color(0xff36BCB3), // 设置活动进度条的颜色
                        inactiveTrackColor: Colors.white, // 设置非活动进度条的颜色
                        thumbColor: Colors.white, // 设置滑块的颜色
                        // valueIndicatorShape: ,
                        valueIndicatorTextStyle:
                            TextStyle(fontSize: 12.sp, color: Colors.white)),
                    child: Slider(
                      value:
                          (viewModel.homeModel?.energyRecovery ?? 0).toDouble(),
                      min: 0,
                      max: 2,
                      divisions: 2,
                      thumbColor: Colors.white,
                      activeColor: const Color(0xff36BCB3),
                      inactiveColor: Colors.white,
                      onChanged: (value) {
                        LogUtil.d('+++++++++++++++onChanged value:$value');
                      },
                      onChangeEnd: (value) {
                        LogUtil.d('+++++++++++++++onChangeEnd value:$value');
                        // 判断手机蓝牙是否打开
                        var isBluetoothOpen =
                            BlueToothUtil.getInstance().blueToothIsOpen();
                        //: 判断蓝牙是否已经连接了车辆
                        var isConnectBluetooth =
                            BlueToothUtil.getInstance().getBlueConnectStatus();
                        if (isBluetoothOpen && isConnectBluetooth) {
                          //: 控制动能回收 value值为0、 1、 2
                          BlueToothUtil.getInstance()
                              .sportRecycle(value.toInt(), successBlock: () {
                            // viewModel.homeModel?.energyRecovery = value.toInt();
                            viewModel.changeEnergyRecovery(value.toInt());
                            // dataRefresh();
                            // EventManager.post(AppEvent.vehicleInfoChange);
                          });
                        } else {
                          viewModel.changeEnergyRecovery(value.toInt());
                        }
                      },
                      label: viewModel.sliderText,
                      // label: '${(_sliderValue * 100).toStringAsFixed(0)}%', //进度条上面的小弹窗
                    ),
                  ),
                  SizedBox(
                      width: 124.dp,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            LocaleKeys.none.tr(),
                            style:
                                TextStyle(fontSize: 12.sp, color: Colors.white),
                          ),
                          Text(
                            LocaleKeys.middle.tr(),
                            style:
                                TextStyle(fontSize: 12.sp, color: Colors.white),
                          ),
                          Text(
                            LocaleKeys.strong.tr(),
                            style:
                                TextStyle(fontSize: 12.sp, color: Colors.white),
                          ),
                        ],
                      ))
                ],
                // ),
              )),
          SizedBox(
            width: 20.dp,
          )
        ],
      ),
    );
  }

  Widget _buildSwitch(
      {bool isOn = false,
      bool enable = false,
      Function(bool value)? callback}) {
    return FlutterSwitch(
      width: 31.dp,
      height: 17.dp,
      toggleSize: 12.dp,
      activeColor: const Color(0xff36BCB3),
      inactiveColor: const Color(0xffE5E5E5),
      padding: 1.dp,
      value: isOn,
      disabled: !enable,
      onToggle: (value) {
        if (callback != null) {
          callback(value);
        }
        pageRefresh(() {});
      },
    );
  }
}
