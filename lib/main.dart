import 'dart:async';
import 'dart:async' as async;
import 'dart:developer';

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
      //   if (event is RawKeyUpEvent) {
      //   // let it jump untill jumpvelocity is zero
      //   if (player.jumpVelocity != 0) {
      //     player.current = PlayerState.jumping;
      //   } else {
      //     player.current = PlayerState.waiting;
      //     player.runningState = RunningState.waiting;
      //   }

      //   player.runningState = RunningState.waiting;

      //   return KeyEventResult.handled;
      // }
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

    if (keysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
        keysPressed.contains(LogicalKeyboardKey.shiftRight) ||
        event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight) {
      if (event is RawKeyUpEvent && !event.isShiftPressed) {
        if (!timer.isActive) {
          add(
            Bullet(
              position: Vector2(
                player.direction == Direction.right ? player.x + player.width : player.x,
                player.y + (player.height - 25) / 2,
              ),
              direction: player.direction,
              isHot: player.isOnHotPlatform,
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
    return super.onLoad();
  }
}

class Bullet extends CircleComponent with HasGameReference<MyGame>, CollisionCallbacks {
  Bullet({
    required this.direction,
    Vector2? position,
    this.isHot = true,
  }) : super(
          position: position ?? Vector2(0, 0),
        );

  final bool isHot;
  final Direction direction;

  @override
  Future<void> onLoad() {
    size = Vector2(25, 25);
    paint = Paint()..color = isHot ? Colors.red : Colors.blue;
    return super.onLoad();
  }

  @override
  void update(double dt) {
    super.update(dt);

    x += dt * 500 * (direction == Direction.right ? 1 : -1);

    if (x < 0 || x > game.size.x) {
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

    // else {
    //   y += jumpVelocity;
    //   jumpVelocity += gravity;
    //   if ((position.y + height) >= groundYPos) {
    //     y = groundYPos;
    //   }
    // }

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

enum Direction {
  left,
  right,
  top,
  bottom;
}

enum PlayerState { crashed, jumping, running, waiting }

enum RunningState { waiting, runningLeft, runningRight }

final defaultPlatformSize = Vector2(200, 30);
