import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:atv/archs/base/event_manager.dart';
import 'package:atv/archs/data/entity/res_data.dart';
import 'package:atv/archs/data/entity/res_empty.dart';
import 'package:atv/archs/data/err/http_error_exception.dart';
import 'package:atv/archs/utils/bluetooth/extra.dart';
import 'package:atv/archs/utils/bluetooth/push_data_service_bean.dart';
import 'package:atv/archs/utils/extension/ext_string.dart';
import 'package:atv/archs/utils/log_util.dart';
import 'package:atv/config/conf/app_event.dart';
import 'package:atv/config/data/entity/mainPage/main_page_model.dart';
import 'package:atv/config/data/entity/vehicle/device_regist_param.dart';
import 'package:atv/config/net/api_device_.dart';
import 'package:atv/generated/locale_keys.g.dart';
import 'package:atv/widgetLibrary/complex/loading/lw_loading.dart';
import 'package:atv/widgetLibrary/complex/toast/lw_toast.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'blue_accept_data_listener.dart';
import 'package:atv/archs/utils/bluetooth/data_exchange_utils.dart';

class BlueToothUtil {
  String TAG = "BlueToothUtil:";

  // 快速连接成功回调
  Function? successBlockT;
  // 快速连接失败回调
  Function? failureBlockT;

  // 无模型数据上传的productkey
  String? productKey;

  // 要推送到服务器到数据模型
  PushDataServiceBean? pushModelBean;

  // 心跳包的序号，1开始递增
  int heartPosition = 1;

  // 记录没有消息的时间间隔 毫秒
  int countHeartTime = 0;

  // 两次发送数据的间隔 毫秒
  static int sendDataHz = 190;

  // 发送数据到服务器到时间间隔 毫秒
  static int sendDataToServiceTime = 3000;

  // 是否第一次发送消息
  bool isFirst = true;

  // 是否快速连接
  bool isSpeedConnect = false;

  // 车速
  double carSpeed = 0;

  // 剩余里程
  double endurance = 0;

  // 电池电量
  int battery = 100;

  // 当前蓝牙name
  String currentBlueName = "";

  // 当前蓝牙
  BluetoothDevice? currentBlue;

  // 蓝牙握手数据类
  DeviceRegistParam? blueConnectInfo;

  // 握手第一步 产品名称
  String? deviceName;

  // 握手成功后 蓝牙返回的simID
  String? simID;
  List<int> simIDList = [];

  // 握手秘钥
  int? keyString;

  // 选择蓝牙的连接状态，默认断开连接
  BluetoothConnectionState _currentBlueConnectionState =
      BluetoothConnectionState.disconnected;

  BluetoothCharacteristic? readChart;
  BluetoothCharacteristic? sendChart;

  // 蓝牙特征
  List<BluetoothService> _services = [];

  // 蓝牙传输过来的数据
  BlueDataVO blueDataVO = BlueDataVO();

  // 蓝牙数据传输流
  StreamController<BlueDataVO> receiveController =
      StreamController<BlueDataVO>.broadcast();
  Stream<BlueDataVO> get receiveDataStream => receiveController.stream;

  // 手机蓝牙开启关闭流
  StreamController<bool> connectController = StreamController<bool>.broadcast();
  Stream<bool> get connectDataStream => connectController.stream;

  // 私有的命名构造函数
  BlueToothUtil._internal();

  BlueAcceptDataListener? blueAcceptDataListener;

  // 初始化
  static BlueToothUtil? _instanceBlueToothUtil;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  // 蓝牙开启状态
  List<BluetoothDevice> _systemDevices = []; // 当前已经连接的蓝牙设备
  List<ScanResult> _scanResults = []; // 扫描到的蓝牙设备
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;

  // 蓝牙连接成功且可以正常发送数据
  bool communicationSuccess = false;

  // 蓝牙连接成功
  bool blueConnectSuccess = false;

  List<List<int>> receiveData = []; // 接收蓝牙发送过来的数据

  List<List<int>> sendData = []; // 暂存发送的数据

  /// 获取示例
  static BlueToothUtil getInstance() {
    if (_instanceBlueToothUtil == null) {
      _instanceBlueToothUtil = BlueToothUtil._internal();
      FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
      FlutterBluePlus.adapterState.listen((state) {
        LogUtil.d("${_instanceBlueToothUtil?.TAG} $state");
        _instanceBlueToothUtil?._adapterState = state;
        if (state == BluetoothAdapterState.off) {
          EventManager.post(AppEvent.blueToothCommunicationDisabled);
          _instanceBlueToothUtil?._scanResultsSubscription = null;
          _instanceBlueToothUtil?._isScanningSubscription = null;

          _instanceBlueToothUtil?._systemDevices = [];
          _instanceBlueToothUtil?._scanResults = [];
          _instanceBlueToothUtil?._isScanning = false;

          _instanceBlueToothUtil?._services = [];
          _instanceBlueToothUtil?.communicationSuccess = false;
          _instanceBlueToothUtil?.blueConnectSuccess = false;
          _instanceBlueToothUtil?.currentBlue = null;
          _instanceBlueToothUtil?.readChart = null;
          _instanceBlueToothUtil?.sendChart = null;
        }
      });

      // 每隔20毫秒钟执行一次myTask
      Timer.periodic(Duration(milliseconds: BlueToothUtil.sendDataHz), (timer) {
        _instanceBlueToothUtil?.myTask();
      });

      // 每隔3000毫秒钟执行一次myTask
      Timer.periodic(
          Duration(milliseconds: BlueToothUtil.sendDataToServiceTime), (timer) {
        _instanceBlueToothUtil?.sendDataToService();
      });
    }
    return _instanceBlueToothUtil!;
  }

  void setDeviceName(String? deviceName) {
    this.deviceName = deviceName;
    getDeviceCertificate();
  }

  void setDeviceRegistParam(DeviceRegistParam? blueConnectInfo) {
    this.blueConnectInfo = blueConnectInfo;
  }

  // 定时发送数据到服务器
  void sendDataToService() {
    if (pushModelBean != null) {
      pushModelBean?.productKey = productKey;
      pushModelBean?.gmtCreate =
          DateTime.now().toUtc().millisecondsSinceEpoch.toString();
      // LogUtil.d("$TAG === ${json.encode(pushModelBean)}");
      // 提交数据到服务器
      // uploadBluetoothDataToServer(pushModelBean!.toJson());
    }
  }

  //定时发送数据到蓝牙
  void myTask() {
    // 这里放置你需要定时执行的代码
    if (sendChart != null) {
      if (sendData.isNotEmpty) {
        sendDataToBlueTooth(sendData[0]);
        sendData.removeAt(0);
        countHeartTime = 0;
      } else {
        if (keyString == null) {
          return;
        }
        // 如果不要app发送心跳包，则吧下面的代码全部注释掉
        countHeartTime += BlueToothUtil.sendDataHz;

        if (countHeartTime >= 5000) {
          // 上一次和这一次5秒没有发送数据则产生一条心跳数据，加入到发送队列里面
          List<int> heartList = sendPackToBluetoothHeart(heartPosition++);
          sendData.add(heartList);
          countHeartTime = 0;
        }
      }
    }
  }

  /// 获取蓝牙是否开启 true 开启， false 关闭
  bool blueToothIsOpen() {
    return _adapterState == BluetoothAdapterState.on;
  }

  /// 获取蓝牙连接状态 能正常通讯
  bool getBlueConnectStatus() {
    return communicationSuccess;
  }

  /// 根据蓝牙mac和key去连接蓝牙
  void speedConnectBlue(String mac, String key, String? productKeyCur,
      {Function? successBlock, Function? failureBlock}) async {
    successBlockT = successBlock;
    failureBlockT = failureBlock;
    productKey = productKeyCur;
    keyString = int.parse(key);
    isFirst = true;
    isSpeedConnect = true;
    // mac = "E0:02:7F:AB:00:29";
    currentBlueName = mac;
    // 判断蓝牙是否开启
    if (!blueToothIsOpen()) {
      // 开启蓝牙
      // openBlueTooth();
      return;
    }
    LWLoading.showLoading2(text: LocaleKeys.connecting.tr());
    // 扫描蓝牙
    startScanBlueTooth();

    Future.delayed(Duration(seconds: 5), () {
      if (!communicationSuccess && failureBlockT != null) {
        failureBlockT!();
      }
      LWLoading.dismiss();
    });
  }

  /// 获取搜索蓝牙列表
  Stream<List<ScanResult>> get bluetoothDeviceList =>
      FlutterBluePlus.scanResults.asBroadcastStream();

  /// 控制蓝牙解锁
  void controllerBlueUnLock(int value, {Function? successBlock}) {
    sendData.add(sendPackToBluetooth46(lockCarStatus: value));
    if (successBlock != null) {
      successBlock();
    }
  }

  // 动能切换模式 1-3 ECO、运动、狂暴     2024年9月7日16:47:23  苟总： 协议改为了1-3  之前是 0-2
  void modelSwitch(int value, {Function? successBlock}) {
    sendData.add(sendPackToBluetooth46(sportStatus: value + 1));
    if (successBlock != null) {
      successBlock();
    }
  }

  // 动能回收
  void sportRecycle(int value, {Function? successBlock}) {
    sendData.add(sendPackToBluetooth46(sportRecycle: value));
    if (successBlock != null) {
      successBlock();
    }
  }

  /// 控制蓝牙响喇叭
  void controllerBlueVoice() {
    sendData.add(sendPackToBluetooth46(voice: 1));
  }

  /// 控制蓝牙响车灯
  void controllerBlueLight() {
    sendData.add(sendPackToBluetooth46(lightStatus: 1));
  }

  /// 剩余电量
  String getBattery() {
    return battery.toString();
  }

  /// 行车速度
  String getSpeed() {
    return carSpeed.toString();
  }

  /// 剩余里程
  String getEndurance() {
    return endurance.toString();
  }

  /// 遥控距离
  String getControllerDistance() {
    return "";
  }

  /// 进入页面发送 苟总:不管其他的，  进入遥控器页面先发：0000000000000082，退出页面的时候发：0000000000000080
  void initPage() {
    sendData.add(sendBluePageInitAndMove(1));
  }

  /// 离开页面发送 苟总: 不管其他的，  进入遥控器页面先发：0000000000000082，退出页面的时候发：0000000000000080
  void movePage() {
    sendData.add(sendBluePageInitAndMove(0));
  }

  /// 向前
  void controllerForward() {
    sendData.add(sendPackToBluetooth46(carStatus: 1));
  }

  /// 停止
  void controllerCardStop() {
    sendData.add(sendPackToBluetooth46(carStatus: 0));
  }

  /// 向后
  void controllerBackwards() {
    sendData.add(sendPackToBluetooth46(carStatus: 2));
  }

  /// 开启蓝牙
  void openBlueTooth() async {
    try {
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      }
    } catch (e) {
      LogUtil.d("$TAG open blueTooth error:$e");
    }
  }

  static Future<bool> checkBlueToothPermission() async {
    /// 判断蓝牙权限
    PermissionStatus permissionStatus = await blueToothPermission();

    if (permissionStatus == PermissionStatus.granted) {
      // 权限已经被授予
      LogUtil.d('蓝牙权限已经被授予');
      return true;
    } else if (permissionStatus == PermissionStatus.denied) {
      // 权限被用户拒绝
      LogUtil.d('蓝牙权限被拒绝');
      // 可以尝试请求权限
      permissionStatus = await requestBlueToothPermission();
      LogUtil.d('+++++++');
      if (permissionStatus == PermissionStatus.granted) {
        LogUtil.d('用户同意了权限请求');
        return true;
      } else if (permissionStatus == PermissionStatus.denied) {
        LogUtil.d('用户仍然拒绝了权限请求');
        return false;
      }
    }
    return false;
  }

  /// 检查蓝牙权限状态
  static Future<PermissionStatus> blueToothPermission() async {
    final PermissionStatus permissionStatus = await Permission.bluetooth.status;
    return permissionStatus;
  }

  /// 请求蓝牙权限
  static Future<PermissionStatus> requestBlueToothPermission() async {
    final PermissionStatus permissionStatus =
        await Permission.bluetooth.request();
    LogUtil.d('requestBlueToothPermission permissionStatus:$permissionStatus');
    return permissionStatus;
  }

  /// 扫描蓝牙
  void startScanBlueTooth() async {
    if (_adapterState != BluetoothAdapterState.on) {
      LogUtil.d("$TAG please open blueTooth");
      return;
    }
    _scanResults = [];
    _scanResultsSubscription ??=
        FlutterBluePlus.scanResults.asBroadcastStream().listen((results) {
      _scanResults = results;
      if (_scanResults.isNotEmpty) {
        for (int i = 0; i < _scanResults.length; i++) {
          if (_scanResults[i].device.platformName.isNotEmpty) {
            //LogUtil.d("$TAG ${_scanResults[i].device.platformName}");
          }

          if (currentBlueName != null &&
              currentBlueName.isNotEmpty &&
              currentBlueName == _scanResults[i].device.platformName) {
            LogUtil.d("$TAG搜索到了指定蓝牙");
            // 停止扫描
            FlutterBluePlus.stopScan();
            // 连接蓝牙
            connectBluetooth(_scanResults[i].device);
            break;
          }
        }
      }
    }, onError: (e) {
      LogUtil.d("$TAG Scan Error:${e.toString()}");
    });

    _isScanningSubscription ??= FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
    });

    if (FlutterBluePlus.isScanningNow) {
      stopScanBlueTooth();
    }

    try {
      _systemDevices = await FlutterBluePlus.systemDevices;
      // LogUtil.d("$TAG scan connect:" + jsonEncode(_systemDevices));
    } catch (e) {
      LogUtil.d("$TAG System Devices Error:${e.toString()}");
    }
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      LogUtil.d("$TAG Start Scan Error:${e.toString()}");
    }
  }

  /// 停止蓝牙扫描
  void stopScanBlueTooth() async {
    if (_adapterState != BluetoothAdapterState.on) {
      LogUtil.d("$TAG please open blueTooth");
      return;
    }
    try {
      FlutterBluePlus.stopScan();
    } catch (e) {
      LogUtil.d("$TAG Stop Scan Error:${e.toString()}");
    }
  }

  /// 刷新扫描
  void onRefresh() {
    if (_adapterState != BluetoothAdapterState.on) {
      LogUtil.d("$TAG please open blueTooth");
      return;
    }
    if (_scanResultsSubscription == null || _isScanningSubscription == null) {
      startScanBlueTooth();
    } else {
      if (_isScanning == false) {
        FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
      }
    }
  }

  /// 修改mtu
  Future onRequestMtuPressed(BluetoothDevice device) async {
    try {
      await device.requestMtu(223, predelay: 0);
      LogUtil.d("$TAG Request Mtu: Success");
    } catch (e) {
      LogUtil.d("$TAG Change Mtu Error:${e.toString()}");
    }
  }

  /// 连接蓝牙
  Future connectBluetooth(BluetoothDevice mdevice) async {
    isFirst = true;
    LogUtil.d("$TAG blueName:${mdevice.platformName}");

    if (getBlueToothConnectState() == -1) {
      mdevice.connectAndUpdateStream().catchError((e) {
        LogUtil.d("$TAG Connect Error:${e.toString()}");
      });
      mdevice.connectionState.listen((state) async {
        _currentBlueConnectionState = state;
        if (state == BluetoothConnectionState.connected) {
          blueConnectSuccess = true;
          connectController.sink.add(true);
          currentBlue = mdevice;
          currentBlueName = mdevice.platformName;
          LogUtil.d("$TAG devicename:${mdevice.platformName}");

          _services = []; // must rediscover services

          try {
            _services = await mdevice.discoverServices();
            for (int i = 0; i < _services.length; i++) {
              List<BluetoothCharacteristic> characteristics =
                  _services[i].characteristics;

              for (int j = 0; j < characteristics.length; j++) {
                if (characteristics[j].properties.read &&
                    (_services[i].uuid.str.toLowerCase() == "ffe0")) {
                  readChart = characteristics[j];

                  await readChart?.setNotifyValue(true);

                  // 读
                  var subscription = readChart?.onValueReceived.listen((value) {
                    decodeBlueToothData(value);
                  });

                  if (subscription != null) {
                    currentBlue?.cancelWhenDisconnected(subscription);
                  }

                  sendChart = characteristics[j];

                  List<int> list = getStepOneBluetoothCarNumber1();
                  sendData.add(list);
                  break;
                }
              }
            }
          } catch (e) {
            LogUtil.d("$TAG Discover Services: Success:${e.toString()}");
          }
        } else {
          EventManager.post(AppEvent.blueToothCommunicationDisabled);
          communicationSuccess = false;
          blueConnectSuccess = false;
          connectController.sink.add(false);
        }
      });
    }
  }

  /// 取消连接
  Future onCancelPressed() async {
    if (currentBlue != null && blueConnectSuccess) {
      try {
        await currentBlue?.disconnectAndUpdateStream(queue: false);
        LogUtil.d("$TAG Cancel: Success");
      } catch (e) {
        LogUtil.d("$TAG Cancel Error:${e.toString()}");
      }
    }
  }

  /// 断开链接
  Future onDisconnectPressed() async {
    if (currentBlue != null &&
        _currentBlueConnectionState == BluetoothConnectionState.connected) {
      try {
        await currentBlue?.disconnectAndUpdateStream();
        communicationSuccess = false;
        return;
        LogUtil.d("$TAG Disconnect: Success");
      } catch (e) {
        LogUtil.d("$TAG Disconnect Error:${e.toString()}");
      }
    }
  }

  /// 发送数据
  Future sendDataToBlueTooth(List<int> sendData,
      {int i = -1, int j = -1}) async {
    if (sendChart == null) {
      LogUtil.d("$TAG sendChart is null");
    } else {
      LogUtil.d("$TAG 发送数据到蓝牙：${DataExchangeUtils.bytesToHex(sendData)}");
      try {
        await sendChart?.write(sendData);
      } catch (e) {
        LogUtil.d("$TAG == ${e}");
        // TODO  发送有时候有异常
      }
    }
  }

  /// 监听蓝牙特征
  void listenerBlueToothReadChart() async {
    if (readChart == null) {
      LogUtil.d("$TAG readChart is null");
    } else {
      await readChart?.setNotifyValue(true);
      readChart?.lastValueStream.listen((event) {
        receiveData.add(event);
        decodeBlueToothData(event);
      });
    }
  }

  /// 蓝牙连接状态  0连接中，1已连接，-1未连接
  int getBlueToothConnectState() {
    if (blueConnectSuccess) {
      return 0;
    } else if (_currentBlueConnectionState ==
        BluetoothConnectionState.connected) {
      return 1;
    } else {
      return -1;
    }
  }

  void dispose() {
    connectController.close();
    // currentBlue?.disconnect();
    // _connectionStateSubscription?.cancel();
    // _mtuSubscription?.cancel();
    // _isConnectingSubscription?.cancel();
    // _isDisconnectingSubscription?.cancel();
    //
    // _scanResultsSubscription?.cancel();
    // _isScanningSubscription?.cancel();
    //
    // _adapterStateStateSubscription?.cancel();
  }

  List<int> currentDat = [];

  /// 解析蓝牙发送的数据
  void decodeBlueToothData(List<int> dataListTemp) {
    // 处理粘包
    List<int> dataList = [];
    // LogUtil.d("$TAG 接收蓝牙数据rrrrr:${DataExchangeUtils.bytesToHex(dataListTemp)}");
    if (dataListTemp.isNotEmpty) {
      if (dataListTemp[0] == 0xa5) {
        if (dataListTemp.length == 17) {
          currentDat.clear();
          dataList = dataListTemp;
        } else if (dataListTemp.length > 17) {
          currentDat = dataListTemp.sublist(17);
          dataList = dataListTemp.sublist(0, 17);
        } else if (dataListTemp.length < 17) {
          currentDat.addAll(dataListTemp);
          return;
        }
      } else if (dataListTemp[0] == 0xaa) {
        if (dataListTemp.length == 16) {
          currentDat.clear();
          dataList = dataListTemp;
        } else if (dataListTemp.length > 16) {
          currentDat = dataListTemp.sublist(16);
          dataList = dataListTemp.sublist(0, 16);
        } else if (dataListTemp.length < 16) {
          currentDat.addAll(dataListTemp);
          return;
        }
      } else {
        if (currentDat[0] == 0xa5) {
          if (dataListTemp.length + currentDat.length >= 17) {
            int lengh = 17 - currentDat.length;
            currentDat.addAll(dataListTemp.sublist(0, lengh));
            dataList = currentDat;
            currentDat = dataListTemp.sublist(lengh);
          } else {
            currentDat.addAll(dataListTemp);
            return;
          }
        } else if (currentDat[0] == 0xaa) {
          if (dataListTemp.length + currentDat.length >= 16) {
            int lengh = 16 - currentDat.length;
            currentDat.addAll(dataListTemp.sublist(0, lengh));
            dataList = currentDat;
            currentDat = dataListTemp.sublist(lengh);
          } else {
            currentDat.addAll(dataListTemp);
            return;
          }
        } else {
          if (dataListTemp.length + currentDat.length >= 17) {
            int lengh = 17 - currentDat.length;
            currentDat.addAll(dataListTemp.sublist(0, lengh));
            dataList = currentDat;
            currentDat = dataListTemp.sublist(lengh);
          } else {
            currentDat.addAll(dataListTemp);
            return;
          }
        }
      }
    } else {
      return;
    }

    if ((dataList[1] & 0xff) == 0x92) {
      // LogUtil.d("$TAG 接收蓝牙数据心跳:${DataExchangeUtils.bytesToHex(dataList)}");
    } else {
      if ((dataList[1] & 0xff) < 0x22 && (dataList[1] & 0xff) > 0x26) {
        LogUtil.d("$TAG 接收蓝牙数据:${DataExchangeUtils.bytesToHex(dataList)}");
      } else {
        communicationSuccess = true;
        if (successBlockT != null) {
          successBlockT!();
        }
        LWLoading.dismiss();
      }
    }
    if (dataList.length != 17) {
      return;
    }
    if ((dataList[0] & 0xff) != 0xa5) {
      return;
    }
    if ((dataList[1] & 0xff) != 0x10) {
      return;
    }

    int count = 0;
    for (int i = 0; i < dataList.length; i++) {
      if (i == 16) {
        break;
      }
      count += dataList[i];
    }

    if ((count & 0xff) != (dataList[16] & 0xff)) {
      return;
    }

    if ((dataList[2] & 0xff) == 1) {
      decodeBlueToothData1(dataList);
    } else if ((dataList[2] & 0xff) == 4) {
      decodeBlueToothData4(dataList);
    } else if ((dataList[2] & 0xff) == 9) {
      decodeBlueToothData9(dataList);
    } else if ((dataList[2] & 0xff) == 14) {
      decodeBlueToothData14(dataList);
    } else if ((dataList[2] & 0xff) == 23) {
      decodeBlueToothData23(dataList);
    } else if ((dataList[2] & 0xff) == 32) {
      decodeBlueToothData32(dataList);
    } else if ((dataList[2] & 0xff) == 33) {
      decodeBlueToothData33(dataList);
    } else if ((dataList[2] & 0xff) == 34) {
      decodeBlueToothData34(dataList);
    } else if ((dataList[2] & 0xff) == 35) {
      decodeBlueToothData35(dataList);
    } else if ((dataList[2] & 0xff) == 36) {
      decodeBlueToothData36(dataList);
    } else if ((dataList[2] & 0xff) == 37) {
      decodeBlueToothData37(dataList);
    } else if ((dataList[2] & 0xff) == 38) {
      decodeBlueToothData38(dataList);
    } else if ((dataList[2] & 0xff) == 39) {
      decodeBlueToothData39(dataList);
    } else if ((dataList[2] & 0xff) == 44) {
      decodeBlueToothData44(dataList);
    } else if ((dataList[2] & 0xff) >= 47 && (dataList[2] & 0xff) <= 49) {
      decodeBlueToothData47_49(dataList);
    } else if ((dataList[2] & 0xff) == 43) {
      if (isFirst) {
        isFirst = false;
        // List<int> list = getStepOneBluetoothCarNumber1();
        // sendData.add(list);

        if (isSpeedConnect) {
          List<int> list = sendPackToBluetooth44(keyString!);
          sendData.add(list);
          pushModelBean ??= PushDataServiceBean();
          pushModelBean?.deviceName = currentBlueName;
          pushModelBean?.productKey = blueConnectInfo?.productKey;
        } else {
          // 发送车架号
          if (deviceName != null && !deviceName!.isNullOrEmpty()) {
            List<List<int>> mList = getPackToBluetoothCarNumber2_4(deviceName!);
            for (int i = 0; i < mList.length; i++) {
              sendData.add(mList[i]);
            }
          }
        }
      }
    } else {
      // LogUtil.d("$TAG 接收蓝牙数据:${DataExchangeUtils.bytesToHex(dataList)}");
      // LogUtil.d("$TAG blueTooth messageType error");
    }
  }

  tt() {
    // 发送车架号
    if (deviceName != null && !deviceName!.isNullOrEmpty()) {
      List<List<int>> mList = getPackToBluetoothCarNumber2_4(deviceName!);
      for (int i = 0; i < mList.length; i++) {
        sendData.add(mList[i]);
      }
    }
  }

  /// app 发送个i蓝牙的心跳包
  List<int> sendPackToBluetoothHeart(int index) {
    List<int> sendPack = List.filled(17, 0);
    int count = 0;
    int position = 0;
    sendPack[position++] = 0xa5;
    sendPack[position++] = 0x03;
    sendPack[position++] = 0x50;
    sendPack[position++] = 8;
    var second = (DateTime.now().toUtc().millisecondsSinceEpoch) ~/ 1000;
    sendPack[position++] = (second >> 24) & 0xff;
    sendPack[position++] = (second >> 16) & 0xff;
    sendPack[position++] = (second >> 8) & 0xff;
    sendPack[position++] = second & 0xff;

    sendPack[position++] = (index >> 24) & 0xff;
    sendPack[position++] = (index >> 16) & 0xff;
    sendPack[position++] = (index >> 8) & 0xff;
    sendPack[position++] = index & 0xff;

    for (int i = 0; i < 16; i++) {
      count += sendPack[i];
    }
    sendPack[16] = count & 0xff;

    return sendPack;
  }

  /// app 蓝牙连接成功后，app发送握手
  List<int> sendPackToBluetooth1() {
    List<int> sendPack = List.filled(17, 0);
    int count = 0;
    int position = 0;
    sendPack[position++] = 0xa5;
    sendPack[position++] = 0x03;
    sendPack[position++] = 1;
    sendPack[position++] = 8;
    var second = (DateTime.now().toUtc().millisecondsSinceEpoch) ~/ 1000;
    sendPack[12] = (second >> 24) & 0xff;
    sendPack[13] = (second >> 16) & 0xff;
    sendPack[14] = (second >> 8) & 0xff;
    sendPack[15] = second & 0xff;

    for (int i = 0; i < 16; i++) {
      count += sendPack[i];
    }
    sendPack[16] = count & 0xff;

    return sendPack;
  }

  /// 解析蓝牙发送过来的数据  消息类型1
  void decodeBlueToothData1(List<int> dataList) {
    int timeMillisecond = ((dataList[8] << 24) & 0xffffffff) |
        ((dataList[9] << 16) & 0xffffff) |
        ((dataList[10] << 8) & 0xffff) |
        (dataList[11] & 0xff);

    // if(isFirst){
    //   isFirst = false;
    //   List<int> list = getStepOneBluetoothCarNumber1();
    //   sendData.add(list);
    //
    //   if(isSpeedConnect){
    //     List<int> list = sendPackToBluetooth44(keyString!);
    //     sendData.add(list);
    //   }else{
    //     // 发送车架号
    //     if (deviceName != null && !deviceName!.isNullOrEmpty()) {
    //       List<List<int>> mList =
    //       getPackToBluetoothCarNumber2_4(deviceName!);
    //       for (int i = 0; i < mList.length; i++) {
    //         sendData.add(mList[i]);
    //       }
    //     }
    //   }
    // }

    // blueAcceptDataListener?.acceptBlueToothData(timeMillisecond, 1);
  }

  /// 解析蓝牙发送过来的数据  消息类型4  产品名称 应答
  void decodeBlueToothData4(List<int> dataList) {
    if ((dataList[14] & 0xff) == 0xa3) {
      LogUtil.d("$TAG 产品名称:接收成功！");
      if (blueConnectInfo != null &&
          blueConnectInfo!.productKey != null &&
          !blueConnectInfo!.productKey.isNullOrEmpty()) {
        productKey = blueConnectInfo!.productKey;
        List<List<int>> mList =
            getPackToBluetoothProductKey5_9(blueConnectInfo!.productKey!);
        for (int i = 0; i < mList.length; i++) {
          sendData.add(mList[i]);
        }
      }
    } else {
      LogUtil.d("$TAG 产品名称:接收失败！");
      // 发送车架号
      if (deviceName != null && !deviceName!.isNullOrEmpty()) {
        List<List<int>> mList = getPackToBluetoothCarNumber2_4(deviceName!);
        for (int i = 0; i < mList.length; i++) {
          sendData.add(mList[i]);
        }
      }
    }
  }

  /// 解析蓝牙发送过来的数据  消息类型9  ProductKey
  void decodeBlueToothData9(List<int> dataList) {
    if ((dataList[14] & 0xff) == 0xa3) {
      LogUtil.d("$TAG ProductKey接收成功！");
      // blueAcceptDataListener?.acceptBlueToothData(true, 9);
      if (blueConnectInfo != null &&
          blueConnectInfo!.deviceName != null &&
          !blueConnectInfo!.deviceName.isNullOrEmpty()) {
        List<List<int>> mList =
            getPackToBluetoothProductKey10_14(blueConnectInfo!.deviceName!);
        for (int i = 0; i < mList.length; i++) {
          sendData.add(mList[i]);
        }
      }
    } else {
      // blueAcceptDataListener?.acceptBlueToothData(false, 9);
      LogUtil.d("$TAG ProductKey接收失败！");
      if (blueConnectInfo != null &&
          blueConnectInfo!.productKey != null &&
          !blueConnectInfo!.productKey.isNullOrEmpty()) {
        List<List<int>> mList =
            getPackToBluetoothProductKey5_9(blueConnectInfo!.productKey!);
        for (int i = 0; i < mList.length; i++) {
          sendData.add(mList[i]);
        }
      }
    }
  }

  /// 解析蓝牙发送过来的数据  消息类型14  DeviceName
  void decodeBlueToothData14(List<int> dataList) {
    if ((dataList[14] & 0xff) == 0xa3) {
      LogUtil.d("$TAG DeviceName接收成功！");
      if (blueConnectInfo != null &&
          blueConnectInfo!.deviceSecret != null &&
          !blueConnectInfo!.deviceSecret.isNullOrEmpty()) {
        List<List<int>> mList =
            getPackToBluetoothDeviceSecret15_23(blueConnectInfo!.deviceSecret!);
        for (int i = 0; i < mList.length; i++) {
          sendData.add(mList[i]);
        }
      }
      // blueAcceptDataListener?.acceptBlueToothData(true, 14);
    } else {
      LogUtil.d("$TAG DeviceName接收失败！");
      // blueAcceptDataListener?.acceptBlueToothData(false, 14);
      if (blueConnectInfo != null &&
          blueConnectInfo!.deviceName != null &&
          !blueConnectInfo!.deviceName.isNullOrEmpty()) {
        List<List<int>> mList =
            getPackToBluetoothProductKey10_14(blueConnectInfo!.deviceName!);
        for (int i = 0; i < mList.length; i++) {
          sendData.add(mList[i]);
        }
      }
    }
  }

  /// 解析蓝牙发送过来的数据  消息类型23 DeviceSecret
  void decodeBlueToothData23(List<int> dataList) {
    if ((dataList[14] & 0xff) == 0xa3) {
      LogUtil.d("$TAG DeviceSecret接收成功！");
      if (blueConnectInfo != null &&
          blueConnectInfo!.mqttHostUrl != null &&
          !blueConnectInfo!.mqttHostUrl.isNullOrEmpty()) {
        List<List<int>> mList =
            getPackToBluetoothURL24_32(blueConnectInfo!.mqttHostUrl!);
        for (int i = 0; i < mList.length; i++) {
          sendData.add(mList[i]);
        }
      }
      // blueAcceptDataListener?.acceptBlueToothData(true, 23);
    } else {
      LogUtil.d("$TAG DeviceSecret接收失败！");
      // blueAcceptDataListener?.acceptBlueToothData(false, 23);
      if (blueConnectInfo != null &&
          blueConnectInfo!.deviceSecret != null &&
          !blueConnectInfo!.deviceSecret.isNullOrEmpty()) {
        List<List<int>> mList =
            getPackToBluetoothDeviceSecret15_23(blueConnectInfo!.deviceSecret!);
        for (int i = 0; i < mList.length; i++) {
          sendData.add(mList[i]);
        }
      }
    }
  }

  /// 解析蓝牙发送过来的数据  消息类型32 URL
  void decodeBlueToothData32(List<int> dataList) {
    if ((dataList[14] & 0xff) == 0xa3) {
      LogUtil.d("$TAG URL接收成功！");
      List<int> activity = getPackToBluetoothActivities33();
      sendData.add(activity);
    } else {
      LogUtil.d("$TAG URL接收失败！");
      if (blueConnectInfo != null &&
          blueConnectInfo!.mqttHostUrl != null &&
          !blueConnectInfo!.mqttHostUrl.isNullOrEmpty()) {
        List<List<int>> mList =
            getPackToBluetoothURL24_32(blueConnectInfo!.mqttHostUrl!);
        for (int i = 0; i < mList.length; i++) {
          sendData.add(mList[i]);
        }
      }
    }
  }

  /// 解析蓝牙发送过来的数据  消息类型33 握手是否成功
  void decodeBlueToothData33(List<int> dataList) {
    // bit0表示ProductKey，bit1表示DeviceName，bit2表示DeviceSecret，bit3表示URL
    bool checkResult = true;
    if ((dataList[9] & 0x01) == 1) {
    } else {
      checkResult = false;
      LogUtil.d("$TAG ProductKey check error");
    }
    if (((dataList[9] >> 1) & 0x01) == 1) {
    } else {
      checkResult = false;
      LogUtil.d("$TAG DeviceName check error");
    }
    if (((dataList[9] >> 2) & 0x01) == 1) {
    } else {
      checkResult = false;
      LogUtil.d("$TAG DeviceSecret check error");
    }
    if (((dataList[9] >> 3) & 0x01) == 1) {
    } else {
      checkResult = false;
      LogUtil.d("$TAG URL check error");
    }

    List<int> key = dataList.sublist(12, 16);
    keyString = DataExchangeUtils.fourByteListToInt(key);
    LogUtil.d("$TAG 激活成功！,key33=$keyString");
  }

  /// 解析蓝牙发送过来的数据  消息类型34
  void decodeBlueToothData34(List<int> dataList) {
    // 维度
    double lat = DataExchangeUtils.bytesToFloat(dataList.sublist(8, 12));
    // 经度
    double lng = DataExchangeUtils.bytesToFloat(dataList.sublist(12, 16));
    pushModelBean?.items.GeoLocation.time =
        DataExchangeUtils.fourBytesToInt(dataList.sublist(4, 8)).toString();
    // {'latitude':31.583733,'longitude':120.433029}
    pushModelBean?.items.GeoLocation.value =
        "{'latitude':$lat,'longitude':$lng}";
    // LogUtil.d("$TAG 解析 lng:$lng lat:$lat");
  }

  /// 解析蓝牙发送过来的数据  消息类型35
  void decodeBlueToothData35(List<int> dataList) {
    // 维度
    double speed = DataExchangeUtils.bytesToFloat(dataList.sublist(8, 12));
    // 动能模式切换
    int sportSwitch = dataList[12] & 0xff;
    // 动能回收
    int sportRecycle = dataList[13] & 0xff;
    // LogUtil.d(
    //     "$TAG 解析 speed:$speed sportSwitch:$sportSwitch sportRecycle:$sportRecycle");
  }

  /// 解析蓝牙发送过来的数据  消息类型36
  void decodeBlueToothData36(List<int> dataList) {
    // 锁车状态
    int lockCarStatus = dataList[8] & 0x01;
    // 设防
    int setLock = (dataList[8] >> 1) & 0x01;
    // 轮动警告
    int wheelDrive = (dataList[8] >> 3) & 0x01;
    //震动警告
    int shake = (dataList[8] >> 4) & 0x01;
    // 喇叭
    int voice = dataList[10] & 0x01;
    // 报警
    int alarm = (dataList[10] >> 1) & 0x01;
    // 持续报警
    int alarmContinue = (dataList[10] >> 1) & 0x01;
    // 设备异常告警
    int deviceDefaultAlarm = dataList[12] & 0x01;
    // 车机温度过高
    int carTemperatureHigh = (dataList[12] >> 3) & 0x01;
    // 充电枪连接
    int chargeConnect = (dataList[12] >> 4) & 0x01;
    // 低电量
    int lowPower = (dataList[12] >> 5) & 0x01;
    // 灯状态
    int lightStatus = dataList[14] & 0xff;
    // 灯双闪
    int doubleLightFlash = (dataList[15] >> 1) & 0x01;
    // 左灯闪
    int leftLightFlash = (dataList[15] >> 2) & 0x01;
    // 右灯闪
    int rightLightFlash = (dataList[15] >> 3) & 0x01;

    blueDataVO.chargeConnect = chargeConnect;
    receiveController.add(blueDataVO);
  }

  /// 解析蓝牙发送过来的数据  消息类型37
  void decodeBlueToothData37(List<int> dataList) {
    // 电机转速
    int motorSpeed =
        DataExchangeUtils.fourByteListToInt(dataList.sublist(8, 12));
    // 车速
    carSpeed = DataExchangeUtils.bytesToFloat(dataList.sublist(12, 16));

    blueDataVO.carSpeed = carSpeed;
    receiveController.add(blueDataVO);

    pushModelBean?.items.RotateSpeed.time =
        DataExchangeUtils.fourBytesToInt(dataList.sublist(4, 8)).toString();
    pushModelBean?.items.RotateSpeed.value = motorSpeed.toString();

    pushModelBean?.items.VehSpeed.time =
        DataExchangeUtils.fourBytesToInt(dataList.sublist(4, 8)).toString();
    pushModelBean?.items.VehSpeed.value = carSpeed.toString();
  }

  /// 解析蓝牙发送过来的数据  消息类型38
  void decodeBlueToothData38(List<int> dataList) {
    // 剩余里程float
    endurance = DataExchangeUtils.bytesToFloat(dataList.sublist(8, 12));
    // 电池电量%
    battery = dataList[12] & 0xff;
    //bit0：电池状态 13
    int batteryStatus = dataList[13] & 0x01;
    // bit1：充电状态 13
    int chargingStatus = (dataList[13] >> 1) & 0x01;
    // bit2：亏电状态 13
    int lackOfPowerStatus = (dataList[13] >> 2) & 0x01;
    // bit3：就绪状态 13
    int readyStatus = (dataList[13] >> 3) & 0x01;
    // bit4：放电接触器状态 13
    int dischargeContactorStatus = (dataList[13] >> 4) & 0x01;
    // bit5：充电接触器状态 13
    int chargingContactorStatus = (dataList[13] >> 5) & 0x01;
    // 电池故障等级 14
    // 0x00:无故障
    // 0x01:1 级故障(严重故障，立即停车)
    // 0x02:2 级故障（普通故障，限速 50%运行）
    // 0x03:3 级故障（报警故障，报警）
    int batteryDefaultLeve = dataList[14] & 0xff;
    // BMS故障码
    int bmsCode = dataList[15] & 0xff;

    blueDataVO.endurance = endurance;
    blueDataVO.battery = battery;
    receiveController.add(blueDataVO);

    pushModelBean?.items.RemainMile.time =
        DataExchangeUtils.fourBytesToInt(dataList.sublist(4, 8)).toString();
    pushModelBean?.items.RemainMile.value = endurance.toString();

    pushModelBean?.items.Electricity.time =
        DataExchangeUtils.fourBytesToInt(dataList.sublist(4, 8)).toString();
    pushModelBean?.items.Electricity.value = battery.toString();
  }

  /// 解析蓝牙发送过来的数据  消息类型39
  void decodeBlueToothData39(List<int> dataList) {
    // 遥感距离1
    int rangeOne = DataExchangeUtils.twoByteToInt(dataList[8], dataList[9]);
    // 遥感距离2
    int rangeTwo = DataExchangeUtils.twoByteToInt(dataList[10], dataList[11]);
    // 遥感距离3
    int rangeThree = DataExchangeUtils.twoByteToInt(dataList[12], dataList[13]);
    // 遥感距离4
    int rangeFour = DataExchangeUtils.twoByteToInt(dataList[14], dataList[15]);

    LogUtil.d(
        "$TAG 解析 rangeOne:$rangeOne rangeTwo:$rangeTwo rangeThree:$rangeThree rangeFour:$rangeFour");
  }

  /// 解析蓝牙发送过来的数据  消息类型44  请求车架号
  void decodeBlueToothData44(List<int> dataList) {
    List<int> key = dataList.sublist(12, 16);
    keyString = DataExchangeUtils.fourBytesToInt(key);
    LogUtil.d("$TAG 激活成功！,key44=$keyString");
  }

  /// 解析simID
  void decodeBlueToothData47_49(List<int> dataList) {
    if (dataList[2] == 47) {
      simIDList = dataList.sublist(8, 16);
    } else if (dataList[2] == 48) {
      simIDList.addAll(dataList.sublist(8, 16));
    } else if (dataList[2] == 49) {
      communicationSuccess = true;
      pushModelBean ??= PushDataServiceBean();
      pushModelBean?.deviceName = currentBlueName;
      pushModelBean?.productKey = blueConnectInfo?.productKey;
      simIDList.addAll(dataList.sublist(8, 12));
      simID = DataExchangeUtils.byteToString(simIDList);

      List<int> list = sendPackToBluetooth49();
      sendData.add(list);

      LogUtil.d("$TAG simID=$simID");
      // LogUtil.d("$TAG simID=${DataExchangeUtils.bytesToHex(simIDList)}");
      notifyDeviceRegistSuccess();
    }
  }

  /// 蓝牙连接后第一步，发送时间戳到蓝牙
  List<int> getStepOneBluetoothCarNumber1() {
    List<int> sendPack = List.filled(17, 0);
    int position = 0;
    int count = 0;
    sendPack[position++] = 0xa5;
    sendPack[position++] = 0x03;
    sendPack[position++] = 1;
    sendPack[position++] = 8;
    var second = (DateTime.now().toUtc().millisecondsSinceEpoch) ~/ 1000;
    sendPack[12] = (second >> 24) & 0xff;
    sendPack[13] = (second >> 16) & 0xff;
    sendPack[14] = (second >> 8) & 0xff;
    sendPack[15] = second & 0xff;

    for (int i = 0; i < 16; i++) {
      count += sendPack[i];
    }
    sendPack[16] = count & 0xff;
    return sendPack;
  }

  /// 获取 发送车架号 的 数据包 产品名称
  List<List<int>> getPackToBluetoothCarNumber2_4(String cardNumberString) {

    List<List<int>> mList = [];
    List<int> dataArray = utf8.encode(cardNumberString);
    int dataLenght = 0;

    for (int i = 0; i < 3; i++) {
      int count = 0;
      int position = 0;
      List<int> sendPack = List.filled(17, 0);

      sendPack[position++] = 0xa5;
      sendPack[position++] = 0x03;
      sendPack[position++] = ((i + 2) & 0xff);
      sendPack[position++] = 8;
      var second = (DateTime.now().toUtc().millisecondsSinceEpoch) ~/ 1000;
      sendPack[position++] = (second >> 24) & 0xff;
      sendPack[position++] = (second >> 16) & 0xff;
      sendPack[position++] = (second >> 8) & 0xff;
      sendPack[position++] = second & 0xff;

      for (int j = 0; j < 8; j++) {
        int temp = i * 8 + j;
        if (temp >= dataArray.length) {
          if (i == 2 && j == 4) {
            sendPack[position++] = dataLenght & 0xff;
          } else {
            sendPack[position++] = 0;
          }
        } else {
          sendPack[position++] = dataArray[temp] & 0xff;
          dataLenght += sendPack[position - 1];
        }
      }

      for (int i = 0; i < 16; i++) {
        count += sendPack[i];
      }
      sendPack[position++] = count & 0xff;

      mList.add(sendPack);
    }
    return mList;
  }

  /// 获取 发送ProductKey 的数据包
  List<List<int>> getPackToBluetoothProductKey5_9(String productKeyString) {
    List<List<int>> mList = [];
    List<int> dataArray = utf8.encode(productKeyString);
    int dataLenght = 0;

    for (int i = 0; i < 5; i++) {
      int count = 0;
      int position = 0;
      List<int> sendPack = List.filled(17, 0);

      sendPack[position++] = 0xa5;
      sendPack[position++] = 0x03;
      sendPack[position++] = ((i + 5) & 0xff);
      sendPack[position++] = 8;
      var second = (DateTime.now().toUtc().millisecondsSinceEpoch) ~/ 1000;
      sendPack[position++] = (second >> 24) & 0xff;
      sendPack[position++] = (second >> 16) & 0xff;
      sendPack[position++] = (second >> 8) & 0xff;
      sendPack[position++] = second & 0xff;

      for (int j = 0; j < 8; j++) {
        int temp = i * 8 + j;
        if (temp >= dataArray.length) {
          if (i == 4 && j == 0) {
            sendPack[position++] = dataArray.length & 0xff;
          } else if (i == 4 && j == 1) {
            sendPack[position++] = dataLenght & 0xff;
          } else {
            sendPack[position++] = 0;
          }
        } else {
          sendPack[position++] = dataArray[temp] & 0xff;
          dataLenght += sendPack[position - 1];
        }
      }

      for (int i = 0; i < 16; i++) {
        count += sendPack[i];
      }
      sendPack[position++] = count & 0xff;

      mList.add(sendPack);
    }
    return mList;
  }

  /// 获取发送DeviceName 数据包
  List<List<int>> getPackToBluetoothProductKey10_14(String deviceNameString) {
    List<List<int>> mList = [];
    List<int> dataArray = utf8.encode(deviceNameString);
    int dataLenght = 0;

    for (int i = 0; i < 5; i++) {
      int count = 0;
      int position = 0;
      List<int> sendPack = List.filled(17, 0);

      sendPack[position++] = 0xa5;
      sendPack[position++] = 0x03;
      sendPack[position++] = ((i + 10) & 0xff);
      sendPack[position++] = 8;
      var second = (DateTime.now().toUtc().millisecondsSinceEpoch) ~/ 1000;
      sendPack[position++] = (second >> 24) & 0xff;
      sendPack[position++] = (second >> 16) & 0xff;
      sendPack[position++] = (second >> 8) & 0xff;
      sendPack[position++] = second & 0xff;

      for (int j = 0; j < 8; j++) {
        int temp = i * 8 + j;
        if (temp >= dataArray.length) {
          if (i == 4 && j == 0) {
            sendPack[position++] = dataArray.length & 0xff;
          } else if (i == 4 && j == 1) {
            sendPack[position++] = dataLenght & 0xff;
          } else {
            sendPack[position++] = 0;
          }
        } else {
          sendPack[position++] = dataArray[temp] & 0xff;
          dataLenght += sendPack[position - 1];
        }
      }

      for (int i = 0; i < 16; i++) {
        count += sendPack[i];
      }
      sendPack[position++] = count & 0xff;

      mList.add(sendPack);
    }
    return mList;
  }

  /// 获取发送DeviceSecret 数据包
  List<List<int>> getPackToBluetoothDeviceSecret15_23(
      String deviceSecretString) {
    List<List<int>> mList = [];
    List<int> dataArray = utf8.encode(deviceSecretString);
    int dataLenght = 0;

    for (int i = 0; i < 9; i++) {
      int count = 0;
      int position = 0;
      List<int> sendPack = List.filled(17, 0);

      sendPack[position++] = 0xa5;
      sendPack[position++] = 0x03;
      sendPack[position++] = ((i + 15) & 0xff);
      sendPack[position++] = 8;
      var second = (DateTime.now().toUtc().millisecondsSinceEpoch) ~/ 1000;
      sendPack[position++] = (second >> 24) & 0xff;
      sendPack[position++] = (second >> 16) & 0xff;
      sendPack[position++] = (second >> 8) & 0xff;
      sendPack[position++] = second & 0xff;

      for (int j = 0; j < 8; j++) {
        int temp = i * 8 + j;
        if (temp >= dataArray.length) {
          if (i == 8 && j == 0) {
            sendPack[position++] = dataArray.length & 0xff;
          } else if (i == 8 && j == 1) {
            sendPack[position++] = dataLenght & 0xff;
          } else {
            sendPack[position++] = 0;
          }
        } else {
          sendPack[position++] = dataArray[temp] & 0xff;
          dataLenght += sendPack[position - 1];
        }
      }

      for (int i = 0; i < 16; i++) {
        count += sendPack[i];
      }
      sendPack[position++] = count & 0xff;

      mList.add(sendPack);
    }
    return mList;
  }

  /// 获取 发送URL 数据包
  List<List<int>> getPackToBluetoothURL24_32(String urlString) {
    List<List<int>> mList = [];
    List<int> dataArray = utf8.encode(urlString);
    int dataLenght = 0;

    for (int i = 0; i < 9; i++) {
      int count = 0;
      int position = 0;
      List<int> sendPack = List.filled(17, 0);

      sendPack[position++] = 0xa5;
      sendPack[position++] = 0x03;
      sendPack[position++] = ((i + 24) & 0xff);
      sendPack[position++] = 8;
      var second = (DateTime.now().toUtc().millisecondsSinceEpoch) ~/ 1000;
      sendPack[position++] = (second >> 24) & 0xff;
      sendPack[position++] = (second >> 16) & 0xff;
      sendPack[position++] = (second >> 8) & 0xff;
      sendPack[position++] = second & 0xff;

      for (int j = 0; j < 8; j++) {
        int temp = i * 8 + j;
        if (temp >= dataArray.length) {
          if (i == 8 && j == 0) {
            sendPack[position++] = dataArray.length & 0xff;
          } else if (i == 8 && j == 1) {
            sendPack[position++] = dataLenght & 0xff;
          } else {
            sendPack[position++] = 0;
          }
        } else {
          sendPack[position++] = dataArray[temp] & 0xff;
          dataLenght += sendPack[position - 1];
        }
      }

      for (int i = 0; i < 16; i++) {
        count += sendPack[i];
      }
      sendPack[position++] = count & 0xff;

      mList.add(sendPack);
    }
    return mList;
  }

  /// 获取 激活 数据包
  List<int> getPackToBluetoothActivities33() {
    int count = 0;
    int position = 0;
    List<int> sendPack = List.filled(17, 0);

    sendPack[position++] = 0xa5;
    sendPack[position++] = 0x03;
    sendPack[position++] = ((33) & 0xff);
    sendPack[position++] = 8;
    var second = (DateTime.now().toUtc().millisecondsSinceEpoch) ~/ 1000;
    sendPack[position++] = (second >> 24) & 0xff;
    sendPack[position++] = (second >> 16) & 0xff;
    sendPack[position++] = (second >> 8) & 0xff;
    sendPack[position++] = second & 0xff;
    sendPack[position++] = 0x5a & 0xff;

    for (int i = 0; i < 16; i++) {
      count += sendPack[i];
    }
    sendPack[16] = count & 0xff;
    return sendPack;
  }

  /// app 二次连接
  static List<int> sendPackToBluetooth44(int privateKey) {
    List<int> dataArray = List.filled(4, 0);
    dataArray[0] = (privateKey >> 24) & 0xff;
    dataArray[1] = (privateKey >> 16) & 0xff;
    dataArray[2] = (privateKey >> 8) & 0xff;
    dataArray[3] = (privateKey >> 0) & 0xff;

    if (dataArray.length != 4) {
      throw ArgumentError("privateKey length must is four");
    }

    List<int> sendPack = List.filled(17, 0);

    int count = 0;

    int position = 0;
    sendPack[position++] = 0xa5;
    sendPack[position++] = 0x03;
    sendPack[position++] = (44 & 0xff);
    sendPack[position++] = 8;
    var second = (DateTime.now().toUtc().millisecondsSinceEpoch) ~/ 1000;
    sendPack[position++] = (second >> 24) & 0xff;
    sendPack[position++] = (second >> 16) & 0xff;
    sendPack[position++] = (second >> 8) & 0xff;
    sendPack[position++] = second & 0xff;
    sendPack[position++] = 0xA1;
    sendPack[position++] = 0xA2;
    sendPack[position++] = 0xA3;
    sendPack[position++] = 0xA4;

    for (int i = 0; i < dataArray.length; i++) {
      sendPack[position++] = dataArray[i] & 0xff;
    }

    for (int i = 0; i < 16; i++) {
      count += sendPack[i];
    }
    sendPack[position++] = count & 0xff;

    return sendPack;
  }

  /// app 发送心跳包
  static List<int> sendPackToBluetooth45(int num, String privateKey) {
    List<int> dataArray = utf8.encode(privateKey);

    if (dataArray.length != 4) {
      throw ArgumentError("privateKey length must is four");
    }

    List<int> sendPack = List.filled(17, 0);
    sendPack[10] = 0;
    sendPack[11] = 0;
    sendPack[15] = 0;
    int count = 0;

    int position = 0;
    sendPack[position++] = 0xa5;
    sendPack[position++] = 0x03;
    sendPack[position++] = (45 & 0xff);
    sendPack[position++] = 8;
    var second = (DateTime.now().toUtc().millisecondsSinceEpoch) ~/ 1000;
    sendPack[position++] = (second >> 24) & 0xff;
    sendPack[position++] = (second >> 16) & 0xff;
    sendPack[position++] = (second >> 8) & 0xff;
    sendPack[position++] = second & 0xff;
    sendPack[position++] = 0xA1;
    sendPack[position++] = 0xA2;
    sendPack[position++] = 0xA3;
    sendPack[position++] = 0xA4;

    for (int i = 0; i < dataArray.length; i++) {
      sendPack[position++] = dataArray[i] & 0xff;
    }

    for (int i = 0; i < 16; i++) {
      count += sendPack[i];
    }
    sendPack[position++] = count & 0xff;

    return sendPack;
  }

  /// 蓝牙控制界面， 进入页面和退出界面发送的数据  carStatus 1 进入页面，0退出页面
  ///  进入遥控器页面先发：0000000000000082，退出页面的时候发：0000000000000080
  List<int> sendBluePageInitAndMove(int carStatus) {
    List<int> sendPack = List.filled(17, 0);
    int count = 0;
    int position = 0;

    sendPack[position++] = 0xa5;
    sendPack[position++] = 0x03;
    sendPack[position++] = 46;
    sendPack[position++] = 8;
    var second = (DateTime.now().toUtc().millisecondsSinceEpoch) ~/ 1000;
    sendPack[position++] = (second >> 24) & 0xff;
    sendPack[position++] = (second >> 16) & 0xff;
    sendPack[position++] = (second >> 8) & 0xff;
    sendPack[position++] = second & 0xff;

    if (carStatus == 1) {
      sendPack[15] = (sendPack[15] | 0x82) & 0xff;
    } else {
      sendPack[15] = (sendPack[15] | 0x80) & 0xff;
    }

    for (int i = 0; i < 16; i++) {
      count += sendPack[i];
    }
    sendPack[16] = count & 0xff;

    return sendPack;
  }

  /// lockCarStatus lockCarStatus 锁车状态 0没关机、1开机
  /// setLock 设防 0关闭、1开启
  /// voice 喇叭 0关闭、1开启
  /// carStatus 汽车状态 1（前进）、2（后退）、0（停止）
  /// sportStatus 动能切换模式 1-3 ECO、运动、狂暴
  /// sportRecycle 动能回收 0-2  无、中、强
  /// lightStatus 灯状态 0-2  关闭、闪烁、常亮
  List<int> sendPackToBluetooth46(
      {int? lockCarStatus,
      int? setLock,
      int? voice,
      int? carStatus,
      int? sportStatus,
      int? sportRecycle,
      int? lightStatus}) {
    List<int> sendPack = List.filled(17, 0);
    sendPack[10] = 0;
    sendPack[11] = 0;
    sendPack[15] = 0;
    int count = 0;
    if (lockCarStatus != null) {
      if (lockCarStatus != 0 && lockCarStatus != 1) {
        throw ArgumentError("lockCarStatus is in(0、1)");
      }
    }

    if (setLock != null) {
      if (setLock != 0 && setLock != 1) {
        throw ArgumentError("setLock is in(0、1)");
      }
    }

    if (voice != null) {
      if (voice != 0 && voice != 1) {
        throw ArgumentError("voice is in(0、1)");
      }
    }

    if (lockCarStatus != null || setLock != null || voice != null) {
      sendPack[15] = (sendPack[15] | 1) & 0xff;
    }

    if (carStatus != null) {
      if (carStatus != 0 && carStatus != 1 && carStatus != 2) {
        throw ArgumentError("carStatus is in(0、1、2)");
      } else {
        sendPack[15] = (sendPack[15] | 0x02) & 0xff;
      }
    }

    if (sportStatus != null) {
      if (sportStatus != 1 && sportStatus != 2 && sportStatus != 3) {
        throw ArgumentError("sportStatus is in(1-3)");
      } else {
        sendPack[15] = (sendPack[15] | 0x10) & 0xff;
      }
    }

    if (sportRecycle != null) {
      if (sportRecycle != 0 && sportRecycle != 1 && sportRecycle != 2) {
        throw ArgumentError("sportRecycle is in(0、1、2)");
      } else {
        sendPack[15] = (sendPack[15] | 0x20) & 0xff;
      }
    }

    if (lightStatus != null) {
      if (lightStatus != 0 && lightStatus != 1 && lightStatus != 2) {
        throw ArgumentError("lightStatus is in(0、1、2)");
      } else {
        sendPack[15] = (sendPack[15] | 0x40) & 0xff;
      }
    }

    sendPack[15] = (sendPack[15] | 0x80) & 0xff;

    if (lockCarStatus == null &&
        setLock == null &&
        voice == null &&
        carStatus == null &&
        sportStatus == null &&
        sportRecycle == null &&
        lightStatus == null) {
      throw ArgumentError("param must have one");
    }

    int position = 0;
    sendPack[position++] = 0xa5;
    sendPack[position++] = 0x03;
    sendPack[position++] = 46;
    sendPack[position++] = 8;
    var second = (DateTime.now().toUtc().millisecondsSinceEpoch) ~/ 1000;
    sendPack[position++] = (second >> 24) & 0xff;
    sendPack[position++] = (second >> 16) & 0xff;
    sendPack[position++] = (second >> 8) & 0xff;
    sendPack[position++] = second & 0xff;

    int bit8 = 0;

    if (lockCarStatus != null) {
      bit8 |= lockCarStatus;
    }

    if (setLock != null) {
      bit8 |= ((setLock << 1) & 0xff);
    }

    if (voice != null) {
      bit8 |= ((voice << 3) & 0xff);
    }
    sendPack[position++] = bit8 & 0xff;

    if (carStatus != null) {
      sendPack[position++] = carStatus & 0xff;
    } else {
      sendPack[position++] = 0;
    }
    sendPack[position++] = 0;
    sendPack[position++] = 0;
    if (sportStatus != null) {
      sendPack[position++] = sportStatus & 0xff;
    } else {
      sendPack[position++] = 0;
    }
    if (sportRecycle != null) {
      sendPack[position++] = sportRecycle & 0xff;
    } else {
      sendPack[position++] = 0;
    }

    if (lightStatus != null) {
      sendPack[position++] = lightStatus & 0xff;
    } else {
      sendPack[position++] = 0;
    }
    sendPack[position++] = sendPack[15];
    for (int i = 0; i < 16; i++) {
      count += sendPack[i];
    }
    sendPack[position++] = count & 0xff;

    return sendPack;
  }

  /// app 发送simid应答
  List<int> sendPackToBluetooth49() {
    List<int> sendPack = List.filled(17, 0);
    int count = 0;

    int position = 0;
    sendPack[position++] = 0xa5;
    sendPack[position++] = 0x03;
    sendPack[position++] = (49 & 0xff);
    sendPack[position++] = 8;
    var second = (DateTime.now().toUtc().millisecondsSinceEpoch) ~/ 1000;
    sendPack[position++] = (second >> 24) & 0xff;
    sendPack[position++] = (second >> 16) & 0xff;
    sendPack[position++] = (second >> 8) & 0xff;
    sendPack[position++] = second & 0xff;
    sendPack[14] = 0xA3;

    for (int i = 0; i < 16; i++) {
      count += sendPack[i];
    }
    sendPack[16] = count & 0xff;

    return sendPack;
  }

  List<int> sendPackToBluetooth47_49(int num) {
    List<int> sendPack = List.filled(17, 0);
    sendPack[10] = 0;
    sendPack[11] = 0;
    sendPack[15] = 0;
    int count = 0;

    int position = 0;
    sendPack[position++] = 0xa5;
    sendPack[position++] = 0x03;
    sendPack[position++] = (num & 0xff);
    sendPack[position++] = 8;
    var second = (DateTime.now().toUtc().millisecondsSinceEpoch) ~/ 1000;
    sendPack[position++] = (second >> 24) & 0xff;
    sendPack[position++] = (second >> 16) & 0xff;
    sendPack[position++] = (second >> 8) & 0xff;
    sendPack[position++] = second & 0xff;
    sendPack[position++] = 0;
    sendPack[position++] = 0;
    sendPack[position++] = 0;
    sendPack[position++] = 0;
    sendPack[position++] = 0;
    sendPack[position++] = 0;
    sendPack[position++] = 0;
    sendPack[position++] = 0;

    for (int i = 0; i < 16; i++) {
      count += sendPack[i];
    }
    sendPack[position++] = count & 0xff;

    return sendPack;
  }

  /// 提交蓝牙数据到服务器
  uploadBluetoothDataToServer(Map<String, dynamic> dataMap,
      {VoidCallback? callback}) async {
    if (dataMap.isEmpty) {
      return null;
    }

    _loadApiData(
      ApiDevice.uploadBluetoothDataToServer(dataMap),
      showLoading: true,
      dataSuccess: (data) {
        if (callback != null) {
          callback();
        }
      },
    );
  }

  /// 获取注册设备到指定产品下所需要的证书
  getDeviceCertificate({Function(DeviceRegistParam)? callback}) async {
    if (deviceName == null) {
      return null;
    }

    _loadApiData<DeviceRegistParam>(
      ApiDevice.getDeviceCertificate(deviceName ?? ''),
      showLoading: true,
      dataSuccess: (data) {
        setDeviceRegistParam(data);
        LogUtil.d('-------------${data.toString()}');

        ///得到蓝牙从后台获取的证书
        if (callback != null) {
          callback(data);
        }
      },
    );
  }

  /// 通知服务器车辆注册成功
  Future<ResEmpty?> notifyDeviceRegistSuccess({VoidCallback? callback}) async {
    if (deviceName == null ||
        currentBlueName.isEmpty ||
        keyString == null ||
        simID == null) {
      return null;
    }

    _loadApiData(
      ApiDevice.vehicleRegisterSuccess(
          deviceName ?? '', currentBlueName, keyString ?? 0, simID ?? ''),
      voidSuccess: () {
        EventManager.post(AppEvent.vehicleRegistSuccess);
        if (callback != null) {
          callback();
        }
      },
    );
  }

  /// 请求接口，并对根据情况刷新页面状态
  /// params:
  ///   - errorMsg 发生异常时优先展示，如果没有则展示异常信息
  Future<ResData<T>?> _loadApiData<T>(Future<ResData<T>> api,
      {bool showLoading = false,
      String? errorMsg,
      Function(T data)? dataSuccess,
      Function()? voidSuccess,
      Function(String? errorMsg)? onFailed}) async {
    String? newErrorMsg;
    showLoading = false;
    try {
      //
      if (showLoading) {
        try {
          await LWLoading.showLoading2();
        } catch (e) {}
      }

      //
      var res = await api;

      if (showLoading) {
        await LWLoading.dismiss(animation: false);
      }

      if (res.data != null) {
        await dataSuccess?.call(res.data!);
      } else {
        await voidSuccess?.call();
      }
      return res;
    } on HttpErrorException catch (e) {
      if (showLoading) {
        await LWLoading.dismiss(animation: false);
      }

      newErrorMsg = e.message;
      if (e.code == '-1') {
        newErrorMsg =
            errorMsg ?? newErrorMsg ?? LocaleKeys.network_access_error.tr();
      } else {
        newErrorMsg = newErrorMsg ??
            errorMsg ??
            LocaleKeys.network_data_unknown_error.tr();
      }
      if (onFailed == null) {
        LWToast.show(newErrorMsg);
      } else {
        onFailed.call(newErrorMsg);
      }
      return null;
    } on Exception catch (e) {
      if (showLoading) {
        await LWLoading.dismiss(animation: false);
      }
      newErrorMsg = e.toString();
      onFailed?.call(newErrorMsg);
      return null;
    } finally {}
  }
}

class BlueDataVO {
  // 车速
  double carSpeed = 0;

  // 剩余里程
  double endurance = 0;

  // 电池电量
  int battery = 100;

  // 遥感距离
  String distance = "0";

  // 充电枪连接
  int chargeConnect = 0;

  BlueDataVO(
      {this.carSpeed = 0,
      this.endurance = 0,
      this.battery = 100,
      this.distance = "0",
      this.chargeConnect = 0});

  BlueDataVO.fromInitial(HomePageModel model) {
    carSpeed = 0;
    endurance = model.remainMile.toDouble();
    battery = model.electricity;
    distance = "0";
    chargeConnect = 0;
  }
}
