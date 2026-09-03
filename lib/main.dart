import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shapes.dart';

void main() => runApp(const BlockBlastApp());

class BlockBlastApp extends StatelessWidget {
  const BlockBlastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Block Blast Klon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: AppColors.bg,
      ),
      home: const GameScreen(),
    );
  }
}

const int kBoardSize = 8;
const double kCellSize = 38;
const double kCellGap = 4;
const double kBoardPadding = 8;
const double kBoardStep = kCellSize + kCellGap;
const double kBoardInnerSize =
    kBoardSize * kCellSize + (kBoardSize - 1) * kCellGap;
const double kBoardOuterSize = kBoardInnerSize + kBoardPadding * 2;
const String kBestScoreKey = 'bb_best';
const String kSavedGameKey = 'bb_saved_game';

class _ScorePopup {
  final int id;
  final String text;
  final Color color;
  _ScorePopup(this.id, this.text, this.color);
}

class _DragState {
  final int slot;
  final TrayPiece piece;
  double ghostLeft = 0;
  double ghostTop = 0;
  int? anchorRow;
  int? anchorCol;
  bool valid = false;
  Set<String> previewCells = {};
  Set<String> lineClearCells = {};

  _DragState(this.slot, this.piece);
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _boardKey = GlobalKey();

  late List<List<Color?>> board;
  late List<TrayPiece?> tray;
  int score = 0;
  int best = 0;
  int combo = 0;
  bool gameOver = false;
  bool newBest = false;
  Set<String> clearingCells = {};
  _DragState? drag;
  final List<_ScorePopup> _popups = [];
  int _popupSeq = 0;

  @override
  void initState() {
    super.initState();
    board = List.generate(kBoardSize, (_) => List<Color?>.filled(kBoardSize, null));
    tray = _dealTray();
    _loadBest();
    _loadSavedGame();
  }

  /// Deals 3 random pieces, but guarantees at least one of them has a
  /// legal placement on the current board so a nearly-full board can't
  /// hand the player an instantly unwinnable tray.
  List<TrayPiece?> _dealTray() {
    final pieces = List.generate(3, (_) => randomPiece());
    final boardEmpty = board.every((row) => row.every((cell) => cell == null));
    if (boardEmpty || pieces.any((p) => _anyPlacementExists(p.shape))) {
      return pieces;
    }
    for (int attempt = 0; attempt < 40; attempt++) {
      final candidate = randomPiece();
      if (_anyPlacementExists(candidate.shape)) {
        pieces[0] = candidate;
        return pieces;
      }
    }
    return pieces;
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => best = prefs.getInt(kBestScoreKey) ?? 0);
  }

  Future<void> _saveBest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kBestScoreKey, best);
  }

  /// Resumes an in-progress game (board, tray, score) after a restart.
  Future<void> _loadSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kSavedGameKey);
    if (raw == null || !mounted) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final savedBoard = (data['board'] as List)
          .map((row) => (row as List)
              .map((v) => v == -1 ? null : kPieceColors[v as int])
              .toList())
          .toList();
      final savedTray = (data['tray'] as List)
          .map((t) => t == null
              ? null
              : TrayPiece(
                  shapeIndex: (t as Map<String, dynamic>)['shapeIndex'] as int,
                  colorIndex: t['colorIndex'] as int,
                ))
          .toList();
      setState(() {
        board = List<List<Color?>>.from(savedBoard.map((r) => List<Color?>.from(r)));
        tray = List<TrayPiece?>.from(savedTray);
        score = data['score'] as int;
      });
    } catch (_) {
      // Corrupted or outdated save — keep the freshly dealt game instead.
    }
  }

  Future<void> _saveGame() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'board': board.map((row) => row.map((c) => c == null ? -1 : colorIndexOf(c)).toList()).toList(),
      'tray': tray
          .map((p) => p == null ? null : {'shapeIndex': p.shapeIndex, 'colorIndex': p.colorIndex})
          .toList(),
      'score': score,
    };
    await prefs.setString(kSavedGameKey, jsonEncode(data));
  }

  Future<void> _clearSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kSavedGameKey);
  }

  void _spawnPopup(String text, Color color) {
    setState(() => _popups.add(_ScorePopup(_popupSeq++, text, color)));
  }

  void _grantScore(int n) {
    score += n;
    if (score > best) {
      best = score;
      _saveBest();
    }
  }

  bool _canPlace(PieceShape shape, int anchorRow, int anchorCol) {
    for (final cell in shape.cells) {
      final r = anchorRow + cell[0];
      final c = anchorCol + cell[1];
      if (r < 0 || r >= kBoardSize || c < 0 || c >= kBoardSize) return false;
      if (board[r][c] != null) return false;
    }
    return true;
  }

  bool _anyPlacementExists(PieceShape shape) {
    for (int r = 0; r < kBoardSize; r++) {
      for (int c = 0; c < kBoardSize; c++) {
        if (_canPlace(shape, r, c)) return true;
      }
    }
    return false;
  }

  void _checkGameOver() {
    final active = tray.whereType<TrayPiece>().toList();
    final stuck = active.every((p) => !_anyPlacementExists(p.shape));
    if (!stuck) return;
    final isNew = score > best;
    if (isNew) {
      best = score;
      _saveBest();
    }
    setState(() {
      gameOver = true;
      newBest = isNew;
    });
  }

  void _afterMove() {
    if (tray.every((p) => p == null)) {
      setState(() => tray = _dealTray());
    }
    _checkGameOver();
    if (gameOver) {
      _clearSavedGame();
    } else {
      _saveGame();
    }
  }

  void _placePiece(int slot, TrayPiece piece, int anchorRow, int anchorCol) {
    HapticFeedback.mediumImpact();
    for (final cell in piece.shape.cells) {
      board[anchorRow + cell[0]][anchorCol + cell[1]] = piece.color;
    }
    tray[slot] = null;
    setState(() => _grantScore(piece.shape.cells.length));
    _clearFullLines();
  }

  void _clearFullLines() {
    final fullRows = <int>[];
    final fullCols = <int>[];
    for (int r = 0; r < kBoardSize; r++) {
      if (board[r].every((v) => v != null)) fullRows.add(r);
    }
    for (int c = 0; c < kBoardSize; c++) {
      if (board.every((row) => row[c] != null)) fullCols.add(c);
    }
    final lines = fullRows.length + fullCols.length;

    if (lines == 0) {
      combo = 0;
      setState(() {});
      _afterMove();
      return;
    }

    final toClear = <String>{};
    for (final r in fullRows) {
      for (int c = 0; c < kBoardSize; c++) {
        toClear.add('$r,$c');
      }
    }
    for (final c in fullCols) {
      for (int r = 0; r < kBoardSize; r++) {
        toClear.add('$r,$c');
      }
    }

    combo += 1;
    final basePoints = lines * lines * 10;
    final comboBonus = combo > 1 ? (combo - 1) * 10 : 0;
    final totalPoints = basePoints + comboBonus;

    setState(() {
      clearingCells = toClear;
      _grantScore(totalPoints);
    });
    HapticFeedback.heavyImpact();
    _spawnPopup(
      combo > 1 ? '+$totalPoints  ·  Combo x$combo' : '+$totalPoints',
      combo > 1 ? AppColors.good : AppColors.text,
    );

    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      for (final key in toClear) {
        final parts = key.split(',');
        board[int.parse(parts[0])][int.parse(parts[1])] = null;
      }
      setState(() => clearingCells = {});
      _afterMove();
    });
  }

  void _startDrag(int slot, TrayPiece piece, Offset globalPos) {
    HapticFeedback.selectionClick();
    drag = _DragState(slot, piece);
    _updateDrag(globalPos);
  }

  void _updateDrag(Offset globalPos) {
    final d = drag;
    if (d == null) return;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final boardBox = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || boardBox == null) return;

    final localInStack = stackBox.globalToLocal(globalPos);
    final ghostW = d.piece.shape.cols * kCellSize + (d.piece.shape.cols - 1) * kCellGap;
    final ghostH = d.piece.shape.rows * kCellSize + (d.piece.shape.rows - 1) * kCellGap;
    final lift = kCellSize * 1.5;

    d.ghostLeft = localInStack.dx - ghostW / 2;
    d.ghostTop = localInStack.dy - ghostH / 2 - lift;

    final boardOriginInStack = stackBox.globalToLocal(boardBox.localToGlobal(Offset.zero));
    final relX = d.ghostLeft - boardOriginInStack.dx - kBoardPadding;
    final relY = d.ghostTop - boardOriginInStack.dy - kBoardPadding;
    final col = (relX / kBoardStep).round();
    final row = (relY / kBoardStep).round();

    d.anchorRow = row;
    d.anchorCol = col;
    d.valid = _canPlace(d.piece.shape, row, col);
    d.previewCells = {
      for (final cell in d.piece.shape.cells)
        if (row + cell[0] >= 0 &&
            row + cell[0] < kBoardSize &&
            col + cell[1] >= 0 &&
            col + cell[1] < kBoardSize)
          '${row + cell[0]},${col + cell[1]}',
    };
    d.lineClearCells = d.valid ? _linesClearedBy(d.previewCells) : {};
  }

  /// Simulates dropping a piece occupying [previewCells] and returns every
  /// cell of every row/column that would become full as a result, so the
  /// board can preview a line clear before the player commits to the move.
  Set<String> _linesClearedBy(Set<String> previewCells) {
    bool occupied(int r, int c) => board[r][c] != null || previewCells.contains('$r,$c');
    final result = <String>{};
    for (int r = 0; r < kBoardSize; r++) {
      if (List.generate(kBoardSize, (c) => occupied(r, c)).every((v) => v)) {
        for (int c = 0; c < kBoardSize; c++) {
          result.add('$r,$c');
        }
      }
    }
    for (int c = 0; c < kBoardSize; c++) {
      if (List.generate(kBoardSize, (r) => occupied(r, c)).every((v) => v)) {
        for (int r = 0; r < kBoardSize; r++) {
          result.add('$r,$c');
        }
      }
    }
    return result;
  }

  void _finishDrag() {
    final d = drag;
    if (d != null && d.valid && d.anchorRow != null && d.anchorCol != null) {
      _placePiece(d.slot, d.piece, d.anchorRow!, d.anchorCol!);
    } else if (d != null) {
      HapticFeedback.heavyImpact();
    }
    setState(() => drag = null);
  }

  void _startNewGame() {
    setState(() {
      board = List.generate(kBoardSize, (_) => List<Color?>.filled(kBoardSize, null));
      tray = _dealTray();
      score = 0;
      combo = 0;
      gameOver = false;
      newBest = false;
      clearingCells = {};
      drag = null;
      _popups.clear();
    });
    _clearSavedGame();
  }

  /// Confirms with the player before discarding an in-progress game.
  Future<void> _confirmNewGame() async {
    if (gameOver || score == 0) {
      _startNewGame();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Neues Spiel?', style: TextStyle(color: AppColors.text)),
        content: const Text(
          'Dein aktueller Fortschritt geht verloren.',
          style: TextStyle(color: AppColors.textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Neu starten', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) _startNewGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          key: _stackKey,
          children: [
            Column(
              children: [
                _topBar(),
                Expanded(child: Center(child: _boardWidget())),
                _trayWidget(),
                const SizedBox(height: 8),
              ],
            ),
            if (drag != null) _ghostWidget(drag!),
            ..._popups.map(_popupWidget),
            if (gameOver) _gameOverOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          _scoreBox('Punkte', score),
          const SizedBox(width: 12),
          _scoreBox('Rekord', best),
          const Spacer(),
          IconButton(
            onPressed: _confirmNewGame,
            icon: const Icon(Icons.refresh, color: AppColors.text),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.panel,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBox(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 11, color: AppColors.textDim, letterSpacing: 0.5),
          ),
          Text(
            '$value',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text),
          ),
        ],
      ),
    );
  }

  Widget _boardWidget() {
    return Container(
      key: _boardKey,
      width: kBoardOuterSize,
      height: kBoardOuterSize,
      padding: const EdgeInsets.all(kBoardPadding),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: List.generate(
          kBoardSize,
          (r) => Row(
            children: List.generate(kBoardSize, (c) => _boardCell(r, c)),
          ),
        ),
      ),
    );
  }

  Widget _boardCell(int r, int c) {
    final key = '$r,$c';
    final isClearing = clearingCells.contains(key);
    final color = board[r][c];
    final isPreview = drag?.previewCells.contains(key) ?? false;
    final previewValid = drag?.valid ?? false;
    final willClear = previewValid && (drag?.lineClearCells.contains(key) ?? false);

    return Container(
      margin: EdgeInsets.only(
        right: c < kBoardSize - 1 ? kCellGap : 0,
        bottom: r < kBoardSize - 1 ? kCellGap : 0,
      ),
      width: kCellSize,
      height: kCellSize,
      child: AnimatedScale(
        scale: isClearing ? 0 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeIn,
        child: Container(
          decoration: BoxDecoration(
            color: willClear && !isPreview
                ? Color.alphaBlend(AppColors.good.withValues(alpha: 0.45), color ?? AppColors.cellEmpty)
                : (color ?? AppColors.cellEmpty),
            borderRadius: BorderRadius.circular(6),
            border: isPreview
                ? Border.all(color: previewValid ? AppColors.good : AppColors.danger, width: 2)
                : (willClear ? Border.all(color: AppColors.good.withValues(alpha: 0.8), width: 1.5) : null),
          ),
        ),
      ),
    );
  }

  Widget _trayWidget() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(minHeight: 110),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(3, (slot) => _traySlot(slot)),
      ),
    );
  }

  Widget _traySlot(int slot) {
    final piece = tray[slot];
    if (piece == null) {
      return const SizedBox(width: 90, height: 90);
    }
    final isDraggingThis = drag?.slot == slot;
    return Opacity(
      opacity: isDraggingThis ? 0.2 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => setState(() => _startDrag(slot, piece, d.globalPosition)),
        onPanUpdate: (d) => setState(() => _updateDrag(d.globalPosition)),
        onPanEnd: (_) => _finishDrag(),
        onPanCancel: () => setState(() => drag = null),
        child: SizedBox(
          width: 90,
          height: 90,
          child: Center(
            child: TweenAnimationBuilder<double>(
              key: ObjectKey(piece),
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: _piece(piece, cellSize: 20, gap: 3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _popupWidget(_ScorePopup p) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(p.id),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 950),
      curve: Curves.easeOut,
      onEnd: () {
        if (mounted) setState(() => _popups.removeWhere((e) => e.id == p.id));
      },
      builder: (context, t, child) {
        return Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: const Alignment(0, -0.42),
              child: Transform.translate(
                offset: Offset(0, -30 * t),
                child: Opacity(
                  opacity: 1 - t,
                  child: Text(
                    p.text,
                    style: TextStyle(
                      color: p.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _piece(TrayPiece piece, {required double cellSize, required double gap}) {
    final rows = piece.shape.rows;
    final cols = piece.shape.cols;
    final on = List.generate(rows, (_) => List<bool>.filled(cols, false));
    for (final cell in piece.shape.cells) {
      on[cell[0]][cell[1]] = true;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        rows,
        (r) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(cols, (c) {
            return Container(
              margin: EdgeInsets.only(
                right: c < cols - 1 ? gap : 0,
                bottom: r < rows - 1 ? gap : 0,
              ),
              width: cellSize,
              height: cellSize,
              decoration: on[r][c]
                  ? BoxDecoration(color: piece.color, borderRadius: BorderRadius.circular(4))
                  : null,
            );
          }),
        ),
      ),
    );
  }

  Widget _ghostWidget(_DragState d) {
    return Positioned(
      left: d.ghostLeft,
      top: d.ghostTop,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.92,
          child: _piece(d.piece, cellSize: kCellSize, gap: kCellGap),
        ),
      ),
    );
  }

  Widget _gameOverOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Spiel vorbei',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text),
                ),
                const SizedBox(height: 8),
                Text('Punkte: $score', style: const TextStyle(color: AppColors.textDim)),
                if (newBest) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Neuer Rekord!',
                    style: TextStyle(color: AppColors.good, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _startNewGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Nochmal spielen', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
