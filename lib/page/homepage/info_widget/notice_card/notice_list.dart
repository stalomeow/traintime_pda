// Copyright 2023 BenderBlog Rodriguez and contributors.
// SPDX-License-Identifier: MPL-2.0

import 'package:disclosure/disclosure.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:watermeter/page/public_widget/both_side_sheet.dart';
import 'package:watermeter/repository/message_session.dart';
import 'package:watermeter/page/public_widget/public_widget.dart';

class NoticeList extends StatelessWidget {
  const NoticeList({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => BothSideSheet(
        title: "应用信息",
        child: DisclosureGroup(
          multiple: false,
          clearable: true,
          children: List<Widget>.generate(messages.length, (index) {
            return Disclosure(
              key: ValueKey('disclosure-$index'),
              wrapper: (state, child) {
                return Card.outlined(
                  clipBehavior: Clip.antiAlias,
                  child: child,
                );
              },
              header: DisclosureButton(
                child: ListTile(
                  title: Row(
                    children: [
                      TagsBoxes(text: messages[index].type),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          messages[index].title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  trailing: const DisclosureSwitcher(
                    opened: Icon(Icons.arrow_drop_up),
                    closed: Icon(Icons.arrow_drop_down),
                  ),
                ),
              ),
              divider: const Divider(height: 1),
              child: Builder(builder: (context) {
                if (bool.tryParse(messages[index].isLink) ?? false) {
                  return FilledButton.icon(
                    onPressed: () => launchUrlString(
                      messages[index].message,
                      mode: LaunchMode.externalApplication,
                    ),
                    label: const Text("访问该链接"),
                    icon: const Icon(Icons.ads_click),
                  ).center();
                }
                return SelectableText(messages[index].message);
              }).padding(all: 12),
            );
          }),
        ).scrollable().padding(top: 20),
      ),
    );

    /*
      SimpleDialog(
        title: const Text(),
        children: List.generate(
          messages.length,
          (index) => SimpleDialogOption(
            onPressed: () {
              if (bool.parse(messages[index].isLink)) {
                launchUrlString(
                  messages[index].message,
                  mode: LaunchMode.externalApplication,
                );
              } else {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(messages[index].title),
                    content: SelectableText(messages[index].message),
                  ),
                );
              }
            },
            child: Row(
              children: [
                TagsBoxes(text: messages[index].type),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    messages[index].title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );*/
  }
}
