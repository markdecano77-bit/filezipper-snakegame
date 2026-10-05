import 'point.dart';

class Node {
  Point data;
  Node? prev;
  Node? next;
  Node(this.data);
}

class Deque {
  Node? _head;
  Node? _tail;
  int _size = 0;

  int get length => _size;
  Point get head => _head!.data;
  Point get tail => _tail!.data;

  void addFirst(Point p) {
    final newNode = Node(p);
    if (_head == null) {
      _head = _tail = newNode;
    } else {
      newNode.next = _head;
      _head!.prev = newNode;
      _head = newNode;
    }
    _size++;
  }

  Point removeLast() {
    if (_tail == null) throw StateError("Deque is empty");
    final data = _tail!.data;
    if (_head == _tail) {
      _head = _tail = null;
    } else {
      _tail = _tail!.prev;
      _tail!.next = null;
    }
    _size--;
    return data;
  }

  List<Point> toList() {
    final list = <Point>[];
    Node? curr = _head;
    while (curr != null) {
      list.add(curr.data);
      curr = curr.next;
    }
    return list;
  }

  void clear() {
    _head = _tail = null;
    _size = 0;
  }
}