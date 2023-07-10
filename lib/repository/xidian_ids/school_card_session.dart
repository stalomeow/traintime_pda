/*
Get your school card money's info, unless you use wechat or alipay...

Copyright (C) 2023 SuperBart

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
*/
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:beautiful_soup_dart/beautiful_soup.dart';
import 'package:watermeter/repository/xidian_ids/ids_session.dart';

class SchoolCardSession extends IDSSession {
  static String virtualCardUrl = "";
  static String personalCenter = "";

  Future<Uint8List> getQRCode() async {
    developer.log(
      "try to get QR Code",
      name: "SchoolCardSession",
    );
    var response = await dio
        .get("https://v8scan.xidian.edu.cn/$virtualCardUrl")
        .then((value) => BeautifulSoup(value.data));
    return base64Decode(
      response
              .find(
                'img',
                id: "qrcode",
              )
              ?.attributes["src"]
              ?.replaceAll(
                "data:image/png;base64,",
                "",
              )
              .replaceAll(
                "\n",
                "",
              ) ??
          "",
    );
  }

  Future<String> getMoney() async {
    var response = await dio
        .get("https://v8scan.xidian.edu.cn/$personalCenter")
        .then((value) => BeautifulSoup(value.data));
    return response.ul?.children[0].findAll('p')[1].innerHtml ?? "未查询到校园卡余额";
  }

  Future<void> initSession() async {
    var response = await dio.get(
      "https://v8scan.xidian.edu.cn/home/openXDOAuth2Page",
    );
    while (response.headers[HttpHeaders.locationHeader] != null) {
      String location = response.headers[HttpHeaders.locationHeader]![0];
      developer.log("Received: $location.", name: "SchoolCardSession");
      response = await dio.get(location);
    }
    var page = BeautifulSoup(response.data);

    page.findAll('a').forEach((element) {
      if (element["href"]?.contains("openVirtualcard") ?? false) {
        virtualCardUrl += element["href"]!;
      }
      if (element["href"]?.contains("openMyAccount") ?? false) {
        personalCenter += element["href"]!;
      }
    });
  }
}
