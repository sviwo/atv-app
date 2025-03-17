import 'package:atv/archs/base/base_view_model.dart';
import 'package:atv/archs/base/event_manager.dart';
import 'package:atv/archs/utils/extension/ext_string.dart';
import 'package:atv/config/conf/app_event.dart';
import 'package:atv/config/net/api_home_page.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AuthenticationCenterViewModel extends BaseViewModel {
  /// 姓
  String? authFirstName;

  /// 名
  String? authLastName;

  /// 证件正面
  XFile? certificateFrontImgFile;

  Uint8List frontImage = Uint8List.fromList([]);

  Uint8List backImage = Uint8List.fromList([]);

  setFrontImage(XFile file) async {
    certificateFrontImgFile = file;
    frontImage = await file.readAsBytes();
    pageRefresh();
  }

  setBackImage(XFile file) async {
    certificateBackImgFile = file;
    backImage = await file.readAsBytes();
    pageRefresh();
  }

  /// 证件背面
  XFile? certificateBackImgFile;

  //合规判断
  bool get isLegal =>
      (authFirstName.isNullOrEmpty() == false) &&
      (authLastName.isNullOrEmpty() == false) &&
      certificateFrontImgFile != null &&
      certificateBackImgFile != null;

  submmitData() {
    if (isLegal == false) {
      return;
    }
    //上传实名认证信息
    loadApiData(
      ApiHomePage.submmitUserRealNameInfo(
          authFirstName: authFirstName,
          authLastName: authLastName,
          certificateFrontImgFile: certificateFrontImgFile,
          certificateBackImgFile: certificateBackImgFile),
      handlePageState: false,
      showLoading: true,
      voidSuccess: () {
        EventManager.post(AppEvent.userBaseInfoChange);
        pagePop();
      },
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
