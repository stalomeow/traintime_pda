// Copyright 2023 BenderBlog Rodriguez and contributors.
// SPDX-License-Identifier: MPL-2.0

// The class table window source.
// Thanks xidian-script and libxdauth!

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/network_session.dart';
import 'package:watermeter/repository/preference.dart' as preference;
import 'package:watermeter/model/xidian_ids/classtable.dart';
import 'package:watermeter/repository/xidian_ids/ehall_session.dart';

/// 课程表 4770397878132218
class ClassTableFile extends EhallSession {
  static const schoolClassName = "ClassTable.json";
  static const userDefinedClassName = "UserClass.json";

  ClassTableData simplifyData(Map<String, dynamic> qResult) {
    ClassTableData toReturn = ClassTableData();

    toReturn.semesterCode = qResult["semesterCode"];
    toReturn.termStartDay = qResult["termStartDay"];

    log.info(
      "[getClasstable][simplifyData] "
      "${toReturn.semesterCode} ${toReturn.termStartDay}",
    );

    for (var i in qResult["rows"]) {
      var toDeal = ClassDetail(
        name: i["KCM"],
        code: i["KCH"],
        number: i["KXH"],
      );
      if (!toReturn.classDetail.contains(toDeal)) {
        toReturn.classDetail.add(toDeal);
      }
      toReturn.timeArrangement.add(
        TimeArrangement(
          source: Source.school,
          index: toReturn.classDetail.indexOf(toDeal),
          start: int.parse(i["KSJC"]),
          teacher: i["SKJS"],
          stop: int.parse(i["JSJC"]),
          day: int.parse(i["SKXQ"]),
          weekList: List<bool>.generate(
            i["SKZC"].toString().length,
            (index) => i["SKZC"].toString()[index] == "1",
          ),
          classroom: i["JASMC"],
        ),
      );
      if (i["SKZC"].toString().length > toReturn.semesterLength) {
        toReturn.semesterLength = i["SKZC"].toString().length;
      }
    }

    // Deal with the not arranged data.
    for (var i in qResult["notArranged"]) {
      toReturn.notArranged.add(NotArrangementClassDetail(
        name: i["KCM"],
        code: i["KCH"],
        number: i["KXH"],
        teacher: i["SKJS"],
      ));
    }

    return toReturn;
  }

  Future<ClassTableData> get() async {
    Map<String, dynamic> qResult = {};
    log.info("[getClasstable][getFromWeb] Login the system.");
    String get = await useApp("4770397878132218");
    log.info("[getClasstable][getFromWeb] Location: $get");
    await dioEhall.post(get);

    log.info(
      "[getClasstable][getFromWeb] "
      "Fetch the semester information.",
    );
    String semesterCode = await dioEhall
        .post(
          "https://ehall.xidian.edu.cn/jwapp/sys/wdkb/modules/jshkcb/dqxnxq.do",
        )
        .then((value) => value.data['datas']['dqxnxq']['rows'][0]['DM']);
    if (preference.getString(preference.Preference.currentSemester) !=
        semesterCode) {
      preference.setString(
        preference.Preference.currentSemester,
        semesterCode,
      );
    }

    log.info(
      "[getClasstable][getFromWeb] "
      "Fetch the day the semester begin.",
    );
    String termStartDay = await dioEhall.post(
      'https://ehall.xidian.edu.cn/jwapp/sys/wdkb/modules/jshkcb/cxjcs.do',
      data: {
        'XN': '${semesterCode.split('-')[0]}-${semesterCode.split('-')[1]}',
        'XQ': semesterCode.split('-')[2]
      },
    ).then((value) => value.data['datas']['cxjcs']['rows'][0]["XQKSRQ"]);
    if (preference.getString(preference.Preference.currentStartDay) !=
        termStartDay) {
      preference.setString(
        preference.Preference.currentStartDay,
        termStartDay,
      );

      /// New semenster, user defined class is useless.
      var userClassFile = File("${supportPath.path}/$userDefinedClassName");
      if (userClassFile.existsSync()) userClassFile.deleteSync();
    }
    log.info(
      "[getClasstable][getFromWeb] "
      "Will get $semesterCode which start at $termStartDay.",
    );

    qResult = await dioEhall.post(
      'https://ehall.xidian.edu.cn/jwapp/sys/wdkb/modules/xskcb/xskcb.do',
      data: {
        'XNXQDM': semesterCode,
        'XH': preference.getString(preference.Preference.idsAccount),
      },
    ).then((value) => value.data['datas']['xskcb']);
    if (qResult['extParams']['code'] != 1) {
      log.warning(
        "[getClasstable][getFromWeb] "
        "extParams: ${qResult['extParams']['msg']} isNotPublish: "
        "${qResult['extParams']['msg'].toString().contains("查询学年学期的课程未发布")}",
      );
      if (qResult['extParams']['msg'].toString().contains("查询学年学期的课程未发布")) {
        log.warning(
          "[getClasstable][getFromWeb] "
          "extParams: ${qResult['extParams']['msg']} isNotPublish: "
          "Classtable not released.",
        );
        return ClassTableData(
          semesterCode: semesterCode,
          termStartDay: termStartDay,
        );
      } else {
        throw Exception("${qResult['extParams']['msg']}");
      }
    }

    log.info(
      "[getClasstable][getFromWeb] "
      "Preliminary storage...",
    );
    qResult["semesterCode"] = semesterCode;
    qResult["termStartDay"] = termStartDay;

    var notOnTable = await dioEhall.post(
      "https://ehall.xidian.edu.cn/jwapp/sys/wdkb/modules/xskcb/cxxsllsywpk.do",
      data: {
        'XNXQDM': semesterCode,
        'XH': preference.getString(preference.Preference.idsAccount),
      },
    ).then((value) => value.data['datas']['cxxsllsywpk']);

    log.info(
      "[getClasstable][getFromWeb] $notOnTable",
    );
    qResult["notArranged"] = notOnTable["rows"];

    ClassTableData preliminaryData = simplifyData(qResult);

    /// Deal with the class change.
    log.info(
      "[getClasstable][getFromWeb] "
      "Deal with the class change...",
    );

    qResult = await dioEhall.post(
      'https://ehall.xidian.edu.cn/jwapp/sys/wdkb/modules/xskcb/xsdkkc.do',
      data: {
        'XNXQDM': semesterCode,
        //'SKZC': "6",
        '*order': "-SQSJ",
      },
    ).then((value) => value.data['datas']['xsdkkc']);
    if (qResult['extParams']['code'] != 1) {
      log.warning(
        "[getClasstable][getFromWeb] ${qResult['extParams']['msg']}",
      );
    }

    // ignore: non_constant_identifier_names
    ChangeType type(String TKLXDM) {
      if (TKLXDM == '01') {
        return ChangeType.change; //调课
      } else if (TKLXDM == '02') {
        return ChangeType.stop; //停课
      } else {
        return ChangeType.patch; //补课
      }
    }

    // Merge change info

    if (int.parse(qResult["totalSize"].toString()) > 0) {
      for (var i in qResult["rows"]) {
        preliminaryData.classChanges.add(
          ClassChange(
            type: type(i["TKLXDM"]),
            classCode: i["KCH"],
            classNumber: i["KXH"],
            className: i["KCM"],
            originalAffectedWeeks: i["SKZC"] == null
                ? null
                : List<bool>.generate(
                    i["SKZC"].toString().length,
                    (index) => i["SKZC"].toString()[index] == "1",
                  ),
            newAffectedWeeks: i["XSKZC"] == null
                ? null
                : List<bool>.generate(
                    i["XSKZC"].toString().length,
                    (index) => i["XSKZC"].toString()[index] == "1",
                  ),
            originalTeacherData: i["YSKJS"],
            newTeacherData: i["XSKJS"],
            originalClassRange: [
              int.parse(i["KSJC"]?.toString() ?? "-1"),
              int.parse(i["JSJC"]?.toString() ?? "-1"),
            ],
            newClassRange: [
              int.parse(i["XKSJC"]?.toString() ?? "-1"),
              int.parse(i["XJSJC"]?.toString() ?? "-1"),
            ],
            originalWeek: i["SKXQ"],
            newWeek: i["XSKXQ"],
            originalClassroom: i["JASMC"],
            newClassroom: i["XJASMC"],
          ),
        );
      }
    }

    log.info(
      "[getClasstable][getFromWeb] "
      "Dealing class change with ${preliminaryData.classChanges.length} info(s).",
    );

    List<ClassChange> cache = [];

    for (var e in preliminaryData.classChanges) {
      /// First, search for the classes.
      /// Due to the unstability of the api, a list is introduced.
      List<int> indexClassDetailList = [];
      for (int i = 0; i < preliminaryData.classDetail.length; ++i) {
        if (preliminaryData.classDetail[i].code == e.classCode) {
          indexClassDetailList.add(i);
        }
      }

      /// Second, find the all time arrangement related to the class.
      log.info(
        "[getClasstable][getFromWeb] "
        "Class change related to class detail index $indexClassDetailList.",
      );
      List<int> indexOriginalTimeArrangementList = [];
      for (var currentClassIndex in indexClassDetailList) {
        for (int i = 0; i < preliminaryData.timeArrangement.length; ++i) {
          if (preliminaryData.timeArrangement[i].index == currentClassIndex &&
              preliminaryData.timeArrangement[i].day == e.originalWeek &&
              preliminaryData.timeArrangement[i].start ==
                  e.originalClassRange[0] &&
              preliminaryData.timeArrangement[i].stop ==
                  e.originalClassRange[1]) {
            indexOriginalTimeArrangementList.add(i);
          }
        }
      }

      /// Third, search for the time arrangements, seek for the truth.
      log.info(
        "[getClasstable][getFromWeb] "
        "Class change related to time arrangement index $indexOriginalTimeArrangementList.",
      );

      if (e.type == ChangeType.change) {
        /// Give a value to the
        int timeArrangementIndex = indexOriginalTimeArrangementList.first;

        log.info(
          "[getClasstable][getFromWeb] "
          "Class change. Teacher changed? ${e.isTeacherChanged}. timeArrangementIndex is $timeArrangementIndex",
        );
        for (int indexOriginalTimeArrangement
            in indexOriginalTimeArrangementList) {
          /// Seek for the change entry. Delete the classes moved waay.
          log.info(
            "[getClasstable][getFromWeb] "
            "Original weeklist ${preliminaryData.timeArrangement[indexOriginalTimeArrangement].weekList} "
            "with originalAffectedWeeksList ${e.originalAffectedWeeksList}.",
          );
          for (int i in e.originalAffectedWeeksList) {
            log.info(
              "[getClasstable][getFromWeb] "
              "Week $i, status ${preliminaryData.timeArrangement[indexOriginalTimeArrangement].weekList[i]}.",
            );
            if (preliminaryData
                .timeArrangement[indexOriginalTimeArrangement].weekList[i]) {
              preliminaryData.timeArrangement[indexOriginalTimeArrangement]
                  .weekList[i] = false;
              timeArrangementIndex = preliminaryData
                  .timeArrangement[indexOriginalTimeArrangement].index;
            }
          }

          log.info(
            "[getClasstable][getFromWeb] "
            "New weeklist ${preliminaryData.timeArrangement[indexOriginalTimeArrangement].weekList}.",
          );
        }

        if (timeArrangementIndex == indexOriginalTimeArrangementList.first) {
          cache.add(e);
          timeArrangementIndex = preliminaryData
              .timeArrangement[indexOriginalTimeArrangementList.first].index;
        }

        log.info(
          "[getClasstable][getFromWeb] "
          "New week: ${e.newAffectedWeeks}, "
          "day: ${e.newWeek}, "
          "startToStop: ${e.newClassRange}, "
          "timeArrangementIndex: $timeArrangementIndex.",
        );

        bool flag = false;
        ClassChange? toRemove;
        log.info("[getClasstable][getFromWeb] cache length = ${cache.length}");
        for (var f in cache) {
          //log.info("[getClasstable][getFromWeb]"
          //    "${f.className} ${f.classCode} ${f.originalClassRange} ${f.originalAffectedWeeksList} ${f.originalWeek}");
          //log.info("[getClasstable][getFromWeb]"
          //    "${e.className} ${e.classCode} ${e.newClassRange} ${e.newAffectedWeeksList} ${e.newWeek}");
          //log.info("[getClasstable][getFromWeb]"
          //    "${f.className == e.className} ${f.classCode == e.classCode} ${listEquals(f.originalClassRange, e.newClassRange)} ${listEquals(f.originalAffectedWeeksList, e.newAffectedWeeksList)} ${f.originalWeek == e.newWeek}");
          if (f.className == e.className &&
              f.classCode == e.classCode &&
              listEquals(f.originalClassRange, e.newClassRange) &&
              listEquals(f.originalAffectedWeeksList, e.newAffectedWeeksList) &&
              f.originalWeek == e.newWeek) {
            flag = true;
            toRemove = f;
            break;
          }
        }

        if (flag) {
          cache.remove(toRemove);
          log.info(
            "[getClasstable][getFromWeb] "
            "Cannot be added",
          );
          continue;
        }

        log.info(
          "[getClasstable][getFromWeb] "
          "Can be added",
        );

        /// Add classes.
        preliminaryData.timeArrangement.add(
          TimeArrangement(
            source: Source.school,
            index: timeArrangementIndex,
            weekList: e.newAffectedWeeks!,
            day: e.newWeek!,
            start: e.newClassRange[0],
            stop: e.newClassRange[1],
            classroom: e.newClassroom ?? e.originalClassroom,
            teacher: e.isTeacherChanged ? e.newTeacher : e.originalTeacher,
          ),
        );
      } else if (e.type == ChangeType.patch) {
        log.info(
          "[getClasstable][getFromWeb] "
          "Class patch.",
        );

        /// Add classes.
        preliminaryData.timeArrangement.add(
          TimeArrangement(
            source: Source.school,
            index: indexClassDetailList.first,
            weekList: e.newAffectedWeeks!,
            day: e.newWeek!,
            start: e.newClassRange[0],
            stop: e.newClassRange[1],
            classroom: e.newClassroom ?? e.originalClassroom,
            teacher: e.isTeacherChanged ? e.newTeacher : e.originalTeacher,
          ),
        );
      } else {
        log.info(
          "[getClasstable][getFromWeb] "
          "Class stop.",
        );

        for (int indexOriginalTimeArrangement
            in indexOriginalTimeArrangementList) {
          log.info(
            "[getClasstable][getFromWeb] "
            "Original weeklist "
            "${preliminaryData.timeArrangement[indexOriginalTimeArrangement].weekList} "
            "with originalAffectedWeeksList ${e.originalAffectedWeeksList}.",
          );
          for (int i in e.originalAffectedWeeksList) {
            log.info(
              "[getClasstable][getFromWeb] "
              "$i ${preliminaryData.timeArrangement[indexOriginalTimeArrangement].weekList[i]}",
            );
            if (preliminaryData
                .timeArrangement[indexOriginalTimeArrangement].weekList[i]) {
              preliminaryData.timeArrangement[indexOriginalTimeArrangement]
                  .weekList[i] = false;
            }
          }
          log.info(
            "[getClasstable][getFromWeb] "
            "New weeklist "
            "${preliminaryData.timeArrangement[indexOriginalTimeArrangement].weekList}.",
          );
        }
      }
    }

    return preliminaryData;
  }
}
