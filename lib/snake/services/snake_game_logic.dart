import 'dart:collection';
import 'dart:math';

import '../models/point.dart';
import '../models/double_linked_list.dart';
import '../models/input_queue.dart';

enum SnakeMode { classic, adventure }

enum SnakeSpeed { slow, fast, veryFast, challenge }

class SnakeGameLogic {
  static const int gridWidth = 30;
  static const int gridHeight = 20;

  final Deque body = Deque();
  final Set<Point> bodySet = {};
  final InputQueue inputQueue = InputQueue();

  final Set<Point> obstacles = {};

  Direction currentDirection = Direction.right;

  Point food = const Point(1, 1);

  int score = 0;
  int highScore = 0;
  int level = 1;

  bool isGameOver = false;
  bool isPaused = false;
  bool isAiMode = false;

  SnakeMode mode = SnakeMode.classic;
  SnakeSpeed speed = SnakeSpeed.slow;

  final List<int> leaderboard = [];

  final Random _random = Random();

  void reset() {
    body.clear();
    bodySet.clear();
    inputQueue.clear();
    obstacles.clear();

    score = 0;
    level = 1;

    isGameOver = false;
    isPaused = false;

    currentDirection = Direction.right;

    body.addFirst(const Point(13, 10));
    bodySet.add(const Point(13, 10));

    body.addFirst(const Point(14, 10));
    bodySet.add(const Point(14, 10));

    body.addFirst(const Point(15, 10));
    bodySet.add(const Point(15, 10));

    _createObstacles();
    _spawnFood();
  }

  void handleInput(Direction direction) {
    if (isGameOver) return;
    inputQueue.enqueue(direction);
  }

  int get timerMilliseconds {
    switch (speed) {
      case SnakeSpeed.slow:
        return 180;

      case SnakeSpeed.fast:
        return 120;

      case SnakeSpeed.veryFast:
        return 75;

      case SnakeSpeed.challenge:
        if (score < 20) return 180;
        if (score < 40) return 120;
        return 75;
    }
  }

  String get speedName {
    switch (speed) {
      case SnakeSpeed.slow:
        return 'Slow';

      case SnakeSpeed.fast:
        return 'Fast';

      case SnakeSpeed.veryFast:
        return 'Very Fast';

      case SnakeSpeed.challenge:
        return 'Challenge';
    }
  }

  String get modeName {
    return mode == SnakeMode.classic ? 'Classic' : 'Adventure';
  }

  void tick() {
    if (isGameOver || isPaused) return;

    if (isAiMode) {
      final aiDirection = _getNextAiDirection();

      if (aiDirection != null) {
        currentDirection = aiDirection;
      }
    } else {
      final nextDirection = inputQueue.dequeue();

      if (nextDirection != null &&
          !_isOpposite(currentDirection, nextDirection)) {
        currentDirection = nextDirection;
      }
    }

    final head = body.head;

    Point newHead;

    switch (currentDirection) {
      case Direction.up:
        newHead = Point(head.x, head.y - 1);
        break;

      case Direction.down:
        newHead = Point(head.x, head.y + 1);
        break;

      case Direction.left:
        newHead = Point(head.x - 1, head.y);
        break;

      case Direction.right:
        newHead = Point(head.x + 1, head.y);
        break;
    }

    if (newHead.x < 0 ||
        newHead.x >= gridWidth ||
        newHead.y < 0 ||
        newHead.y >= gridHeight) {
      _gameOver();
      return;
    }

    if (mode == SnakeMode.adventure && obstacles.contains(newHead)) {
      _gameOver();
      return;
    }

    if (bodySet.contains(newHead) && newHead != body.tail) {
      _gameOver();
      return;
    }

    body.addFirst(newHead);
    bodySet.add(newHead);

    if (newHead == food) {
      score += 10;

      if (score > highScore) {
        highScore = score;
      }

      if (mode == SnakeMode.adventure) {
        final newLevel = (score ~/ 50) + 1;

        if (newLevel != level) {
          level = newLevel;
          _createObstacles();
        }
      }

      _spawnFood();
    } else {
      final tail = body.removeLast();
      bodySet.remove(tail);
    }
  }

  void _gameOver() {
    isGameOver = true;

    leaderboard.add(score);
    leaderboard.sort((a, b) => b.compareTo(a));

    if (leaderboard.length > 10) {
      leaderboard.removeRange(10, leaderboard.length);
    }
  }

  void togglePause() {
    if (!isGameOver) {
      isPaused = !isPaused;
    }
  }

  void setMode(SnakeMode newMode) {
    mode = newMode;
    reset();
  }

  void setSpeed(SnakeSpeed newSpeed) {
    speed = newSpeed;
  }

  void _createObstacles() {
    obstacles.clear();

    if (mode != SnakeMode.adventure) {
      return;
    }

    // Level 1 has no obstacles.
    if (level <= 1) {
      return;
    }

    int amount = 3 + ((level - 2) * 3);

    final maxObstacles = (gridWidth * gridHeight) ~/ 5;

    if (amount > maxObstacles) {
      amount = maxObstacles;
    }

    int created = 0;

    while (created < amount) {
      final point = Point(
        _random.nextInt(gridWidth),
        _random.nextInt(gridHeight),
      );

      if (bodySet.contains(point)) {
        continue;
      }

      if (point == food) {
        continue;
      }

      obstacles.add(point);
      created++;
    }
  }

  void _spawnFood() {
    if (bodySet.length + obstacles.length >= gridWidth * gridHeight) {
      return;
    }

    Point newFood;

    do {
      newFood = Point(_random.nextInt(gridWidth), _random.nextInt(gridHeight));
    } while (bodySet.contains(newFood) || obstacles.contains(newFood));

    food = newFood;
  }

  Direction? _getNextAiDirection() {
    final start = body.head;
    final target = food;

    if (start == target) {
      return null;
    }

    final queue = Queue<Point>();
    final visited = <Point>{};
    final parentMap = <Point, Point>{};

    queue.add(start);
    visited.add(start);

    final blocked = <Point>{}
      ..addAll(bodySet)
      ..addAll(obstacles);

    blocked.remove(body.tail);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();

      if (current == target) {
        break;
      }

      final neighbors = <Point>[
        Point(current.x, current.y - 1),
        Point(current.x, current.y + 1),
        Point(current.x - 1, current.y),
        Point(current.x + 1, current.y),
      ];

      for (final next in neighbors) {
        if (next.x < 0 ||
            next.x >= gridWidth ||
            next.y < 0 ||
            next.y >= gridHeight) {
          continue;
        }

        if (blocked.contains(next)) {
          continue;
        }

        if (visited.contains(next)) {
          continue;
        }

        visited.add(next);
        parentMap[next] = current;
        queue.add(next);
      }
    }

    if (!parentMap.containsKey(target)) {
      return null;
    }

    Point current = target;

    while (parentMap[current] != start) {
      current = parentMap[current]!;
    }

    if (current.x > start.x) {
      return Direction.right;
    }

    if (current.x < start.x) {
      return Direction.left;
    }

    if (current.y > start.y) {
      return Direction.down;
    }

    if (current.y < start.y) {
      return Direction.up;
    }

    return null;
  }

  bool _isOpposite(Direction d1, Direction d2) {
    return (d1 == Direction.up && d2 == Direction.down) ||
        (d1 == Direction.down && d2 == Direction.up) ||
        (d1 == Direction.left && d2 == Direction.right) ||
        (d1 == Direction.right && d2 == Direction.left);
  }
}
