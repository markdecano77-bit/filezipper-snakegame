import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/point.dart';
import 'services/snake_game_logic.dart';

class SnakeScreen extends StatefulWidget {
  const SnakeScreen({super.key});

  @override
  State<SnakeScreen> createState() => _SnakeScreenState();
}

class _SnakeScreenState extends State<SnakeScreen> {
  final SnakeGameLogic _game = SnakeGameLogic();

  Timer? _timer;

  final FocusNode _focusNode = FocusNode();

  Offset? _touchStart;

  @override
  void initState() {
    super.initState();

    _game.reset();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(Duration(milliseconds: _game.timerMilliseconds), (
      _,
    ) {
      if (!mounted) return;

      setState(() {
        _game.tick();
      });

      _restartTimerIfSpeedChanged();
    });
  }

  int _lastTimerSpeed = 180;

  void _restartTimerIfSpeedChanged() {
    if (_lastTimerSpeed == _game.timerMilliseconds) {
      return;
    }

    _lastTimerSpeed = _game.timerMilliseconds;

    _timer?.cancel();

    _timer = Timer.periodic(Duration(milliseconds: _game.timerMilliseconds), (
      _,
    ) {
      if (!mounted) return;

      setState(() {
        _game.tick();
      });

      _restartTimerIfSpeedChanged();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    super.dispose();
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return;
    }

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      _game.handleInput(Direction.up);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      _game.handleInput(Direction.down);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.keyA) {
      _game.handleInput(Direction.left);
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      _game.handleInput(Direction.right);
    } else if (key == LogicalKeyboardKey.space) {
      setState(() {
        _game.togglePause();
      });
    }
  }

  void _onPanStart(DragStartDetails details) {
    _touchStart = details.localPosition;
  }

  void _onPanEnd(DragEndDetails details) {
    if (_touchStart == null) {
      return;
    }

    final velocity = details.velocity.pixelsPerSecond;

    if (velocity.distance < 100) {
      _touchStart = null;
      return;
    }

    if (velocity.dx.abs() > velocity.dy.abs()) {
      if (velocity.dx > 0) {
        _game.handleInput(Direction.right);
      } else {
        _game.handleInput(Direction.left);
      }
    } else {
      if (velocity.dy > 0) {
        _game.handleInput(Direction.down);
      } else {
        _game.handleInput(Direction.up);
      }
    }

    _touchStart = null;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF101010),
        appBar: AppBar(
          title: const Text(
            'Snake',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings),
              onPressed: _showSettings,
            ),
            IconButton(
              tooltip: 'Leaderboard',
              icon: const Icon(Icons.leaderboard),
              onPressed: _showLeaderboard,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopInformation(),

              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio:
                        SnakeGameLogic.gridWidth / SnakeGameLogic.gridHeight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: GestureDetector(
                        onPanStart: _onPanStart,
                        onPanEnd: _onPanEnd,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildGameBoard(),

                            if (_game.isPaused && !_game.isGameOver)
                              _buildPauseOverlay(),

                            if (_game.isGameOver) _buildGameOverOverlay(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              _buildBottomInformation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopInformation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Score: ${_game.score}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          Text(
            'High Score: ${_game.highScore}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          Text(
            _game.isAiMode ? 'BFS AI' : _game.modeName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          if (_game.mode == SnakeMode.adventure)
            Text(
              'Level ${_game.level}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

          IconButton(
            icon: Icon(_game.isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: () {
              setState(() {
                _game.togglePause();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGameBoard() {
    return CustomPaint(
      painter: SnakeBoardPainter(
        body: _game.body.toList(),
        food: _game.food,
        obstacles: _game.obstacles,
        direction: _game.currentDirection,
        gridWidth: SnakeGameLogic.gridWidth,
        gridHeight: SnakeGameLogic.gridHeight,
      ),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildBottomInformation() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Speed: ${_game.speedName}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),

          Text(
            'Swipe or use WASD / Arrow Keys',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),

          IconButton(
            tooltip: 'BFS Auto Play',
            icon: Icon(
              _game.isAiMode ? Icons.smart_toy : Icons.smart_toy_outlined,
            ),
            onPressed: () {
              setState(() {
                _game.isAiMode = !_game.isAiMode;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.70),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PAUSED',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 15),

            ElevatedButton(
              onPressed: () {
                setState(() {
                  _game.togglePause();
                });
              },
              child: const Text('Resume'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.78),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'GAME OVER',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Score: ${_game.score}',
              style: const TextStyle(fontSize: 20, color: Colors.white),
            ),

            const SizedBox(height: 15),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _game.reset();
                    });
                  },
                  child: const Text('Restart'),
                ),

                const SizedBox(width: 10),

                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) {
        SnakeMode selectedMode = _game.mode;
        SnakeSpeed selectedSpeed = _game.speed;
        bool selectedAi = _game.isAiMode;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Snake Settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Game Mode',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),

                    RadioListTile<SnakeMode>(
                      title: const Text('Classic'),
                      value: SnakeMode.classic,
                      groupValue: selectedMode,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedMode = value!;
                        });
                      },
                    ),

                    RadioListTile<SnakeMode>(
                      title: const Text('Adventure'),
                      subtitle: const Text('Levels and obstacles'),
                      value: SnakeMode.adventure,
                      groupValue: selectedMode,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedMode = value!;
                        });
                      },
                    ),

                    const Divider(),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Speed',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),

                    RadioListTile<SnakeSpeed>(
                      title: const Text('Slow'),
                      value: SnakeSpeed.slow,
                      groupValue: selectedSpeed,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedSpeed = value!;
                        });
                      },
                    ),

                    RadioListTile<SnakeSpeed>(
                      title: const Text('Fast'),
                      value: SnakeSpeed.fast,
                      groupValue: selectedSpeed,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedSpeed = value!;
                        });
                      },
                    ),

                    RadioListTile<SnakeSpeed>(
                      title: const Text('Very Fast'),
                      value: SnakeSpeed.veryFast,
                      groupValue: selectedSpeed,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedSpeed = value!;
                        });
                      },
                    ),

                    RadioListTile<SnakeSpeed>(
                      title: const Text('Challenge'),
                      subtitle: const Text(
                        'Gets faster as your score increases',
                      ),
                      value: SnakeSpeed.challenge,
                      groupValue: selectedSpeed,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedSpeed = value!;
                        });
                      },
                    ),

                    const Divider(),

                    SwitchListTile(
                      title: const Text('BFS Auto-Play'),
                      value: selectedAi,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedAi = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _game.mode = selectedMode;
                      _game.speed = selectedSpeed;
                      _game.isAiMode = selectedAi;
                      _game.reset();
                    });

                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLeaderboard() {
    showDialog(
      context: context,
      builder: (context) {
        final scores = List<int>.from(_game.leaderboard);

        return AlertDialog(
          title: const Text('Leaderboard'),
          content: SizedBox(
            width: 300,
            child: scores.isEmpty
                ? const Text('No scores yet.', textAlign: TextAlign.center)
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: scores.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text('${scores[index]} points'),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class SnakeBoardPainter extends CustomPainter {
  final List<Point> body;
  final Point food;
  final Set<Point> obstacles;
  final Direction direction;

  final int gridWidth;
  final int gridHeight;

  SnakeBoardPainter({
    required this.body,
    required this.food,
    required this.obstacles,
    required this.direction,
    required this.gridWidth,
    required this.gridHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / gridWidth;
    final cellHeight = size.height / gridHeight;

    // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF151515),
    );

    final gridPaint = Paint()
      ..color = const Color(0xFF303030)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    for (int x = 0; x <= gridWidth; x++) {
      final dx = x * cellWidth;

      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
    }

    for (int y = 0; y <= gridHeight; y++) {
      final dy = y * cellHeight;

      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    final obstaclePaint = Paint()..color = const Color(0xFF666666);

    for (final obstacle in obstacles) {
      final rect = Rect.fromLTWH(
        obstacle.x * cellWidth + 1,
        obstacle.y * cellHeight + 1,
        cellWidth - 2,
        cellHeight - 2,
      );

      canvas.drawRect(rect, obstaclePaint);
    }

    final foodCenter = Offset(
      food.x * cellWidth + cellWidth / 2,
      food.y * cellHeight + cellHeight / 2,
    );

    final foodPaint = Paint()..color = Colors.red;

    canvas.drawCircle(
      foodCenter,
      math.min(cellWidth, cellHeight) * 0.35,
      foodPaint,
    );

    for (int i = body.length - 1; i >= 0; i--) {
      final part = body[i];

      final isHead = i == 0;

      final rect = Rect.fromLTWH(
        part.x * cellWidth + 1.5,
        part.y * cellHeight + 1.5,
        cellWidth - 3,
        cellHeight - 3,
      );

      final paint = Paint()
        ..color = isHead ? const Color(0xFF168A3A) : const Color(0xFF35B957);

      // Square body blocks
      canvas.drawRect(rect, paint);

      // Head eyes
      if (isHead) {
        _drawEyes(canvas, rect);
      }
    }
  }

  void _drawEyes(Canvas canvas, Rect rect) {
    final eyePaint = Paint()..color = Colors.white;

    final pupilPaint = Paint()..color = Colors.black;

    final eyeRadius = math.min(rect.width, rect.height) * 0.14;

    final pupilRadius = eyeRadius * 0.48;

    Offset eye1;
    Offset eye2;

    switch (direction) {
      case Direction.up:
        eye1 = Offset(
          rect.left + rect.width * 0.35,
          rect.top + rect.height * 0.25,
        );

        eye2 = Offset(
          rect.left + rect.width * 0.65,
          rect.top + rect.height * 0.25,
        );
        break;

      case Direction.down:
        eye1 = Offset(
          rect.left + rect.width * 0.35,
          rect.bottom - rect.height * 0.25,
        );

        eye2 = Offset(
          rect.left + rect.width * 0.65,
          rect.bottom - rect.height * 0.25,
        );
        break;

      case Direction.left:
        eye1 = Offset(
          rect.left + rect.width * 0.25,
          rect.top + rect.height * 0.35,
        );

        eye2 = Offset(
          rect.left + rect.width * 0.25,
          rect.top + rect.height * 0.65,
        );
        break;

      case Direction.right:
        eye1 = Offset(
          rect.right - rect.width * 0.25,
          rect.top + rect.height * 0.35,
        );

        eye2 = Offset(
          rect.right - rect.width * 0.25,
          rect.top + rect.height * 0.65,
        );
        break;
    }

    canvas.drawCircle(eye1, eyeRadius, eyePaint);

    canvas.drawCircle(eye2, eyeRadius, eyePaint);

    canvas.drawCircle(eye1, pupilRadius, pupilPaint);

    canvas.drawCircle(eye2, pupilRadius, pupilPaint);
  }

  @override
  bool shouldRepaint(covariant SnakeBoardPainter oldDelegate) {
    return true;
  }
}
