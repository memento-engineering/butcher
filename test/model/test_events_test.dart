import 'package:radioactive_dart/radioactive_dart.dart';
import 'package:test/test.dart';

void main() {
  test('times each suite from its own events', () {
    final events = TestEvents.parse(
      '{"type":"suite","suite":{"id":0,"path":"test/a_test.dart"}}\n'
      '{"type":"suite","suite":{"id":1,"path":"test/b_test.dart"}}\n'
      '{"type":"testStart","test":{"id":1,"name":"a","suiteID":0},"time":100}\n'
      '{"type":"testStart","test":{"id":2,"name":"b","suiteID":1},"time":150}\n'
      '{"type":"testDone","testID":1,"result":"success","time":400}\n'
      '{"type":"testDone","testID":2,"result":"success","time":950}\n',
    );

    expect(events.suiteDurations, {
      'test/a_test.dart': const Duration(milliseconds: 300),
      'test/b_test.dart': const Duration(milliseconds: 800),
    });
  });

  test('reports windows suite paths the way dart test takes them', () {
    final events = TestEvents.parse(
      '{"type":"suite","suite":{"id":0,"path":"test\\\\a_test.dart"}}\n'
      '{"type":"testStart","test":{"id":1,"name":"a","suiteID":0},"time":10}\n'
      '{"type":"testDone","testID":1,"result":"success","time":20}\n',
    );

    expect(events.suiteDurations.keys, ['test/a_test.dart']);
  });

  test('times nothing when the stream carries no suite', () {
    final events = TestEvents.parse(
      '{"type":"testStart","test":{"id":1,"name":"a","suiteID":9},"time":10}\n'
      '{"type":"testDone","testID":1,"result":"success","time":20}\n',
    );

    expect(events.suiteDurations, isEmpty);
  });
}
