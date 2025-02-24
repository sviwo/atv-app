import 'dart:async';

import 'package:atv/archs/base/base_mvvm_page.dart';
import 'package:atv/archs/base/event_manager.dart';
import 'package:atv/archs/conf/arch_event.dart';
import 'package:atv/archs/utils/extension/ext_string.dart';
import 'package:atv/archs/utils/log_util.dart';
import 'package:atv/config/conf/app_conf.dart';
import 'package:atv/config/conf/app_event.dart';
import 'package:atv/config/conf/app_icons.dart';
import 'package:atv/config/conf/route/app_route_settings.dart';
import 'package:atv/generated/locale_keys.g.dart';
import 'package:atv/pages/MainPage/viewModel/main_page_view_model.dart';
import 'package:atv/widgetLibrary/basic/font/lw_font_weight.dart';
import 'package:atv/widgetLibrary/complex/loading/lw_loading.dart';
import 'package:atv/widgetLibrary/complex/titleBar/lw_title_bar.dart';
import 'package:atv/widgetLibrary/complex/toast/lw_toast.dart';
import 'package:atv/widgetLibrary/utils/size_util.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:atv/archs/utils/bluetooth/blue_tooth_util.dart';

class MainPage extends BaseMvvmPage {
  @override
  State<StatefulWidget> createState() => _MainPageState();
}

class _MainPageState extends BaseMvvmPageState<MainPage, MainPageViewModel>
    with WidgetsBindingObserver {
  @override
  Widget? headerBackgroundWidget() {
    // return Image.asset(
    //   AppIcons.imgCommonBgDownStar,
    //   fit: BoxFit.cover,
    // );
    return viewModel.haveCar
        ? Image.asset(
            AppIcons.imgCommonBgNoStar,
            fit: BoxFit.cover,
          )
        : Image.asset(
            AppIcons.imgCommonBgDownStar,
            fit: BoxFit.cover,
          );
  }

  @override
  LWTitleBar? buildTitleBar() {
    return LWTitleBar(
        leadingWidth: 90.dp,
        leadingWidget: InkWell(
          onTap: () async {
            LogUtil.d('点击了扫码');
            // pagePush(AppRoute.remoteControl);
            // return;

            pagePush(AppRoute.scanQrCodePage, callback: (data) {
              if (data != null && data is Map<String, dynamic>) {
                var codeString = data['code'];
                viewModel.checkDeviceName(
                  deviceName: codeString,
                  callback: () {
                    // 车架号后台初验通过，跳转蓝牙列表页面
                    pagePush(AppRoute.bluetoothDevicesPage,
                        params: {'deviceName': codeString});
                  },
                );
              }
            });
          },
          child: Center(
            child: Image.asset(
              AppIcons.imgMainScanCode,
              width: 19.dp,
              height: 19.dp,
            ),
          ),
        ),
        actions: [
          IconButton(
              padding: EdgeInsets.symmetric(horizontal: 20.dp),
              onPressed: () {
                pagePush(AppRoute.mine);
              },
              iconSize: 25.67.dp,
              icon: Image.asset(
                AppIcons.imgMainPageMineIcon,
                width: 25.67.dp,
                height: 22.67.dp,
              ))
        ]);
  }

  @override
  bool isSupportPullRefresh() => true;

  @override
  bool isSupportScrollView() => false;

  @override
  MainPageViewModel viewModelProvider() {
    return MainPageViewModel();
  }

  /// 手机蓝牙是否打开的订阅
  StreamSubscription<bool>? connectSubscription;

  @override
  void initState() {
    // BlueTest.getInstance();
    BlueToothUtil.getInstance();
    viewModel = MainPageViewModel();
    super.initState();
    // AppConf.isMainPage = true;
    EventManager.register(context, ArchEvent.tokenInvalid, (params) {
      AppConf.logout();
      pagePushAndRemoveUntil(AppRoute.loginMain);
    });
    EventManager.register(context, AppEvent.userBaseInfoChange, (params) {
      LogUtil.d("------------userBaseInfoChange");
      viewModel.loadData();
    });
    EventManager.register(context, AppEvent.vehicleInfoChange, (params) {
      LogUtil.d("------------vehicleInfoChange");

      viewModel.loadData();
    });
    EventManager.register(context, AppEvent.vehicleRegistSuccess, (args) {
      LogUtil.d("------------vehicleRegistSuccess");

      viewModel.loadData();
    });
    WidgetsBinding.instance.addObserver(this);

    // connectSubscription =
    //     BlueToothUtil.getInstance().connectDataStream.listen((event) {
    //   LWLoading.dismiss(animation: true);
    // });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    LogUtil.d('=================dispose========');
    EventManager.unregister(context, ArchEvent.tokenInvalid);
    EventManager.unregister(context, AppEvent.userBaseInfoChange);
    EventManager.unregister(context, AppEvent.vehicleInfoChange);
    EventManager.unregister(context, AppEvent.vehicleRegistSuccess);
    connectSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void releaseVM() {
    LogUtil.d('=================releaseVM========');

    super.releaseVM();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用进入前台时
    if (state == AppLifecycleState.resumed) {
      // 执行进入前台时需要处理的逻辑
      print('App has entered foreground!');
      readFromClipboard();
    }
  }

  @override
  void readFromClipboard() async {
    LogUtil.d('----------粘贴板回调');
    var copyIsString = await Clipboard.hasStrings();
    LogUtil.d('----------粘贴板中是否字符串:$copyIsString');
    if (copyIsString) {
      ClipboardData? newClipboardData =
          await Clipboard.getData(Clipboard.kTextPlain);
      var copyText = newClipboardData?.text;
      LogUtil.d('----------粘贴板中的文字为:$copyText');
      if (StringUtils.isNullOrEmpty(copyText) == false) {
        var resultText = copyText ?? '';

        if (resultText.startsWith(RegExp(r'SVIWO_'))) {
          // 车钥匙 绑定
          if (viewModel.clipboardText == resultText) {
            return;
          }
          viewModel.clipboardText = resultText;
          // await Clipboard.setData(ClipboardData(text: ' '));
          viewModel.inviteBindVehicle(resultText, (isSuccess) {
            if (isSuccess) {
              LWToast.show(LocaleKeys.car_key_bind_success.tr());
              // viewModel.clipboardText = '';
              if (viewModel.haveCar == false) {
                // 没有车就要去拉数据 延迟两秒 让toast展示一会儿
                Future.delayed(const Duration(seconds: 2), () {
                  LogUtil.d("------------clipboardText");

                  viewModel.loadData();
                });
              }
            }
          });
        }
      }
    }
  }

  @override
  Widget buildBody(BuildContext context) {
    List<Widget> list = [];
    if (viewModel.haveCar == false) {
      list.addAll(_buildNoCar());
    } else {
      list.addAll([
        SizedBox(
          height: 30.dp,
        ),
        _buildCar(),
        Visibility(
            visible: (viewModel.dataModel?.batteryStatus ?? false) &&
                ((viewModel.dataModel?.electricity ?? 0) > 0),
            child: SizedBox(
              height: 28.dp,
            )),
        Visibility(
            visible: (viewModel.dataModel?.batteryStatus ?? false) &&
                ((viewModel.dataModel?.electricity ?? 0) > 0),
            child: _buildCarStatus()),
        SizedBox(
          height: 30.dp,
        ),
        _buildControlIcons(),
        SizedBox(
          height: 32.dp,
        ),
        _buildItem(
          LocaleKeys.remote_control,
          null,
          Image.asset(
            AppIcons.imgMainPageRemoteControlIcon,
            width: 21.5.dp,
            height: 21.5.dp,
          ),
          callback: () {
            if (viewModel.dataModel?.authStatus == 2) {
              // 判断手机蓝牙是否打开
              var isBluetoothOpen =
                  BlueToothUtil.getInstance().blueToothIsOpen();

              if (!isBluetoothOpen) {
                return;
              }

              //: 判断蓝牙是否已经连接了车辆
              var isConnectBluetooth =
                  // BlueTest.getInstance().getBlueConnectStatus();
                  BlueToothUtil.getInstance().getBlueConnectStatus();
              if (isConnectBluetooth) {
                //跳转到控制器页面
                pagePush(AppRoute.remoteControl);
              } else {
                //: 去连接蓝牙，走快速连接流程 连接不成功 弹出提示
                var bluetoothAddress =
                    viewModel.dataModel?.bluetoothAddress ?? '';
                var bluetoothSecrectKey =
                    viewModel.dataModel?.bluetoothSecretKey ?? '';
                BlueToothUtil.getInstance().speedConnectBlue(bluetoothAddress,
                    bluetoothSecrectKey, viewModel.dataModel?.productKey,
                    successBlock: () => pagePush(AppRoute.remoteControl));
              }
            } else if (viewModel.dataModel?.authStatus == 0 ||
                viewModel.dataModel?.authStatus == 3) {
              LWToast.show(
                LocaleKeys.authentication_not_tips.tr(),
                duration: 3000,
                whenComplete: () {
                  pagePush(AppRoute.authenticationCenter);
                },
              );
            } else if (viewModel.dataModel?.authStatus == 1) {
              LWToast.show(LocaleKeys.inAuthenticate.tr());
            }
          },
        ),
        _buildItem(
          LocaleKeys.kinetic_energy_model,
          null,
          Image.asset(
            AppIcons.imgMainPageLightningIcon,
            width: 15.5.dp,
            height: 24.5.dp,
          ),
          callback: () {
            if (viewModel.dataModel?.authStatus == 2) {
              pagePush(AppRoute.energyModel,
                  params: {'home': viewModel.dataModel?.toJson()});
            } else if (viewModel.dataModel?.authStatus == 0 ||
                viewModel.dataModel?.authStatus == 3) {
              LWToast.show(
                LocaleKeys.authentication_not_tips.tr(),
                duration: 3000,
                whenComplete: () {
                  pagePush(AppRoute.authenticationCenter);
                },
              );
            } else if (viewModel.dataModel?.authStatus == 1) {
              LWToast.show(LocaleKeys.inAuthenticate.tr());
            }
          },
        ),
        _buildLocationItem(),
        _buildItem(
          LocaleKeys.trip_recorder,
          null,
          Image.asset(
            AppIcons.imgMainPageLocationIcon,
            width: 18.dp,
            height: 24.dp,
          ),
          callback: () {
            pagePush(AppRoute.tripRecorder);
          },
        ),
        _buildVehicleConditionInformationItem(),
        Visibility(
            visible: viewModel.isOwnerCar,
            child: _buildItem(
              LocaleKeys.safety,
              null,
              Image.asset(
                AppIcons.imgMainPageSafeIcon,
                width: 20.5.dp,
                height: 20.5.dp,
              ),
              callback: () {
                if (viewModel.dataModel?.authStatus == 2) {
                  pagePush(AppRoute.safetyInfo);
                } else if (viewModel.dataModel?.authStatus == 0 ||
                    viewModel.dataModel?.authStatus == 3) {
                  LWToast.show(
                    LocaleKeys.authentication_not_tips.tr(),
                    duration: 3000,
                    whenComplete: () {
                      pagePush(AppRoute.authenticationCenter);
                    },
                  );
                } else if (viewModel.dataModel?.authStatus == 1) {
                  LWToast.show(LocaleKeys.inAuthenticate.tr());
                }
              },
            )),
        _buildItem(
          LocaleKeys.service,
          null,
          Image.asset(
            AppIcons.imgMainPageServiceIcon,
            width: 19.dp,
            height: 19.dp,
          ),
          callback: () {
            pagePush(AppRoute.serviceInfo,
                params: {'servicePhone': viewModel.dataModel?.servicePhone});
          },
        ),
        _buildItem(
          LocaleKeys.upgrade,
          null,
          Image.asset(
            AppIcons.imgMainPageUpgrade,
            width: 21.dp,
            height: 21.dp,
          ),
          callback: () {
            pagePush(AppRoute.upgradeInfo);
          },
        ),
        SizedBox(
          height: bottomBarHeight,
        )
      ]);
    }

    return ListView(
      // physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: list,
    );
  }

  List<Widget> _buildNoCar() {
    return [
      // _buildNaviIcons(),
      SizedBox(
        height: 60.dp,
      ),
      _buildNoCarIcon(),
      SizedBox(
        height: 105.dp,
      ),
      _buildItem(
        LocaleKeys.place,
        null,
        Image.asset(
          AppIcons.imgMainPageNavigationIcon,
          width: 17.5.dp,
          height: 22.dp,
        ),
        callback: () {},
      ),
      _buildItem(
        LocaleKeys.service,
        null,
        Image.asset(
          AppIcons.imgMainPageServiceIcon,
          width: 19.dp,
          height: 19.dp,
        ),
        callback: () {
          pagePush(AppRoute.serviceInfo);
        },
      ),
      _buildItem(
        LocaleKeys.upgrade,
        null,
        Image.asset(
          AppIcons.imgMainPageUpgrade,
          width: 21.dp,
          height: 21.dp,
        ),
        callback: () {
          pagePush(AppRoute.upgradeInfo);
        },
      ),
      SizedBox(
        height: bottomBarHeight,
      )
    ];
  }

  Widget _buildCar() {
    return SizedBox(
      height: 158.dp,
      child: Center(
        child: Image.asset(
          AppIcons.imgMainPageCarIcon,
          width: 203.dp,
          height: 158.dp,
        ),
      ),
    );
  }

  Widget _buildNoCarIcon() {
    return SizedBox(
      height: 81.dp,
      child: Center(
        child: Image.asset(
          AppIcons.imgMainPageNoCarIcon,
          width: 127.dp,
          height: 81.dp,
        ),
      ),
    );
  }

  Widget _buildCarStatus() {
    var factor = (viewModel.dataModel?.electricity ?? 0) * 0.01;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 40.dp),
      padding: EdgeInsets.all(2.dp),
      height: 14.dp,
      decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1.0.dp),
          borderRadius: BorderRadius.circular(7.dp)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: factor,
        child: Shimmer.fromColors(
            baseColor: const Color(0xff01cde4),
            highlightColor: const Color(0xff0cd1a4),
            period: Duration(milliseconds: (1000 * factor).toInt()),
            child: Container(
              height: 14.dp,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5.dp),
                color: const Color(0xff0CD1A4),
              ),
            )),
      ),
    );
    // return Padding(
    //     padding: EdgeInsets.symmetric(horizontal: 40.dp),
    //     child: Row(
    //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //       children: [
    //         Row(
    //           mainAxisSize: MainAxisSize.min,
    //           children: [
    //             Image.asset(
    //               AppIcons.imgMainPageQuantityOfElectricityIcon,
    //               width: 37.dp,
    //               height: 16.dp,
    //             ),
    //             SizedBox(
    //               width: 8.5.dp,
    //             ),
    //             Text(
    //               '100' + 'km',
    //               style: TextStyle(
    //                 color: Colors.white,
    //                 fontSize: 16.sp,
    //               ),
    //             ),
    //           ],
    //         ),
    //         Row(
    //           mainAxisSize: MainAxisSize.min,
    //           children: [
    //             Text(
    //               '28℃',
    //               style: TextStyle(
    //                 color: Colors.white,
    //                 fontSize: 16.sp,
    //               ),
    //             ),
    //             SizedBox(
    //               width: 10.dp,
    //             ),
    //             Image.asset(
    //               AppIcons.imgMainPageTemperatureIcon,
    //               width: 44.dp,
    //               height: 15.5.dp,
    //             ),
    //           ],
    //         )
    //       ],
    //     ));
  }

  Widget _buildControlIcons() {
    return Padding(
        padding: EdgeInsets.only(left: 11.dp, right: 20.dp),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
                padding: EdgeInsets.symmetric(horizontal: 20.dp),
                onPressed: () {
                  LogUtil.d('点击了锁图标');
                  // BlueToothUtil.getInstance().controllerBlueVoice();
                  // 判断手机蓝牙是否打开
                  var isBluetoothOpen =
                      BlueToothUtil.getInstance().blueToothIsOpen();
                  //: 判断蓝牙是否已经连接了车辆
                  var isConnectBluetooth =
                      BlueToothUtil.getInstance().getBlueConnectStatus();
                  if (isBluetoothOpen && isConnectBluetooth) {
                    //: 控制蓝牙去解锁
                    BlueToothUtil.getInstance().controllerBlueUnLock(1);
                  } else {
                    //: 去连接蓝牙，走快速连接流程
                    var bluetoothAddress =
                        viewModel.dataModel?.bluetoothAddress ?? '';
                    var bluetoothSecrectKey =
                        viewModel.dataModel?.bluetoothSecretKey ?? '';
                    BlueToothUtil.getInstance().speedConnectBlue(
                        bluetoothAddress,
                        bluetoothSecrectKey,
                        viewModel.dataModel?.productKey);
                  }
                },
                iconSize: 41.dp,
                icon: Image.asset(
                  AppIcons.imgMainPageLockIcon,
                  width: 29.dp,
                  height: 29.dp,
                  fit: BoxFit.contain,
                  color: (viewModel.dataModel?.lockedStatus ?? false)
                      ? const Color(0xff36BCB3)
                      : Colors.white,
                )),
            StatefulBuilder(builder: (context, setStateBorn) {
              return IconButton(
                  padding: EdgeInsets.symmetric(horizontal: 20.dp),
                  onPressed: () {
                    if (viewModel.bornIsOn) {
                      return;
                    }

                    LogUtil.d('点击了喇叭图标');
                    // 判断手机蓝牙是否打开
                    var isBluetoothOpen =
                        BlueToothUtil.getInstance().blueToothIsOpen();
                    if (!isBluetoothOpen) {
                      viewModel.controlVehicle(1);
                      return;
                    }

                    //: 判断蓝牙是否已经连接了车辆
                    var isConnectBluetooth =
                        BlueToothUtil.getInstance().getBlueConnectStatus();
                    if (isConnectBluetooth) {
                      //: 控制蓝牙响喇叭
                      BlueToothUtil.getInstance().controllerBlueVoice();
                    } else {
                      //: 去连接蓝牙，走快速连接流程 连接不成功 调用'viewModel.controlVehicle(1);' 走mqtt通道
                      var bluetoothAddress =
                          viewModel.dataModel?.bluetoothAddress ?? '';
                      var bluetoothSecrectKey =
                          viewModel.dataModel?.bluetoothSecretKey ?? '';
                      BlueToothUtil.getInstance().speedConnectBlue(
                          bluetoothAddress,
                          bluetoothSecrectKey,
                          viewModel.dataModel?.productKey,
                          successBlock: () =>
                              BlueToothUtil.getInstance().controllerBlueVoice(),
                          failureBlock: () => viewModel.controlVehicle(1));
                    }
                    setStateBorn(() => viewModel.bornIsOn = true);

                    Future.delayed(const Duration(seconds: 2), () {
                      setStateBorn(() => viewModel.bornIsOn = false);
                    });
                  },
                  iconSize: 41.dp,
                  icon: Image.asset(
                    AppIcons.imgMainPageTrumpetIcon,
                    width: 22.dp,
                    height: 19.dp,
                    fit: BoxFit.contain,
                    color: viewModel.bornIsOn
                        ? const Color(0xff36BCB3)
                        : Colors.white,
                    // color: (viewModel.dataModel?.lockedStatus ?? false) &&
                    //         viewModel.bornIsOn
                    //     ? const Color(0xff36BCB3)
                    //     : Colors.white,
                  ));
            }),
            StatefulBuilder(builder: (context, setStateLight) {
              return IconButton(
                  padding: EdgeInsets.symmetric(horizontal: 20.dp),
                  onPressed: () {
                    if (viewModel.lightIsOn) {
                      return;
                    }
                    LogUtil.d('点击了灯光图标');

                    // 判断手机蓝牙是否打开
                    var isBluetoothOpen =
                        BlueToothUtil.getInstance().blueToothIsOpen();

                    if (!isBluetoothOpen) {
                      viewModel.controlVehicle(0);
                      return;
                    }

                    //: 判断蓝牙是否已经连接了车辆
                    var isConnectBluetooth =
                        BlueToothUtil.getInstance().getBlueConnectStatus();
                    if (isConnectBluetooth) {
                      //: 控制蓝牙响车灯
                      BlueToothUtil.getInstance().controllerBlueLight();
                    } else {
                      //: 去连接蓝牙，走快速连接流程 连接不成功 调用'viewModel.controlVehicle(0);' 走mqtt通道
                      var bluetoothAddress =
                          viewModel.dataModel?.bluetoothAddress ?? '';
                      var bluetoothSecrectKey =
                          viewModel.dataModel?.bluetoothSecretKey ?? '';
                      BlueToothUtil.getInstance().speedConnectBlue(
                          bluetoothAddress,
                          bluetoothSecrectKey,
                          viewModel.dataModel?.productKey,
                          successBlock: () =>
                              BlueToothUtil.getInstance().controllerBlueLight(),
                          failureBlock: () => viewModel.controlVehicle(0));
                    }
                    setStateLight(() => viewModel.lightIsOn = true);

                    Future.delayed(const Duration(seconds: 2), () {
                      setStateLight(() => viewModel.lightIsOn = false);
                    });
                  },
                  iconSize: 41.dp,
                  icon: Image.asset(
                    AppIcons.imgMainPageLamplightIcon,
                    width: 25.dp,
                    height: 15.dp,
                    fit: BoxFit.contain,
                    color: viewModel.lightIsOn
                        ? const Color(0xff36BCB3)
                        : Colors.white,
                    // color: (viewModel.dataModel?.lockedStatus ?? false)
                    //     ? const Color(0xff36BCB3)
                    //     : Colors.white,
                  ));
            })
          ],
        ));
  }

  Widget _buildItem(String? title, Widget? leftWidget, Widget icon,
      {VoidCallback? callback}) {
    LogUtil.d(title);
    // assert(
    // title.isNullOrEmpty() && leftWidget == null, 'title或者leftWidget至少有一个');
    Widget? _lWiget = null;
    if (leftWidget != null) {
      _lWiget = leftWidget;
    } else if (title != null) {
      _lWiget = Text(
        title.tr(),
        style: TextStyle(
          color: Colors.white,
          fontSize: 16.sp,
          // fontWeight: LWFontWeight.bold
        ),
      );
    }
    return InkWell(
        onTap: () {
          LogUtil.d('点击了$title');
          if (callback != null) {
            callback();
          }
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(40.dp, 15.dp, 42.dp, 15.dp),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _lWiget ?? Container()),
              SizedBox(
                width: 28.dp,
                child: Center(
                  child: icon,
                ),
              )
            ],
          ),
        ));
  }

  Widget _buildLocationItem() {
    Widget? _lWiget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.place.tr(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            // fontWeight: LWFontWeight.bold
          ),
        ),
        SizedBox(
          height: 5.5.dp,
        ),
        viewModel.dataModel?.geoLocation != null
            ? FutureBuilder(
                future: viewModel.reverseGeocodingString(),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? "-",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.5.sp,
                      // fontWeight: LWFontWeight.bold
                    ),
                  );
                },
              )
            : Text(
                '-',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9.5.sp,
                  // fontWeight: LWFontWeight.bold
                ),
              ),
      ],
    );
    return InkWell(
        onTap: () {
          if (viewModel.dataModel == null) {
            return;
          }
          if (viewModel.dataModel?.geoLocation == null) {
            return;
          }
          if (viewModel.dataModel?.geoLocation?.locationString
                  .isNullOrEmpty() ==
              true) {
            return;
          }
          pagePush(AppRoute.mapNavi,
              params: viewModel.dataModel?.geoLocation?.toJson());
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(40.dp, 15.dp, 42.dp, 15.dp),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _lWiget),
              SizedBox(
                width: 28.dp,
                child: Center(
                  child: Image.asset(
                    AppIcons.imgMainPageNavigationIcon,
                    width: 17.5.dp,
                    height: 22.dp,
                  ),
                ),
              )
            ],
          ),
        ));
  }

  Widget _buildVehicleConditionInformationItem() {
    Widget? _lWiget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.vehicle_condition_information.tr(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            // fontWeight: LWFontWeight.bold
          ),
        ),
        SizedBox(
          height: 5.5.dp,
        ),
        Text(
          '${LocaleKeys.remaining_mileage.tr()}:${viewModel.dataModel?.remainMile ?? 0}km',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9.5.sp,
            // fontWeight: LWFontWeight.bold
          ),
        ),
      ],
    );
    return InkWell(
        onTap: () {
          if (viewModel.dataModel?.authStatus == 2) {
            pagePush(AppRoute.vehicleConditionInformation, params: {
              'userDeviceType': viewModel.dataModel?.userDeviceType
            });
          } else if (viewModel.dataModel?.authStatus == 0 ||
              viewModel.dataModel?.authStatus == 3) {
            LWToast.show(
              LocaleKeys.authentication_not_tips.tr(),
              duration: 3000,
              whenComplete: () {
                pagePush(AppRoute.vehicleConditionInformation, params: {
                  'userDeviceType': viewModel.dataModel?.userDeviceType
                });
              },
            );
          } else if (viewModel.dataModel?.authStatus == 1) {
            LWToast.show(LocaleKeys.inAuthenticate.tr());
          }
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(40.dp, 15.dp, 42.dp, 15.dp),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _lWiget),
              SizedBox(
                width: 28.dp,
                child: Center(
                  child: Image.asset(
                    AppIcons.imgMainPageAtvInfoIcon,
                    width: 28.dp,
                    height: 14.dp,
                  ),
                ),
              )
            ],
          ),
        ));
  }
}
