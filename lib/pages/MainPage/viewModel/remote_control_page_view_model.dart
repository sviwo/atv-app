import 'package:atv/archs/base/base_view_model.dart';
import 'package:atv/config/net/api_vehicle.dart';
import 'package:atv/generated/locale_keys.g.dart';
import 'package:atv/widgetLibrary/complex/toast/lw_toast.dart';
import 'package:easy_localization/easy_localization.dart';

class RemoteControlPageViewModel extends BaseViewModel {
  /// 蓝牙是否连接
  bool blueToothIsConnected = false;

  /// 喇叭是否打开
  bool bornIsOn = false;

  /// 灯光是否打开
  bool lightIsOn = false;

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

  @override
  void initialize(args) {
    // TODO: implement initialize
  }

  @override
  void release() {
    // TODO: implement release
  }
}
