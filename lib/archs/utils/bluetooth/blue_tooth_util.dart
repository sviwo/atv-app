import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:atv/archs/utils/bluetooth/extra.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'blue_accept_data_listener.dart';
import 'package:atv/archs/utils/bluetooth/data_exchange_utils.dart';

class BlueToothUtil {
  // 私有的命名构造函数
  BlueToothUtil._internal();

  BlueAcceptDataListener? blueAcceptDataListener = null;

  // 初始化
  static BlueToothUtil? _instanceBlueToothUtil;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  StreamSubscription<BluetoothAdapterState>? _adapterStateStateSubscription;

  // 蓝牙开启状态
  List<BluetoothDevice> _systemDevices = []; // 当前已经连接的蓝牙设备
  List<ScanResult> _scanResults = []; // 扫描到的蓝牙设备
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<bool>? _isScanningSubscription;

  // 连接蓝牙
  int? _rssi;
  int? _mtuSize;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  bool _isConnecting = false;
  bool _isDisconnecting = false;

  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<bool>? _isConnectingSubscription;
  StreamSubscription<bool>? _isDisconnectingSubscription;
  StreamSubscription<int>? _mtuSubscription;
  BluetoothDevice? device;

  BluetoothCharacteristic? readChart;
  BluetoothCharacteristic? sendChart;
  List<List<int>> receiveData = []; // 接收蓝牙发送过来的数据

  /// 获取示例
  static BlueToothUtil getInstance() {
    if (_instanceBlueToothUtil == null) {
      _instanceBlueToothUtil = BlueToothUtil._internal();
      FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
      _instanceBlueToothUtil?._adapterStateStateSubscription =
          FlutterBluePlus.adapterState.listen((state) {
        _instanceBlueToothUtil?._adapterState = state;
        if (state == BluetoothAdapterState.off) {
          _instanceBlueToothUtil?._scanResultsSubscription = null;
          _instanceBlueToothUtil?._isScanningSubscription = null;

          _instanceBlueToothUtil?._systemDevices = [];
          _instanceBlueToothUtil?._scanResults = [];
          _instanceBlueToothUtil?._isScanning = false;

          _instanceBlueToothUtil?._services = [];
          _instanceBlueToothUtil?._isConnecting = false;
          _instanceBlueToothUtil?._isDisconnecting = false;
          _instanceBlueToothUtil?._connectionStateSubscription = null;
          _instanceBlueToothUtil?._isConnectingSubscription = null;
          _instanceBlueToothUtil?._isDisconnectingSubscription = null;
          _instanceBlueToothUtil?._mtuSubscription = null;
          _instanceBlueToothUtil?.device = null;
          _instanceBlueToothUtil?.readChart = null;
          _instanceBlueToothUtil?.sendChart = null;
        }
      });
    }
    return _instanceBlueToothUtil!;
  }

  /// 获取蓝牙是否开启 true 开启， false 关闭
  bool blueToothIsOpen() {
    return _adapterState == BluetoothAdapterState.on;
  }

  /// 开启蓝牙
  void openBlueTooth() async {
    try {
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      }
    } catch (e) {
      print("open blueTooth error:$e");
    }
  }

  /// 扫描蓝牙
  void startScanBlueTooth() async {
    if (_adapterState != BluetoothAdapterState.on) {
      print("please open blueTooth");
      return;
    }
    _scanResultsSubscription ??= FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results;
    }, onError: (e) {
      print("Scan Error:${e.toString()}");
    });

    _isScanningSubscription ??= FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
    });

    if (FlutterBluePlus.isScanningNow) {
      stopScanBlueTooth();
    }

    try {
      _systemDevices = await FlutterBluePlus.systemDevices;
    } catch (e) {
      print("System Devices Error:${e.toString()}");
    }
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      print("Start Scan Error:${e.toString()}");
    }
  }

  /// 停止蓝牙扫描
  void stopScanBlueTooth() async {
    if (_adapterState != BluetoothAdapterState.on) {
      print("please open blueTooth");
      return;
    }
    try {
      FlutterBluePlus.stopScan();
    } catch (e) {
      print("Stop Scan Error:${e.toString()}");
    }
  }

  /// 刷新扫描
  void onRefresh() {
    if (_adapterState != BluetoothAdapterState.on) {
      print("please open blueTooth");
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
      print("Request Mtu: Success");
    } catch (e) {
      print("Change Mtu Error:${e.toString()}");
    }
  }

  /// 连接蓝牙
  Future connectBluetooth(BluetoothDevice mdevice) async {
    if (getBlueToothConnectState() == -1) {
      mdevice.connectAndUpdateStream().catchError((e) {
        print("Connect Error:${e.toString()}");
      });
      _connectionStateSubscription =
          mdevice.connectionState.listen((state) async {
        _connectionState = state;
        if (state == BluetoothConnectionState.connected) {
          this.device = mdevice;
          _services = []; // must rediscover services
          try {
            _services = await mdevice.discoverServices();
            print("Discover Services: Success");
          } catch (e) {
            print("Discover Services: Success:${e.toString()}");
          }
        }
        if (state == BluetoothConnectionState.connected && _rssi == null) {
          _rssi = await mdevice.readRssi();
        }
      });

      _mtuSubscription = mdevice.mtu.listen((value) {
        _mtuSize = value;
      });

      _isConnectingSubscription = mdevice.isConnecting.listen((value) {
        _isConnecting = value;
      });

      _isDisconnectingSubscription = mdevice.isDisconnecting.listen((value) {
        _isDisconnecting = value;
      });
    }
  }

  /// 取消连接
  Future onCancelPressed() async {
    if (device != null && _isConnecting) {
      try {
        await device?.disconnectAndUpdateStream(queue: false);
        print("Cancel: Success");
      } catch (e) {
        print("Cancel Error:${e.toString()}");
      }
    }
  }

  /// 断开链接
  Future onDisconnectPressed() async {
    if (device != null &&
        _connectionState == BluetoothConnectionState.connected) {
      try {
        await device?.disconnectAndUpdateStream();
        print("Disconnect: Success");
      } catch (e) {
        print("Disconnect Error:${e.toString()}");
      }
    }
  }

  /// 发送数据
  Future sendDataToBlueTooth(List<int> sendData) async {
    if (sendChart == null) {
      print("sendChart is null");
    } else {
      await sendChart?.write(sendData);
    }
  }

  /// 监听蓝牙特征
  void listenerBlueToothReadChart() async {
    if (readChart == null) {
      print("readChart is null");
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
    if (_isConnecting) {
      return 0;
    } else if (_connectionState == BluetoothConnectionState.connected) {
      return 1;
    } else {
      return -1;
    }
  }

  void dispose() {
    _connectionStateSubscription?.cancel();
    _mtuSubscription?.cancel();
    _isConnectingSubscription?.cancel();
    _isDisconnectingSubscription?.cancel();

    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();

    _adapterStateStateSubscription?.cancel();
  }

  /// 解析蓝牙发送的数据
  void decodeBlueToothData(List<int> dataList) {
    print("acept blueTooth data:$dataList");
    if (dataList.length != 17) {
      print("dataList length must is 17");
      return;
    }
    if ((dataList[0] & 0xff) != 0xa5) {
      print("data index 0 must is 0xa5");
      return;
    }
    if ((dataList[1] & 0xff) != 0x10) {
      print("data index 1 must is 0x10");
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
      print("sum check failed");
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
    } else {
      print("blueTooth messageType error");
    }
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
    var second = DateTime.now().second;
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
    blueAcceptDataListener?.acceptBlueToothData(timeMillisecond, 1);
  }

  /// 解析蓝牙发送过来的数据  消息类型4  产品名称 应答
  void decodeBlueToothData4(List<int> dataList) {
    if ((dataList[14] & 0xff) == 0xa3) {
      blueAcceptDataListener?.acceptBlueToothData(true, 4);
    } else {
      blueAcceptDataListener?.acceptBlueToothData(false, 4);
    }
  }

  /// 解析蓝牙发送过来的数据  消息类型9  ProductKey
  void decodeBlueToothData9(List<int> dataList) {
    if ((dataList[14] & 0xff) == 0xa3) {
      blueAcceptDataListener?.acceptBlueToothData(true, 9);
    } else {
      blueAcceptDataListener?.acceptBlueToothData(false, 9);
    }
  }

  /// 解析蓝牙发送过来的数据  消息类型14  DeviceName
  void decodeBlueToothData14(List<int> dataList) {
    if ((dataList[14] & 0xff) == 0xa3) {
      blueAcceptDataListener?.acceptBlueToothData(true, 14);
    } else {
      blueAcceptDataListener?.acceptBlueToothData(false, 14);
    }
  }

  /// 解析蓝牙发送过来的数据  消息类型23 DeviceSecret
  void decodeBlueToothData23(List<int> dataList) {
    if ((dataList[14] & 0xff) == 0xa3) {
      blueAcceptDataListener?.acceptBlueToothData(true, 23);
    } else {
      blueAcceptDataListener?.acceptBlueToothData(false, 23);
    }
  }

  /// 解析蓝牙发送过来的数据  消息类型32 URL
  void decodeBlueToothData32(List<int> dataList) {
    if ((dataList[14] & 0xff) == 0xa3) {
      blueAcceptDataListener?.acceptBlueToothData(true, 32);
    } else {
      blueAcceptDataListener?.acceptBlueToothData(false, 32);
    }
  }

  /// 解析蓝牙发送过来的数据  消息类型33 握手是否成功
  void decodeBlueToothData33(List<int> dataList) {
    // bit0表示ProductKey，bit1表示DeviceName，bit2表示DeviceSecret，bit3表示URL
    bool checkResult = true;
    if ((dataList[9] & 0x01) == 1) {
    } else {
      checkResult = false;
      print("ProductKey check error");
    }
    if (((dataList[9] >> 1) & 0x01) == 1) {
    } else {
      checkResult = false;
      print("DeviceName check error");
    }
    if (((dataList[9] >> 2) & 0x01) == 1) {
    } else {
      checkResult = false;
      print("DeviceSecret check error");
    }
    if (((dataList[9] >> 3) & 0x01) == 1) {
    } else {
      checkResult = false;
      print("URL check error");
    }

    blueAcceptDataListener?.acceptBlueToothData(checkResult, 33);
  }


  /// 解析蓝牙发送过来的数据  消息类型34
  void decodeBlueToothData34(List<int> dataList) {
    // 维度
    double lat = DataExchangeUtils.bytesToFloat(dataList.sublist(8, 12));
    // 经度
    double lng = DataExchangeUtils.bytesToFloat(dataList.sublist(12, 16));

    Map<String, double> map = HashMap();
    map["lat"] = lat;
    map["lng"] = lng;
    blueAcceptDataListener?.acceptBlueToothData(map, 34);
  }

  /// 解析蓝牙发送过来的数据  消息类型35
  void decodeBlueToothData35(List<int> dataList) {
    // 维度
    double speed = DataExchangeUtils.bytesToFloat(dataList.sublist(8, 12));
    // 动能模式切换
    int sportSwitch = dataList[12] & 0xff;
    // 动能回收
    int sportRecycle = dataList[13] & 0xff;
    Map<String, Object> map = HashMap();
    map["speed"] = speed;
    map["sportSwitch"] = sportSwitch;
    map["sportRecycle"] = sportRecycle;

    blueAcceptDataListener?.acceptBlueToothData(map, 35);
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

    Map<String, Object> map = HashMap();
    map["lockCarStatus"] = lockCarStatus;
    map["setLock"] = setLock;
    map["wheelDrive"] = wheelDrive;
    map["shake"] = shake;
    map["voice"] = voice;
    map["alarm"] = alarm;
    map["alarmContinue"] = alarmContinue;
    map["deviceDefaultAlarm"] = deviceDefaultAlarm;
    map["carTemperatureHigh"] = carTemperatureHigh;
    map["chargeConnect"] = chargeConnect;
    map["lowPower"] = lowPower;
    map["lightStatus"] = lightStatus;
    map["doubleLightFlash"] = doubleLightFlash;
    map["leftLightFlash"] = leftLightFlash;
    map["rightLightFlash"] = rightLightFlash;

    blueAcceptDataListener?.acceptBlueToothData(map, 36);
  }

  /// 解析蓝牙发送过来的数据  消息类型37
  void decodeBlueToothData37(List<int> dataList) {
    // 电机转速
    int motorSpeed = DataExchangeUtils.fourByteListToInt(dataList.sublist(8, 12));
    // 车速
    double carSpeed = DataExchangeUtils.bytesToFloat(dataList.sublist(12, 16));

    Map<String, Object> map = HashMap();
    map["motorSpeed"] = motorSpeed;
    map["carSpeed"] = carSpeed;

    blueAcceptDataListener?.acceptBlueToothData(map, 37);
  }

  /// 解析蓝牙发送过来的数据  消息类型38
  void decodeBlueToothData38(List<int> dataList) {
    // 剩余里程float
    double range = DataExchangeUtils.bytesToFloat(dataList.sublist(8, 12));
    // 电池电量%
    int battery = dataList[12] & 0xff;
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

    Map<String, Object> map = HashMap();
    map["range"] = range;
    map["battery"] = battery;
    map["batteryStatus"] = batteryStatus;
    map["chargingStatus"] = chargingStatus;
    map["lackOfPowerStatus"] = lackOfPowerStatus;
    map["readyStatus"] = readyStatus;
    map["dischargeContactorStatus"] = dischargeContactorStatus;
    map["chargingContactorStatus"] = chargingContactorStatus;
    map["batteryDefaultLeve"] = batteryDefaultLeve;
    map["bmsCode"] = bmsCode;
    blueAcceptDataListener?.acceptBlueToothData(map, 38);
  }

  /// 解析蓝牙发送过来的数据  消息类型39
  void decodeBlueToothData39(List<int> dataList) {
    // 遥感距离1
    int rangeOne = DataExchangeUtils.twoByteToInt(dataList[8],dataList[9]);
    // 遥感距离2
    int rangeTwo = DataExchangeUtils.twoByteToInt(dataList[10],dataList[11]);
    // 遥感距离3
    int rangeThree = DataExchangeUtils.twoByteToInt(dataList[12],dataList[13]);
    // 遥感距离4
    int rangeFour = DataExchangeUtils.twoByteToInt(dataList[14],dataList[15]);

    Map<String, Object> map = HashMap();
    map["rangeOne"] = rangeOne;
    map["rangeTwo"] = rangeTwo;
    map["rangeThree"] = rangeThree;
    map["rangeFour"] = rangeFour;
    blueAcceptDataListener?.acceptBlueToothData(map, 39);
  }

  /// 解析蓝牙发送过来的数据  消息类型44
  void decodeBlueToothData44(List<int> dataList) {
    // 握手秘钥
    String shakeHandsKey = utf8.decode(dataList.sublist(12, 16));
    blueAcceptDataListener?.acceptBlueToothData(shakeHandsKey, 44);
  }

  /// 获取 发送车架号 的 数据包 产品名称
  List<List<int>> getPackToBluetoothCarNumber2_4(String cardNumberString) {
    if (cardNumberString.length != 20) {
      throw ArgumentError("cardNumberString length must is 20");
    }

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
      var second = DateTime.now().second;
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
      var second = DateTime.now().second;
      sendPack[position++] = (second >> 24) & 0xff;
      sendPack[position++] = (second >> 16) & 0xff;
      sendPack[position++] = (second >> 8) & 0xff;
      sendPack[position++] = second & 0xff;

      for (int j = 0; j < 8; j++) {
        int temp = i * 8 + j;
        if (temp >= dataArray.length) {
          if (i == 4 && j == 0) {
            sendPack[position++] = dataArray.length & 0xff;
          } else if (i == 4 && j == 0) {
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
      var second = DateTime.now().second;
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
      var second = DateTime.now().second;
      sendPack[position++] = (second >> 24) & 0xff;
      sendPack[position++] = (second >> 16) & 0xff;
      sendPack[position++] = (second >> 8) & 0xff;
      sendPack[position++] = second & 0xff;

      for (int j = 0; j < 8; j++) {
        int temp = i * 8 + j;
        if (temp >= dataArray.length) {
          if (i == 7 && j == 0) {
            sendPack[position++] = dataArray.length & 0xff;
          } else if (i == 7 && j == 1) {
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
      var second = DateTime.now().second;
      sendPack[position++] = (second >> 24) & 0xff;
      sendPack[position++] = (second >> 16) & 0xff;
      sendPack[position++] = (second >> 8) & 0xff;
      sendPack[position++] = second & 0xff;

      for (int j = 0; j < 8; j++) {
        int temp = i * 8 + j;
        if (temp >= dataArray.length) {
          if (i == 7 && j == 0) {
            sendPack[position++] = dataArray.length & 0xff;
          } else if (i == 7 && j == 1) {
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
  List<int> getPackToBluetoothActivities33(String privateKey) {
    List<int> dataArray = utf8.encode(privateKey);

    if (dataArray.length != 4) {
      throw ArgumentError("privateKey length must is four");
    }

    int count = 0;
    int position = 0;
    List<int> sendPack = List.filled(17, 0);

    sendPack[position++] = 0xa5;
    sendPack[position++] = 0x03;
    sendPack[position++] = ((33) & 0xff);
    sendPack[position++] = 8;
    var second = DateTime.now().second;
    sendPack[position++] = (second >> 24) & 0xff;
    sendPack[position++] = (second >> 16) & 0xff;
    sendPack[position++] = (second >> 8) & 0xff;
    sendPack[position++] = second & 0xff;
    sendPack[position++] = 0x5a & 0xff;
    sendPack[position++] = 0;
    sendPack[position++] = 0;
    sendPack[position++] = 0;

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
    var second = DateTime.now().second;
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
    var second = DateTime.now().second;
    sendPack[position++] = (second >> 24) & 0xff;
    sendPack[position++] = (second >> 16) & 0xff;
    sendPack[position++] = (second >> 8) & 0xff;
    sendPack[position++] = second & 0xff;

    int bit8 = 0;

    if (lockCarStatus != null) {
      bit8 |= lockCarStatus;
    }

    if (setLock != null) {
      bit8 |= ((setLock >> 1) & 0xff);
    }

    if (voice != null) {
      bit8 |= ((voice >> 3) & 0xff);
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

    for (int i = 0; i < 16; i++) {
      count += sendPack[i];
    }
    sendPack[position++] = count & 0xff;

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
    var second = DateTime.now().second;
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
}
