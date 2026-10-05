import 'point.dart';

/// Input Queue for directional keystroke buffering
class InputQueue {
  final List<Direction> _list = [];

  void enqueue(Direction d) {
    if (_list.length < 3) {
      _list.add(d);
    }
  }

  Direction? dequeue() {
    if (_list.isEmpty) return null;
    return _list.removeAt(0);
  }

  void clear() => _list.clear();
}