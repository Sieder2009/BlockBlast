import 'dart:math';
import 'package:flutter/material.dart';

/// A piece shape as a list of [row, col] offsets from its own
/// top-left bounding box. Pieces are dealt already "rotated" —
/// the player never rotates them, matching the original game.
const List<List<List<int>>> kShapes = [
  [
    [0, 0],
  ],
  [
    [0, 0],
    [0, 1],
  ],
  [
    [0, 0],
    [1, 0],
  ],
  [
    [0, 0],
    [0, 1],
    [0, 2],
  ],
  [
    [0, 0],
    [1, 0],
    [2, 0],
  ],
  [
    [0, 0],
    [0, 1],
    [0, 2],
    [0, 3],
  ],
  [
    [0, 0],
    [1, 0],
    [2, 0],
    [3, 0],
  ],
  [
    [0, 0],
    [0, 1],
    [0, 2],
    [0, 3],
    [0, 4],
  ],
  [
    [0, 0],
    [1, 0],
    [2, 0],
    [3, 0],
    [4, 0],
  ],
  [
    [0, 0],
    [0, 1],
    [1, 0],
    [1, 1],
  ],
  [
    [0, 0],
    [1, 0],
    [1, 1],
  ],
  [
    [0, 0],
    [0, 1],
    [1, 0],
  ],
  [
    [0, 0],
    [0, 1],
    [1, 1],
  ],
  [
    [1, 0],
    [1, 1],
    [0, 1],
  ],
  [
    [0, 0],
    [0, 1],
    [0, 2],
    [1, 1],
  ],
  [
    [1, 0],
    [1, 1],
    [1, 2],
    [0, 1],
  ],
  [
    [0, 0],
    [1, 0],
    [2, 0],
    [1, 1],
  ],
  [
    [0, 1],
    [1, 1],
    [2, 1],
    [1, 0],
  ],
  [
    [0, 1],
    [0, 2],
    [1, 0],
    [1, 1],
  ],
  [
    [0, 0],
    [1, 0],
    [1, 1],
    [2, 1],
  ],
  [
    [0, 0],
    [0, 1],
    [1, 1],
    [1, 2],
  ],
  [
    [0, 1],
    [1, 0],
    [1, 1],
    [2, 0],
  ],
  [
    [0, 0],
    [1, 0],
    [2, 0],
    [2, 1],
  ],
  [
    [0, 0],
    [0, 1],
    [0, 2],
    [1, 0],
  ],
  [
    [0, 0],
    [0, 1],
    [1, 1],
    [2, 1],
  ],
  [
    [1, 0],
    [1, 1],
    [1, 2],
    [0, 2],
  ],
  [
    [0, 1],
    [1, 1],
    [2, 1],
    [2, 0],
  ],
  [
    [0, 0],
    [0, 1],
    [0, 2],
    [1, 2],
  ],
  [
    [0, 0],
    [1, 0],
    [2, 0],
    [0, 1],
  ],
  [
    [0, 0],
    [1, 0],
    [1, 1],
    [1, 2],
  ],
  [
    [0, 1],
    [1, 0],
    [1, 1],
    [1, 2],
    [2, 1],
  ],
  [
    [0, 0],
    [0, 1],
    [1, 0],
    [1, 1],
    [2, 0],
  ],
  [
    [0, 0],
    [0, 1],
    [1, 0],
    [1, 1],
    [2, 1],
  ],
  [
    [0, 0],
    [1, 0],
    [1, 1],
    [2, 0],
    [2, 1],
  ],
  [
    [0, 1],
    [1, 0],
    [1, 1],
    [2, 0],
    [2, 1],
  ],
  [
    [0, 0],
    [1, 0],
    [2, 0],
    [2, 1],
    [2, 2],
  ],
  [
    [0, 0],
    [0, 1],
    [0, 2],
    [1, 0],
    [2, 0],
  ],
];

/// Own flat colour palette used to recolour the pieces — not a copy of
/// any particular app's visual design.
const List<Color> kPieceColors = [
  Color(0xFFFF6B6B),
  Color(0xFFFFD166),
  Color(0xFF4FD67E),
  Color(0xFF4DD0E1),
  Color(0xFF5B8CFF),
  Color(0xFFB98CFF),
  Color(0xFFFF8FC7),
  Color(0xFFFFA552),
];

class AppColors {
  static const bg = Color(0xFF1B1F2A);
  static const panel = Color(0xFF242A38);
  static const cellEmpty = Color(0xFF2F3648);
  static const text = Color(0xFFEEF1F8);
  static const textDim = Color(0xFF9AA3B8);
  static const accent = Color(0xFF5B8CFF);
  static const danger = Color(0xFFFF5B6E);
  static const good = Color(0xFF4FD67E);
}

class PieceShape {
  final List<List<int>> cells;
  const PieceShape(this.cells);

  int get rows => cells.map((c) => c[0]).reduce(max) + 1;
  int get cols => cells.map((c) => c[1]).reduce(max) + 1;
}

class TrayPiece {
  final int shapeIndex;
  final int colorIndex;
  const TrayPiece({required this.shapeIndex, required this.colorIndex});

  PieceShape get shape => PieceShape(kShapes[shapeIndex]);
  Color get color => kPieceColors[colorIndex];
}

final Random _rng = Random();

TrayPiece randomPiece() => TrayPiece(
      shapeIndex: _rng.nextInt(kShapes.length),
      colorIndex: _rng.nextInt(kPieceColors.length),
    );

/// Index of [color] within [kPieceColors], used to serialise board cells.
int colorIndexOf(Color color) => kPieceColors.indexOf(color);
