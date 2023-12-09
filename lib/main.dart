import 'dart:async';
import 'dart:developer';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum PlayerState { crashed, jumping, running, waiting }

enum RunningState { waiting, runningLeft, runningRight }

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

  @override
  Future<void> onLoad() async {
    addAll([
      player,
      screenhitbox,
      GamePlatform(),
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
      log('arrowLeft');
      if (event is RawKeyUpEvent) {
        player.runningState = RunningState.waiting;
      } else {
        player.runningState = RunningState.runningLeft;
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (event is RawKeyUpEvent) {
        player.runningState = RunningState.waiting;
      } else {
        player.runningState = RunningState.runningRight;
      }
    }

    return KeyEventResult.handled;
  }
}

class GamePlatform extends RectangleComponent with HasGameReference<MyGame>, CollisionCallbacks {
  @override
  FutureOr<void> onLoad() {
    size = Vector2(200, 25);
    paint = Paint()..color = const Color(0xFF0000FF);

    position = Vector2(game.size.x / 2 - width / 2, game.size.y - 200);

    add(RectangleHitbox());
    return super.onLoad();
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
