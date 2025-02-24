import 'package:atv/archs/base/base_mvvm_page.dart';
import 'package:atv/archs/utils/log_util.dart';
import 'package:atv/config/conf/app_icons.dart';
import 'package:atv/config/data/entity/vehicle/vehicle_info.dart';
import 'package:atv/generated/locale_keys.g.dart';
import 'package:atv/pages/MainPage/viewModel/safety_info_page_view_model.dart';
import 'package:atv/widgetLibrary/basic/button/lw_button.dart';
import 'package:atv/widgetLibrary/basic/font/lw_font_weight.dart';
import 'package:atv/widgetLibrary/complex/toast/lw_toast.dart';
import 'package:atv/widgetLibrary/utils/size_util.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_switch/flutter_switch.dart';

class SafetyInfoPage extends BaseMvvmPage {
  @override
  State<StatefulWidget> createState() => _SafetyInfoPageState();
}

class _SafetyInfoPageState
    extends BaseMvvmPageState<SafetyInfoPage, SafetyInfoPageViewModel> {
  @override
  SafetyInfoPageViewModel viewModelProvider() => SafetyInfoPageViewModel();
  @override
  String? titleName() => LocaleKeys.safety.tr();
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
        _buildLockRow(),
        Visibility(
            visible: viewModel.mobileKeysIsOn,
            child: SizedBox(
              height: 26.dp,
            )),
        Visibility(
            visible: viewModel.mobileKeysIsOn, child: _buildUploadItems()),
        SizedBox(
          height: 50.dp,
        ),
        _buildSpeedLimitRow()
      ],
    );
  }

  Widget _buildLockRow() {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.dp),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 5.dp),
              child: Image.asset(
                AppIcons.imgSafetyLockIcon,
                width: 17.dp,
                height: 27.7.dp,
              ),
            ),
            SizedBox(
              width: 29.dp,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocaleKeys.mobile_keys.tr(),
                    style: TextStyle(fontSize: 14.dp, color: Colors.white),
                  ),
                  SizedBox(
                    height: 6.dp,
                  ),
                  Text(
                    LocaleKeys.mobile_keys_describe.tr(),
                    style: TextStyle(fontSize: 9.5.dp, color: Colors.white),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 5.dp,
            ),
            Padding(
              padding: EdgeInsets.only(top: 10.dp),
              child: StatefulBuilder(
                builder: (BuildContext context, setStateT) {
                  return _buildSwitch(
                    isOn: viewModel.mobileKeysIsOn,
                    enable: true,
                    callback: (value) {
                      setStateT(
                        () {
                          viewModel.mobileKeysIsOn =
                              !(viewModel.mobileKeysIsOn);
                          viewModel.onOrCloseMobileKeys((isSuccess) => null);
                        },
                      );
                    },
                  );
                },
              ),
            )
          ],
        ));
  }

  Widget _buildUploadItems() {
    List<VehicleInfoKeyInfo> carKeyList =
        viewModel.dataModel?.userCarKeyList ?? [];
    ;

    return StatefulBuilder(
      builder: (context, setStateT) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Visibility(
                visible: carKeyList.isNotEmpty,
                child: Padding(
                    padding: EdgeInsets.only(left: 25.dp),
                    child: LWButton.text(
                      text: viewModel.inDeleteMode
                          ? LocaleKeys.remove_car_back_key.tr()
                          : LocaleKeys.remove_car_key.tr(),
                      textColor: const Color(0xffC40808),
                      textSize: 16.sp,
                      backgroundColor: Colors.transparent,
                      minWidth: 60.dp,
                      minHeight: 44.dp,
                      // shape: RoundedRectangleBorder(
                      //     borderRadius: BorderRadius.all(Radius.circular(25.dp))),
                      onPressed: () {
                        setStateT(
                          () {
                            viewModel.inDeleteMode = !(viewModel.inDeleteMode);
                          },
                        );
                      },
                    ))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40.dp),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                      onTap: () {
                        if (carKeyList.isNotEmpty) {
                          return;
                        }
                        viewModel.getShareCarKey((isSuccess, {carKey}) async {
                          await Clipboard.setData(
                              ClipboardData(text: carKey ?? ''));
                          LWToast.show(LocaleKeys.car_key_get_success.tr(),
                              duration: 3000);
                        });
                      },
                      child: carKeyList.isNotEmpty
                          ? Container(
                              width: 80.dp,
                              height: 80.dp,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                  image: DecorationImage(
                                      image: AssetImage(
                                          AppIcons.imgSafetyMobileKeyBg),
                                      fit: BoxFit.cover)),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Padding(
                                      padding: EdgeInsets.all(2.dp),
                                      child: Center(
                                        child: Text(
                                          carKeyList.first.name ?? '-',
                                          maxLines: 3,
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 18.dp,
                                              overflow: TextOverflow.ellipsis,
                                              fontWeight: LWFontWeight.bold),
                                        ),
                                      )),
                                  Visibility(
                                      visible: viewModel.inDeleteMode,
                                      child: Align(
                                        alignment: Alignment.topRight,
                                        child: InkWell(
                                          onTap: () {
                                            showDeleteAlert(
                                                carKeyList[0].userDeviceId);
                                          },
                                          child: Padding(
                                            padding: EdgeInsets.all(8.dp),
                                            child: Image.asset(
                                              AppIcons.imgSafetyMobileKeyDelete,
                                              width: 7.dp,
                                              height: 7.dp,
                                            ),
                                          ),
                                        ),
                                      ))
                                ],
                              ),
                            )
                          : DottedBorder(
                              borderType: BorderType.RRect,
                              radius: Radius.circular(11.dp),
                              // padding: EdgeInsets.all(6),
                              color: Colors.white,
                              child: Container(
                                width: 80.dp,
                                height: 80.dp,
                                alignment: Alignment.center,
                                child: Text(
                                  "+",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.dp,
                                      fontWeight: LWFontWeight.bold),
                                ),
                              ))),
                  InkWell(
                      onTap: () {
                        if (carKeyList.length > 1) {
                          return;
                        }
                        viewModel.getShareCarKey((isSuccess, {carKey}) async {
                          await Clipboard.setData(
                              ClipboardData(text: carKey ?? ''));
                          LWToast.show(LocaleKeys.car_key_get_success.tr(),
                              duration: 3000);
                        });
                      },
                      child: carKeyList.length > 1
                          ? Container(
                              width: 80.dp,
                              height: 80.dp,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                  image: DecorationImage(
                                      image: AssetImage(
                                          AppIcons.imgSafetyMobileKeyBg),
                                      fit: BoxFit.cover)),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Padding(
                                      padding: EdgeInsets.all(2.dp),
                                      child: Center(
                                        child: Text(
                                          carKeyList[1].name ?? '-',
                                          maxLines: 3,
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 18.dp,
                                              overflow: TextOverflow.ellipsis,
                                              fontWeight: LWFontWeight.bold),
                                        ),
                                      )),
                                  Visibility(
                                      visible: viewModel.inDeleteMode,
                                      child: Align(
                                        alignment: Alignment.topRight,
                                        child: InkWell(
                                          onTap: () {
                                            showDeleteAlert(
                                                carKeyList[1].userDeviceId);
                                          },
                                          child: Padding(
                                            padding: EdgeInsets.all(8.dp),
                                            child: Image.asset(
                                              AppIcons.imgSafetyMobileKeyDelete,
                                              width: 7.dp,
                                              height: 7.dp,
                                            ),
                                          ),
                                        ),
                                      ))
                                ],
                              ),
                            )
                          : DottedBorder(
                              borderType: BorderType.RRect,
                              radius: Radius.circular(11.dp),
                              // padding: EdgeInsets.all(6),
                              color: Colors.white,
                              child: Container(
                                width: 80.dp,
                                height: 80.dp,
                                alignment: Alignment.center,
                                child: Text(
                                  "+",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.dp,
                                      fontWeight: LWFontWeight.bold),
                                ),
                              ))),
                  InkWell(
                      onTap: () {
                        if (carKeyList.length > 2) {
                          return;
                        }
                        viewModel.getShareCarKey((isSuccess, {carKey}) async {
                          await Clipboard.setData(
                              ClipboardData(text: carKey ?? ''));
                          LWToast.show(LocaleKeys.car_key_get_success.tr(),
                              duration: 3000);
                        });
                      },
                      child: carKeyList.length > 2
                          ? Container(
                              width: 80.dp,
                              height: 80.dp,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                  image: DecorationImage(
                                      image: AssetImage(
                                          AppIcons.imgSafetyMobileKeyBg),
                                      fit: BoxFit.cover)),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Padding(
                                      padding: EdgeInsets.all(2.dp),
                                      child: Center(
                                        child: Text(
                                          carKeyList[2].name ?? '-',
                                          maxLines: 3,
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 18.dp,
                                              overflow: TextOverflow.ellipsis,
                                              fontWeight: LWFontWeight.bold),
                                        ),
                                      )),
                                  Visibility(
                                      visible: viewModel.inDeleteMode,
                                      child: Align(
                                        alignment: Alignment.topRight,
                                        child: InkWell(
                                          onTap: () {
                                            showDeleteAlert(
                                                carKeyList[2].userDeviceId);
                                          },
                                          child: Padding(
                                            padding: EdgeInsets.all(8.dp),
                                            child: Image.asset(
                                              AppIcons.imgSafetyMobileKeyDelete,
                                              width: 7.dp,
                                              height: 7.dp,
                                            ),
                                          ),
                                        ),
                                      ))
                                ],
                              ),
                            )
                          : DottedBorder(
                              borderType: BorderType.RRect,
                              radius: Radius.circular(11.dp),
                              // padding: EdgeInsets.all(6),
                              color: Colors.white,
                              child: Container(
                                width: 80.dp,
                                height: 80.dp,
                                alignment: Alignment.center,
                                child: Text(
                                  "+",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.dp,
                                      fontWeight: LWFontWeight.bold),
                                ),
                              )))
                ],
              ),
            )
          ],
        );
      },
    );
  }

  Widget _buildSpeedLimitRow() {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.dp),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 5.dp),
              child: Image.asset(
                AppIcons.imgSafetySpeedLimitIcon,
                width: 26.7.dp,
                height: 31.7.dp,
              ),
            ),
            SizedBox(
              width: 19.dp,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocaleKeys.speed_limit_model.tr(),
                    style: TextStyle(fontSize: 14.dp, color: Colors.white),
                  ),
                  SizedBox(
                    height: 6.dp,
                  ),
                  Text(
                    LocaleKeys.speed_limit_model_decribe.tr(),
                    style: TextStyle(fontSize: 9.5.dp, color: Colors.white),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 5.dp,
            ),
            Padding(
              padding: EdgeInsets.only(top: 10.dp),
              child: StatefulBuilder(
                builder: (BuildContext context, setStateT) {
                  return _buildSwitch(
                    isOn: viewModel.speedLimitIsOn,
                    enable: true,
                    callback: (value) {
                      setStateT(
                        () {
                          viewModel.speedLimitIsOn =
                              !(viewModel.speedLimitIsOn);
                          viewModel.onOrCloseSpeedLimit((isSuccess) => null);
                        },
                      );
                    },
                  );
                },
              ),
            )
          ],
        ));
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
        // pageRefresh(() {});
      },
    );
  }

  showDeleteAlert(String? carKey) {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(
            LocaleKeys.reminder.tr(),
            style: TextStyle(fontSize: 20.dp, color: Colors.black),
          ),
          content: Text(
            LocaleKeys.sure_want_to_delete_car_key.tr(),
            style: TextStyle(fontSize: 14.dp, color: Colors.black),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(LocaleKeys.cancel.tr()),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(LocaleKeys.confirm.tr()),
              onPressed: () {
                Navigator.of(context).pop();
                viewModel.deleteCar(carKey);
              },
            ),
          ],
        );
      },
    );
  }
}
