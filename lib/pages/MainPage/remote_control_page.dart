import 'package:atv/archs/base/base_mvvm_page.dart';
import 'package:atv/archs/base/event_manager.dart';
import 'package:atv/archs/utils/bluetooth/blue_test.dart';
import 'package:atv/archs/utils/log_util.dart';
import 'package:atv/config/conf/app_event.dart';
import 'package:atv/config/conf/app_icons.dart';
import 'package:atv/generated/locale_keys.g.dart';
import 'package:atv/pages/MainPage/viewModel/remote_control_page_view_model.dart';
import 'package:atv/widgetLibrary/basic/button/lw_button.dart';
import 'package:atv/widgetLibrary/utils/size_util.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:atv/archs/utils/bluetooth/blue_tooth_util.dart';

class RemoteControlPage extends BaseMvvmPage {
  @override
  State<StatefulWidget> createState() => _RemoteControlPageState();
}

class _RemoteControlPageState
    extends BaseMvvmPageState<RemoteControlPage, RemoteControlPageViewModel> {
  @override
  RemoteControlPageViewModel viewModelProvider() =>
      RemoteControlPageViewModel();
  @override
  String? titleName() => LocaleKeys.remote_control.tr();

  var _isForward = false;
  var _isBackward = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    EventManager.register(context, AppEvent.blueToothCommunicationDisabled,
        (params) {
      pagePop();
    });
    //YGTODO: 进入页面监听
    BlueToothUtil.getInstance().initPage();
  }

  tt() {
    Center(child: StatefulBuilder(builder: (context, forwardState) {
      return GestureDetector(
        child: Image.asset(
          AppIcons.imgRemoteControlForwad,
          width: 266.dp,
          height: 120.dp,
          color: _isForward ? Colors.white.withOpacity(0.5) : null,
          colorBlendMode: BlendMode.dstIn,
        ),
        onLongPress: () {
          LogUtil.d('长按了向前');
          if (_isBackward) return;
          //: 蓝牙控制向前
          BlueToothUtil.getInstance().controllerForward();
          forwardState(() {
            _isForward = true;
          });
        },
        onLongPressEnd: (details) {
          LogUtil.d('onLongPressEnd');
          BlueToothUtil.getInstance().controllerCardStop();
          forwardState(() {
            _isForward = false;
          });
        },
      );
    }));
  }

  @override
  void dispose() {
    // TODO: implement dispose
    EventManager.unregister(context, AppEvent.blueToothCommunicationDisabled);
    //YGTODO: 退出页面监听
    BlueToothUtil.getInstance().movePage();
    super.dispose();
  }

  @override
  List<Widget>? buildTitleActions2() {
    // TODO: implement buildTitleActions2
    return [
      StatefulBuilder(
        builder: (BuildContext context, setStateT) {
          return IconButton(
            onPressed: () {
              // setStateT(() {
              //   viewModel.blueToothIsConnected =
              //       !(viewModel.blueToothIsConnected);
              // });
              LogUtil.d('点击了蓝牙图标');
            },
            icon: Image.asset(
              AppIcons.imgRemoteControlBluetooth,
              color: viewModel.blueToothIsConnected
                  ? const Color(0xff36BCB3)
                  : Colors.white,
            ),
            iconSize: 19.dp,
          );
        },
      ),
    ];
  }

  @override
  Widget? headerBackgroundWidget() {
    return Image.asset(
      AppIcons.imgCommonBgUpStar,
      fit: BoxFit.cover,
    );
  }

  @override
  bool isSupportScrollView() => true;

  @override
  Widget buildBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 25.dp,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 45.dp),
          child: Text(
            LocaleKeys.real_time_information.tr(),
            style: TextStyle(
                fontSize: 14.dp,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        ),
        SizedBox(
          height: 25.dp,
        ),
        StreamBuilder<BlueDataVO>(
          stream: BlueToothUtil.getInstance().receiveDataStream,
          initialData: BlueToothUtil.getInstance().blueDataVO,
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            BlueDataVO model = snapshot.data;
            return Padding(
                padding: EdgeInsets.symmetric(horizontal: 60.dp),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem(
                        Image.asset(
                          AppIcons.imgRemoteControlElectricQuantity,
                          width: 18.7.dp,
                          height: 8.dp,
                        ),
                        //: 剩余电量，从设备获取
                        '${model.battery}',
                        '%',
                        LocaleKeys.remaining_battery.tr()),
                    _buildInfoItem(
                        Image.asset(
                          AppIcons.imgRemoteControlspeed,
                          width: 17.7.dp,
                          height: 15.3.dp,
                        ),
                        //: 运行速度，从设备获取
                        '${model.carSpeed}',
                        'km/h',
                        LocaleKeys.speed.tr()),
                  ],
                ));
          },
        ),
        SizedBox(
          height: 19.dp,
        ),
        StreamBuilder<BlueDataVO>(
            stream: BlueToothUtil.getInstance().receiveDataStream,
            initialData: BlueToothUtil.getInstance().blueDataVO,
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              BlueDataVO model = snapshot.data;
              return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 60.dp),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoItem(
                          Image.asset(
                            AppIcons.imgRemoteControlEdurance,
                            width: 9.dp,
                            height: 22.dp,
                          ),
                          //: 剩余里程，从设备获取
                          // BlueToothUtil.getInstance().getEndurance(),
                          '${model.endurance}',
                          'km',
                          LocaleKeys.remaining_mileage.tr()),
                      _buildInfoItem(
                          Image.asset(
                            AppIcons.imgRemoteControlDistance,
                            width: 12.3.dp,
                            height: 21.dp,
                          ),
                          //: 遥控距离，从设备获取
                          // BlueToothUtil.getInstance().getControllerDistance(),
                          model.distance,
                          'm',
                          LocaleKeys.remote_control_distance.tr()),
                    ],
                  ));
            }),
        SizedBox(
          height: 78.dp,
        ),
        Center(child: StatefulBuilder(builder: (context, forwardState) {
          return GestureDetector(
            child: Image.asset(
              AppIcons.imgRemoteControlForwad,
              width: 266.dp,
              height: 120.dp,
              color: _isForward ? Colors.white.withOpacity(0.5) : null,
              colorBlendMode: BlendMode.dstIn,
            ),
            onLongPress: () {
              LogUtil.d('长按了向前');
              if (_isBackward) return;
              //: 蓝牙控制向前
              BlueToothUtil.getInstance().controllerForward();
              forwardState(() {
                _isForward = true;
              });
            },
            onLongPressEnd: (details) {
              LogUtil.d('onLongPressEnd');
              BlueToothUtil.getInstance().controllerCardStop();
              forwardState(() {
                _isForward = false;
              });
            },
          );
        })),
        SizedBox(
          height: 25.dp,
        ),
        Center(child: StatefulBuilder(builder: (context, backwardState) {
          return GestureDetector(
            child: Image.asset(
              AppIcons.imgRemoteControlBackward,
              width: 266.dp,
              height: 120.dp,
              color: _isBackward ? Colors.white.withOpacity(0.5) : null,
              colorBlendMode: BlendMode.dstIn,
            ),
            onLongPress: () {
              LogUtil.d('长按了向后');
              //: 蓝牙控制向后
              BlueToothUtil.getInstance().controllerBackwards();
              if (_isForward) return;
              backwardState(() {
                _isBackward = true;
              });
            },
            onLongPressEnd: (details) {
              LogUtil.d('onLongPressEnd');
              BlueToothUtil.getInstance().controllerCardStop();
              backwardState(() {
                _isBackward = false;
              });
            },
          );
        })),
        SizedBox(
          height: 69.dp,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 70.dp),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatefulBuilder(
                builder: (context, setStateT) {
                  return IconButton(
                    onPressed: () {
                      setStateT(() {
                        viewModel.bornIsOn = !(viewModel.bornIsOn);
                      });
                      LogUtil.d('点击了喇叭图标');
                      //: 蓝牙控制喇叭
                      BlueToothUtil.getInstance().controllerBlueVoice();
                    },
                    icon: Image.asset(
                      AppIcons.imgRemoteControlHorn,
                      color: viewModel.bornIsOn
                          ? const Color(0xff36BCB3)
                          : Colors.white,
                    ),
                    iconSize: 42.dp,
                  );
                },
              ),
              StatefulBuilder(
                builder: (BuildContext context, setStateT) {
                  return IconButton(
                    onPressed: () {
                      setStateT(() {
                        viewModel.lightIsOn = !(viewModel.lightIsOn);
                      });
                      LogUtil.d('点击了灯光图标');
                      //: 蓝牙控制灯光
                      BlueToothUtil.getInstance().controllerBlueLight();
                    },
                    icon: Image.asset(
                      AppIcons.imgRemoteControlLight,
                      color: viewModel.lightIsOn
                          ? const Color(0xff36BCB3)
                          : Colors.white,
                    ),
                    iconSize: 46.dp,
                  );
                },
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildInfoItem(
      Widget icon, String text, String textUnit, String textDecribe) {
    return Container(
      width: 104.dp,
      height: 43.dp,
      decoration: const BoxDecoration(
        image: DecorationImage(
            image: AssetImage(AppIcons.imgRemoteControlInfoBg),
            fit: BoxFit.cover,
            alignment: Alignment.center),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42.dp,
            child: Center(
              child: icon,
            ),
          ),
          SizedBox(
            width: 6.dp,
          ),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 5.dp,
              ),
              Text.rich(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  TextSpan(children: [
                    TextSpan(
                        text: text,
                        style: TextStyle(
                            fontSize: 15.dp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    TextSpan(
                        text: textUnit,
                        style: TextStyle(
                            fontSize: 11.dp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ])),
              Text(
                textDecribe,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5.dp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff9fb4fe),
                ),
              )
            ],
          ))
        ],
      ),
    );
  }
}
