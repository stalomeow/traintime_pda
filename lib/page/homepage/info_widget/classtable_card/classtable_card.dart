// Copyright 2023 BenderBlog Rodriguez and contributors.
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:watermeter/controller/classtable_controller.dart';
import 'package:watermeter/page/classtable/classtable.dart';

import 'package:watermeter/page/homepage/home_card_padding.dart';
import 'package:watermeter/page/homepage/info_widget/classtable_card/classtable_current.dart';
import 'package:watermeter/page/homepage/refresh.dart';

class ClassTableCard extends StatelessWidget {
  const ClassTableCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final c = Get.find<ClassTableController>();
        switch (c.state) {
          case ClassTableState.fetched:
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ClassTableWindow(
                  currentWeek: c.getCurrentWeek(updateTime),
                ),
              ),
            );
          case ClassTableState.error:
            Fluttertoast.showToast(msg: "遇到错误：${c.error}");
          case ClassTableState.fetching:
          case ClassTableState.none:
            Fluttertoast.showToast(msg: "正在获取课表");
        }
      },
      child: const ClasstableCurrentTimeline()
          .paddingDirectional(
            horizontal: 16,
            vertical: 14,
          )
          .withHomeCardStyle(
            Theme.of(context).colorScheme.secondary,
          ),
    );
  }
}
