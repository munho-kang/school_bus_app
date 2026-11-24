// 친구 시간표: 공유 코드가 그대로 되살아나고 이상한 코드는 걸러지는지, 서랍에 내 QR이 뜨는지,
// 코드를 붙여넣어 친구를 넣으면 이름이 생기고·눌러서 시간표가 보이고·저장되고·지워지는지 검사한다.
// (카메라로 찍는 화면은 실제 기기에서만 돌아 여기선 검사하지 않는다 — 찍힌 글자는 붙여넣은 코드와 같은 길을 탄다.)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bus_tracker/ui/friends.dart';
import 'package:bus_tracker/ui/timetable.dart';

String _raw(Object rows) => 'JNUTT1:${base64Url.encode(utf8.encode(jsonEncode(rows)))}';

void main() {
  const List<Lesson> mine = <Lesson>[
    Lesson(title: '자료구조', days: <int>[1, 3], start: 630, end: 705),
    Lesson(title: '운영체제', days: <int>[2], start: 780, end: 855),
  ];

  test('공유 코드를 풀면 그대로', () {
    expect(encodeLessons(parseShareCode('  ${shareCode(mine)}\n')!), encodeLessons(mine)); // 앞뒤 공백·줄바꿈은 무시
  });

  test('이상한 코드는 받지 않는다', () {
    expect(parseShareCode(''), isNull);
    expect(parseShareCode('https://example.com'), isNull); // 다른 QR
    expect(parseShareCode('JNUTT1:!!!'), isNull); // 깨진 글자
    expect(parseShareCode(_raw(<Object>[])), isNull); // 수업 없음
    expect(parseShareCode(_raw(<String, int>{'a': 1})), isNull); // 목록이 아님
    expect(parseShareCode(_raw(<Object>[<Object>['수학', '6', 600, 660]])), isNull); // 없는 요일
    expect(parseShareCode(_raw(<Object>[<Object>['수학', '1', 660, 600]])), isNull); // 끝이 시작보다 이름
    expect(parseShareCode(_raw(<Object>[<Object>['수학', '1', 600, 99999]])), isNull); // 하루를 넘는 시각
    expect(parseShareCode(_raw(<Object>[<Object>['', '1', 600, 660]])), isNull); // 이름 없는 수업
    expect(parseShareCode(_raw(<Object>[<Object>['수학', '1', 600]])), isNull); // 칸이 모자람
  });

  testWidgets('서랍의 내 QR: 수업이 있어야 생기고, 코드 복사가 된다', (WidgetTester tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall c) async {
      if (c.method == 'Clipboard.setData') copied = (c.arguments as Map<dynamic, dynamic>)['text'] as String;
      return null;
    });
    Future<void> show(Map<String, Object> saved) async {
      SharedPreferences.setMockInitialValues(saved);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 272, child: MyQrCard(key: UniqueKey())))));
      await tester.pumpAndSettle();
    }

    await show(<String, Object>{});
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('수업을 넣으면'), findsOneWidget);

    await show(<String, Object>{'timetable': encodeLessons(mine)});
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.tap(find.text('코드 복사'));
    await tester.pumpAndSettle();
    expect(copied, shareCode(mine));
  });

  testWidgets('친구 추가 → 이름을 누르면 시간표 → 지우기', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FriendsRow())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('친구 추가'));
    await tester.pumpAndSettle();
    FilledButton save() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, '저장'));
    expect(save().onPressed, isNull); // 아직 아무것도 안 넣음
    await tester.enterText(find.widgetWithText(TextField, '또는 코드 붙여넣기'), '아무 글자');
    await tester.pump();
    expect(find.textContaining('코드가 올바르지 않아요'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '또는 코드 붙여넣기'), shareCode(mine));
    await tester.pump();
    expect(find.text('수업 2개를 읽었어요.'), findsOneWidget);
    expect(save().onPressed, isNull); // 이름이 아직 없음
    await tester.enterText(find.widgetWithText(TextField, '친구 이름'), '민수');
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    // 이름이 생기고, 껐다 켜도 남도록 저장된다.
    expect(find.text('민수'), findsOneWidget);
    Future<Map<String, dynamic>> saved() async =>
        jsonDecode((await SharedPreferences.getInstance()).getString('friends')!) as Map<String, dynamic>;
    expect(await saved(), <String, dynamic>{'민수': shareCode(mine)});

    // 이름을 누르면 친구의 시간표가 뜬다.
    await tester.tap(find.text('민수'));
    await tester.pumpAndSettle();
    expect(find.text('민수의 시간표'), findsOneWidget);
    expect(find.text('자료구조'), findsNWidgets(2)); // 월·수
    expect(find.text('운영체제'), findsOneWidget);

    // 지우면 이름도 저장도 사라진다.
    await tester.tap(find.byTooltip('친구 지우기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();
    expect(find.text('민수'), findsNothing);
    expect(await saved(), isEmpty);
  });

  testWidgets('저장된 친구는 다시 켜도 보이고, 같은 이름으로 추가하면 새 시간표로 바뀐다', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'friends': jsonEncode(<String, String>{'민수': shareCode(mine)}),
    });
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: FriendsRow())));
    await tester.pumpAndSettle();
    expect(find.text('민수'), findsOneWidget);

    final String changed = shareCode(const <Lesson>[Lesson(title: '선형대수', days: <int>[5], start: 540, end: 600)]);
    await tester.tap(find.text('친구 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '또는 코드 붙여넣기'), changed);
    await tester.enterText(find.widgetWithText(TextField, '친구 이름'), '민수');
    await tester.pump();
    expect(find.textContaining('같은 이름의 친구가 있어요'), findsOneWidget);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('민수'), findsOneWidget); // 둘로 늘지 않는다
    await tester.tap(find.text('민수'));
    await tester.pumpAndSettle();
    expect(find.text('선형대수'), findsOneWidget);
    expect(find.text('자료구조'), findsNothing);
  });
}
