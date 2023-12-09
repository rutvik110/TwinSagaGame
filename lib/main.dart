import 'dart:async';
import 'dart:async' as async;
import 'dart:developer';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(GameWidget(game: MyGame()));
}

class MyGame extends FlameGame with HasCollisionDetection, KeyboardEvents, HasKeyboardHandlerComponents {
  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  // TODO: implement debugMode
  bool get debugMode => true;

  final player = PlayerComponent();
  final screenhitbox = ScreenHitbox();

  async.Timer timer = async.Timer(Duration.zero, () {});

  @override
  Future<void> onLoad() async {
    addAll([
      player,
      GamePlatform(
        size: defaultPlatformSize,
        position: Vector2(size.x / 2 - defaultPlatformSize.x / 2, size.y - 200),
        isHot: false,
      ),
      GamePlatform(
        size: Vector2(size.x, 25),
        position: Vector2(0, size.y - 25),
      ),
    ]);
    return super.onLoad();
  }

  @override
  KeyEventResult onKeyEvent(
    RawKeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (keysPressed.contains(LogicalKeyboardKey.enter) || keysPressed.contains(LogicalKeyboardKey.space)) {
      player.jump();
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (event is RawKeyUpEvent) {
        player.runningState = RunningState.waiting;
      } else {
        player.runningState = RunningState.runningLeft;
        player.direction = Direction.left;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (event is RawKeyUpEvent) {
        player.runningState = RunningState.waiting;
      } else {
        player.runningState = RunningState.runningRight;
        player.direction = Direction.right;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (event is RawKeyDownEvent) {
        player.direction = Direction.top;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (event is RawKeyDownEvent) {
        player.direction = Direction.bottom;
      }
    }

    if (keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
        keysPressed.contains(LogicalKeyboardKey.shiftRight) ||
        event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight) {
      if (event is RawKeyUpEvent && !event.isShiftPressed) {
        if (!timer.isActive) {
          add(
            Bullet(
              position: player.center - Vector2(12.5, 12.5),
              direction: player.direction,
              isHot: player.isOnHotPlatform,
              fireAngle: player.direction.angleInRadians,
            ),
          );
          timer = async.Timer(const Duration(milliseconds: 300), () {});
        }
      }
    }

    return KeyEventResult.handled;
  }
}

class GamePlatform extends RectangleComponent with HasGameReference<MyGame>, CollisionCallbacks {
  GamePlatform({
    required Vector2 position,
    required Vector2 size,
    this.isHot = true,
  }) : super(
          size: size,
          position: position,
        );
  final bool isHot;

  @override
  FutureOr<void> onLoad() {
    paint = Paint()..color = isHot ? Colors.red : Colors.blue;

    add(RectangleHitbox());

    game.add(
      Enemy(
        isOnHotPlatform: isHot,
        platform: this,
      ),
    );
    return super.onLoad();
  }
}

class Bullet extends CircleComponent with HasGameReference<MyGame>, CollisionCallbacks {
  Bullet({
    required this.direction,
    required this.isHot,
    required this.fireAngle,
    Vector2? position,
  }) : super(
          position: position ?? Vector2(0, 0),
        );

  final bool isHot;
  final Direction direction;
  final double fireAngle;

  @override
  Future<void> onLoad() {
    size = Vector2(25, 25);
    paint = Paint()..color = isHot ? Colors.red : Colors.blue;

    add(CircleHitbox());
    return super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final radius = dt * 500;

    final angle = fireAngle;

    // if (angle != null) {
    x += radius * cos(angle);
    y += radius * sin(angle);
    // } else {
    //   x += radius * (direction == Direction.right ? 1 : -1);
    // }

    if (x < 0 || x > game.size.x || y < 0 || y > game.size.y) {
      removeFromParent();
    }
  }
}

class PlayerComponent extends RectangleComponent with HasGameReference<MyGame>, CollisionCallbacks {
  PlayerComponent() : super(priority: 1);

  final double gravity = 1;

  final double initialJumpVelocity = -15.0;
  final double introDuration = 1500.0;
  final double startXPosition = 50;
  final double currentSpeed = 300;

  double jumpVelocity = 0.0;

  PlayerState current = PlayerState.waiting;
  RunningState runningState = RunningState.waiting;

  late double groundYPos;

  Direction direction = Direction.right;

  bool isOnHotPlatform = true;

  @override
  FutureOr<void> onLoad() {
    size = Vector2(100, 100);

    paint = Paint()..color = const Color(0xFF00FF00);

    groundYPos = game.size.y - height;

    add(RectangleHitbox());

    return super.onLoad();
  }

  void jump() {
    if (current == PlayerState.jumping) {
      return;
    }

    current = PlayerState.jumping;
    jumpVelocity = initialJumpVelocity - 8;
  }

  void reset() {
    y = groundYPos;
    jumpVelocity = 0.0;
    current = PlayerState.waiting;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final newplacement = y + jumpVelocity;
    jumpVelocity += gravity;

    if (newplacement < groundYPos) {
      y = newplacement;
    } else {
      reset();
    }

    if (current == PlayerState.jumping) {
      y += jumpVelocity;
      jumpVelocity += gravity;
      if (y > groundYPos) {
        reset();
      }
    }

    if (runningState == RunningState.runningRight) {
      if (x < game.size.x - width) {
        x += dt * currentSpeed;
      }
    }

    if (runningState == RunningState.runningLeft) {
      if (x > 0) {
        x -= dt * currentSpeed;
      }
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is GamePlatform) {
      isOnHotPlatform = other.isHot;

      if ((position.y + height) <= (other.y + other.height)) {
        groundYPos = other.y - height;
      }
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    if (other is GamePlatform) {
      groundYPos = game.size.y - height;
    }

    super.onCollisionEnd(other);
  }
}

class Enemy extends RectangleComponent with HasGameReference<MyGame>, CollisionCallbacks {
  Enemy({
    required this.isOnHotPlatform,
    required this.platform,
  });

  Direction direction = Direction.right;

  final bool isOnHotPlatform;
  final GamePlatform platform;

  late Timer attackTimer;

  @override
  FutureOr<void> onLoad() {
    size = Vector2(50, 50);

    position = Vector2(
      platform.x + (platform.width - width) / 2,
      platform.y - height * 2,
    );

    paint = Paint()..color = isOnHotPlatform ? Colors.red : Colors.blue;

    attackTimer = Timer(
      1.5,
      repeat: true,
      onTick: () {
        final playerCenter = game.player.center;
        final bulletdirection = playerCenter - center;

        var angle = atan2(bulletdirection.y, bulletdirection.x);

        if (angle < 0) {
          angle += 2 * pi;
        }

        final bullet = Bullet(
          direction: direction,
          isHot: isOnHotPlatform,
          position: position,
          fireAngle: angle,
        );

        game.add(bullet);
      },
    );

    attackTimer.start();

    add(RectangleHitbox());

    return super.onLoad();
  }

  @override
  void update(double dt) {
    attackTimer.update(dt);
    super.update(dt);
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is Bullet) {
      if (other.isHot != isOnHotPlatform) {
        removeFromParent();
      }
    }
    super.onCollisionStart(intersectionPoints, other);
  }
}

enum Direction {
  left,
  right,
  top,
  bottom;

  double get angleInRadians {
    switch (this) {
      case Direction.right:
        return 0;
      case Direction.bottom:
        return pi / 2;
      case Direction.left:
        return pi;
      case Direction.top:
        return 3 * pi / 2;
    }
  }
}

enum PlayerState { crashed, jumping, running, waiting }

enum RunningState { waiting, runningLeft, runningRight }

final defaultPlatformSize = Vector2(200, 30);

const degree = pi / 180;
