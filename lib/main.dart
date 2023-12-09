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
  final player = PlayerComponent();
  final screenhitbox = ScreenHitbox();

  @override
  Future<void> onLoad() async {
    add(player);
    add(screenhitbox);
    return super.onLoad();
  }

  @override
  KeyEventResult onKeyEvent(
    RawKeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is RawKeyUpEvent) {
      // let it jump untill jumpvelocity is zero
      if (player.jumpVelocity != 0) {
        player.current = PlayerState.jumping;
      } else {
        player.current = PlayerState.waiting;
        player.runningState = RunningState.waiting;
      }

      return KeyEventResult.handled;
    }

    if (keysPressed.contains(LogicalKeyboardKey.enter) || keysPressed.contains(LogicalKeyboardKey.space)) {
      player.jump(0);
    }

    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
      player.runningState = RunningState.runningLeft;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
      player.runningState = RunningState.runningRight;
    }

    return KeyEventResult.handled;
  }
}

class PlayerComponent extends RectangleComponent with HasGameReference<MyGame>, CollisionCallbacks {
  PlayerComponent() : super(priority: 1);

  final double gravity = 1;

  final double initialJumpVelocity = -15.0;
  final double introDuration = 1500.0;
  final double startXPosition = 50;

  double jumpVelocity = 0.0;

  PlayerState current = PlayerState.waiting;
  RunningState runningState = RunningState.waiting;

  double get groundYPos {
    return game.size.y - height;
  }

  @override
  FutureOr<void> onLoad() {
    size = Vector2(100, 100);

    paint = Paint()..color = const Color(0xFF00FF00);

    return super.onLoad();
  }

  void jump(double speed) {
    if (current == PlayerState.jumping) {
      return;
    }

    current = PlayerState.jumping;
    jumpVelocity = initialJumpVelocity - (speed / 500);
  }

  void reset() {
    y = groundYPos;
    jumpVelocity = 0.0;
    current = PlayerState.waiting;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (current == PlayerState.jumping) {
      y += jumpVelocity;
      jumpVelocity += gravity;

      if (y > groundYPos) {
        reset();
      }
    } else {
      y = groundYPos;
    }

    if (runningState == RunningState.runningRight) {
      if (x < game.size.x - width) {
        x += (startXPosition / introDuration) * dt * 5000;
      }
    }

    if (runningState == RunningState.runningLeft) {
      if (x > 0) {
        x -= (startXPosition / introDuration) * dt * 5000;
      }
    }
  }
}
