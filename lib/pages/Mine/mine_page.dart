import 'package:atv/archs/base/base_mvvm_page.dart';
import 'package:atv/archs/base/event_manager.dart';
import 'package:atv/archs/utils/log_util.dart';
import 'package:atv/config/conf/app_conf.dart';
import 'package:atv/config/conf/app_event.dart';
import 'package:atv/config/conf/app_icons.dart';
import 'package:atv/config/conf/route/app_route_settings.dart';
import 'package:atv/config/data/entity/vehicle/vehicle_list_model.dart';
import 'package:atv/generated/locale_keys.g.dart';
import 'package:atv/pages/Mine/viewModel/mine_page_view_model.dart';
import 'package:atv/widgetLibrary/basic/font/lw_font_weight.dart';
import 'package:atv/widgetLibrary/complex/file/lw_image_loader.dart';
import 'package:atv/widgetLibrary/form/ui_form_label.dart';
import 'package:atv/widgetLibrary/utils/size_util.dart';
import 'package:card_swiper/card_swiper.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MinePage extends BaseMvvmPage {
  @override
  State<StatefulWidget> createState() => _MinePageState();
}

class _MinePageState
    extends BaseMvvmPageState<BaseMvvmPage, MinePageViewModel> {
  @override
  MinePageViewModel viewModelProvider() => MinePageViewModel();

  @override
  String? titleName() => LocaleKeys.personal_center.tr();

  @override
  Widget? headerBackgroundWidget() {
    return Image.asset(
      AppIcons.imgCommonBgUpStar,
      fit: BoxFit.cover,
    );
  }

  // @override
  // LWTitleBar? buildTitleBar() {
  //   // TODO: implement buildTitleBar
  //   return LWTitleBar();
  // }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    EventManager.register(context, AppEvent.userBaseInfoChange, (params) {
      viewModel.getUserData();
    });
    EventManager.register(context, AppEvent.languageChange, (params) async {
      viewModel.currentLauguage = await AppConf.getLauguage();
      updateState(() {});
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    EventManager.unregister(context, AppEvent.userBaseInfoChange);
    EventManager.unregister(context, AppEvent.languageChange);
    super.dispose();
  }

  @override
  bool isSupportScrollView() => true;

  @override
  Widget buildBody(BuildContext context) {
    // TODO: implement buildBody
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 57.dp,
        ),
        _buildHeader(),
        SizedBox(
          height: 50.dp,
        ),
        Divider(
          color: Colors.white,
          height: 0.5.dp,
        ),
        SizedBox(
          height: 17.dp,
        ),
        _buildList()
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 15.dp),
          width: 90.dp,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                  onTap: () {
                    pagePush(AppRoute.userInfo);
                  },
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(7.5.dp),
                      child: LWImageLoader.network(
                          imageUrl: viewModel.userInfo?.headImg ?? '',
                          width: 60.dp,
                          height: 60.dp))),
              SizedBox(
                height: 9.dp,
              ),
              Text(
                viewModel.fullName,
                maxLines: 3,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: LWFontWeight.bold,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        viewModel.vehicleList.isNotEmpty
            ? SizedBox(
                width: 201.dp,
                height: 120.dp,
                child: Swiper(
                  itemCount: viewModel.vehicleList.length,
                  index: 0,
                  // loop: viewModel.vehicleList.length > 1 ? true : false,
                  loop: false,
                  itemBuilder: (context, index) {
                    VehicleListModel model = viewModel.vehicleList[index];
                    return Column(
                      children: [
                        Container(
                          width: 172.dp,
                          height: 92.dp,
                          padding: EdgeInsets.fromLTRB(14.dp, 15.dp, 0, 0.dp),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(7.5.dp),
                              color: Colors.white),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                      child: Text(model.nickname ?? '-',
                                          style: TextStyle(
                                              color: const Color(0xff36BCB3),
                                              fontSize: 20.sp,
                                              fontWeight: LWFontWeight.bold))),
                                  RichText(
                                    text: TextSpan(children: [
                                      TextSpan(
                                          text: '${model.mileage ?? '0'} ',
                                          style: TextStyle(
                                              color: const Color(0xff1B1B1B),
                                              fontSize: 20.sp,
                                              fontWeight: LWFontWeight.bold)),
                                      TextSpan(
                                          text: 'km',
                                          style: TextStyle(
                                            color: const Color(0xff1B1B1B),
                                            fontSize: 8.sp,
                                          ))
                                    ]),
                                  ),
                                  SizedBox(
                                    width: 15.dp,
                                  )
                                ],
                              ),
                              SizedBox(
                                height: 14.dp,
                              ),
                              model.userDeviceType == 0
                                  ? UIFormLabel(
                                      LocaleKeys.VIN.tr(), model.deviceName,
                                      fontSize: 8.sp,
                                      bottomMargin: 0,
                                      labelColor: const Color(0xff1B1B1B),
                                      valueColor: const Color(0xff1B1B1B))
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                            child: UIFormLabel(
                                                LocaleKeys.VIN.tr(),
                                                model.deviceName,
                                                fontSize: 8.sp,
                                                bottomMargin: 0,
                                                maxLines: 2,
                                                labelColor:
                                                    const Color(0xff1B1B1B),
                                                valueColor:
                                                    const Color(0xff1B1B1B))),
                                        InkWell(
                                            onTap: () {
                                              showCupertinoDialog(
                                                context: context,
                                                builder: (context) {
                                                  return CupertinoAlertDialog(
                                                    title: Text(
                                                      LocaleKeys.reminder.tr(),
                                                      style: TextStyle(
                                                          fontSize: 20.dp,
                                                          color: Colors.black),
                                                    ),
                                                    content: Text(
                                                      LocaleKeys
                                                          .sure_want_to_delete_car
                                                          .tr(),
                                                      style: TextStyle(
                                                          fontSize: 14.dp,
                                                          color: Colors.black),
                                                    ),
                                                    actions: <Widget>[
                                                      TextButton(
                                                        child: Text(LocaleKeys
                                                            .cancel
                                                            .tr()),
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop();
                                                        },
                                                      ),
                                                      TextButton(
                                                        child: Text(LocaleKeys
                                                            .confirm
                                                            .tr()),
                                                        onPressed: () {
                                                          Navigator.of(context)
                                                              .pop();
                                                          viewModel
                                                              .deleteCar(model);
                                                        },
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                            child: Padding(
                                              padding: EdgeInsets.all(10.dp),
                                              child: Image.asset(
                                                AppIcons.imgMinePageCardDraft,
                                                width: 8.33.dp,
                                                height: 9.67.dp,
                                              ),
                                            )),
                                        SizedBox(
                                          width: 5.dp,
                                        )
                                      ],
                                    ),
                            ],
                          ),
                        ),
                        Image.asset(
                          AppIcons.imgMinePageCardBottom,
                          width: 200.dp,
                          height: 5.33.dp,
                        )
                      ],
                    );
                  },
                  onIndexChanged: (value) {
                    VehicleListModel model = viewModel.vehicleList[value];
                    viewModel.changeCar(model);
                  },
                ))
            : const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildList() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 131.dp,
          child: ListView.builder(
            itemCount: viewModel.itemNames.length,
            padding: EdgeInsets.fromLTRB(30.dp, 10.sp, 10.dp, 20.dp),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              var itemName = viewModel.itemNames[index];
              bool isAC = (itemName == LocaleKeys.authentication_center.tr() ||
                  itemName == LocaleKeys.multi_language.tr());
              var describe = '';
              if (itemName == LocaleKeys.authentication_center.tr()) {
                describe = viewModel.verifiedString;
              } else if (itemName == LocaleKeys.multi_language.tr()) {
                describe = viewModel.languageString ?? '-';
              }

              return Padding(
                padding:
                    EdgeInsets.only(top: 30.dp, bottom: isAC ? 20.dp : 30.dp),
                child: InkWell(
                  onTap: () {
                    LogUtil.d('点击了${viewModel.itemNames[index]}');
                    if (itemName == LocaleKeys.account.tr()) {
                      // 账户
                      pagePush(AppRoute.accountInfo);
                    } else if (itemName == LocaleKeys.help.tr()) {
                      // 帮助
                      pagePush(AppRoute.helpInfo);
                    } else if (itemName == LocaleKeys.multi_language.tr()) {
                      // 多语言
                      pagePush(AppRoute.multiLanguage);
                    } else if (itemName ==
                        LocaleKeys.authentication_center.tr()) {
                      // 认证中心
                      pagePush(AppRoute.authenticationCenter);
                      if (viewModel.userInfo?.authStatus == 0 ||
                          viewModel.userInfo?.authStatus == 3) {
                        pagePush(AppRoute.authenticationCenter);
                      } else if (viewModel.userInfo?.authStatus == 2) {}
                    } else if (itemName == LocaleKeys.quit.tr()) {
                      // 退出
                      showCupertinoDialog(
                        context: context,
                        builder: (context) {
                          return CupertinoAlertDialog(
                            title: Text(
                              LocaleKeys.reminder.tr(),
                              style: TextStyle(
                                  fontSize: 20.dp, color: Colors.black),
                            ),
                            content: Text(
                              LocaleKeys.sure_want_to_log_out.tr(),
                              style: TextStyle(
                                  fontSize: 14.dp, color: Colors.black),
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
                                  viewModel.logout();
                                },
                              ),
                            ],
                          );
                        },
                      );
                    }
                  },
                  child: Row(
                    crossAxisAlignment: isAC
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 21.dp,
                        child: Image.asset(
                          viewModel.itemImageNames[index],
                          width: viewModel.itemImageWidths[index],
                          height: viewModel.itemImageHeights[index],
                        ),
                      ),
                      SizedBox(
                        width: 11.5.dp,
                      ),
                      Expanded(
                          child: isAC
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      itemName,
                                      style: TextStyle(
                                          fontSize: 14.sp, color: Colors.white),
                                    ),
                                    SizedBox(
                                      height: 7.3.dp,
                                    ),
                                    Text(
                                      describe,
                                      style: TextStyle(
                                          fontSize: 12.sp,
                                          color: const Color(0xff36BCB3)),
                                    ),
                                  ],
                                )
                              : Text(
                                  itemName,
                                  style: TextStyle(
                                      fontSize: 14.dp, color: Colors.white),
                                )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          width: 0.5.dp,
          height: 410.dp,
          color: Colors.white,
        ),
        Expanded(
            child: ListView.builder(
          padding: EdgeInsets.only(top: 35.dp),
          itemCount: viewModel.productTitles.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return Container(
                alignment: Alignment.centerRight,
                padding: EdgeInsets.only(bottom: 44.dp),
                child: Column(
                  children: [
                    InkWell(
                        onTap: () {
                          LogUtil.d('点击了${viewModel.productTitles[index]}');
                        },
                        child: Stack(
                          fit: StackFit.loose,
                          children: [
                            Image.asset(viewModel.productImageNames[index],
                                width: 166.33.dp, height: 84.33.dp),
                            Positioned(
                              left: 14.dp,
                              top: 16.dp,
                              child: Text(
                                viewModel.productTitles[index],
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontWeight: LWFontWeight.normal),
                              ),
                            ),
                            Positioned(
                              bottom: 14.dp,
                              right: 5.dp,
                              child: Text(
                                viewModel.productDescrips[index],
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5.sp,
                                    fontWeight: LWFontWeight.normal),
                              ),
                            )
                          ],
                        )),
                    Image.asset(
                      AppIcons.imgMinePageCardBottom,
                      width: 200.dp,
                      height: 5.33.dp,
                      alignment: Alignment.bottomRight,
                    )
                  ],
                ));
          },
        ))
      ],
    );
  }
}
