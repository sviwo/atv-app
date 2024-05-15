import 'package:atv/archs/data/entity/res_data.dart';
import 'package:atv/archs/data/entity/res_empty.dart';
import 'package:atv/archs/data/net/http.dart';
import 'package:atv/archs/data/net/http_helper.dart';
import 'package:atv/config/data/entity/vehicle/device_regist_param.dart';

class ApiDevice {
  ApiDevice._();

  /// 激活设备前置检查  deviceName 设备的唯一标识(车架号)
  static Future<ResEmpty> checkVehicleRegisterValid(String deviceName) async {
    try {
      var data = await Http.instance().post('api/device/check/device/bind',
          params: {'deviceName': deviceName});
      return await HttpHelper.httpEmptyConvert(data);
    } catch (e) {
      throw HttpHelper.handleException(e);
    }
  }
  /// 设备激活成功通知服务器 deviceName 设备的唯一标识(车架号)
  static Future<ResEmpty> vehicleRegisterSuccess(String deviceName) async {
    try {
      var data = await Http.instance().post('api/device/activation/success',
          params: {'deviceName': deviceName});
      return await HttpHelper.httpEmptyConvert(data);
    } catch (e) {
      throw HttpHelper.handleException(e);
    }
  }
  /// DeviceRegistParam
  /// 获取注册设备到指定产品下所需要的证书 deviceName 设备的唯一标识(车架号)
  static Future<ResData<DeviceRegistParam>> getDeviceCertificate(String deviceName) async {
    try {
      var data = await Http.instance().get('api/device/get/secret',
          params: {'deviceName': deviceName});
      return await HttpHelper.httpDataConvert(data, (json) => DeviceRegistParam.fromJson(data));
    } catch (e) {
      throw HttpHelper.handleException(e);
    }
  }
}