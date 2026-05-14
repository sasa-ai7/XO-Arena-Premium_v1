import 'dart:math';

import 'package:flutter/material.dart';

enum PlayerSymbol { x, o }

enum GameMode { ai, friend, coinMatch, levelGame }

enum AIDifficulty { easy, medium, hard }

const List<int> kStandardBoardSizes = [3, 4, 5];

class MatchBoardConfig {
  final int boardSize;
  final int winLength;

  const MatchBoardConfig({
    required this.boardSize,
    required this.winLength,
  });

  int get cellCount => boardSize * boardSize;
  String get label => '$boardSize×$boardSize';
}

MatchBoardConfig standardBoardConfig(int boardSize) {
  switch (boardSize) {
    case 4:
      return const MatchBoardConfig(boardSize: 4, winLength: 4);
    case 5:
      return const MatchBoardConfig(boardSize: 5, winLength: 5);
    case 3:
    default:
      return const MatchBoardConfig(boardSize: 3, winLength: 3);
  }
}

List<List<int>> generateWinningLines({
  required int boardSize,
  required int winLength,
}) {
  final lines = <List<int>>[];
  for (int row = 0; row < boardSize; row++) {
    for (int col = 0; col <= boardSize - winLength; col++) {
      lines.add(List.generate(winLength, (i) => row * boardSize + col + i));
    }
  }
  for (int col = 0; col < boardSize; col++) {
    for (int row = 0; row <= boardSize - winLength; row++) {
      lines.add(
        List.generate(winLength, (i) => (row + i) * boardSize + col),
      );
    }
  }
  for (int row = 0; row <= boardSize - winLength; row++) {
    for (int col = 0; col <= boardSize - winLength; col++) {
      lines.add(
        List.generate(winLength, (i) => (row + i) * boardSize + col + i),
      );
      lines.add(
        List.generate(
          winLength,
          (i) => (row + i) * boardSize + col + winLength - 1 - i,
        ),
      );
    }
  }
  return lines;
}

List<int> preferredCenterIndices(int boardSize) {
  final midpoint = boardSize ~/ 2;
  if (boardSize.isOdd) {
    return [midpoint * boardSize + midpoint];
  }

  return [
    (midpoint - 1) * boardSize + (midpoint - 1),
    (midpoint - 1) * boardSize + midpoint,
    midpoint * boardSize + (midpoint - 1),
    midpoint * boardSize + midpoint,
  ];
}

List<int> cornerIndices(int boardSize) {
  final last = boardSize - 1;
  return [0, last, last * boardSize, last * boardSize + last];
}

List<int> perimeterEdgeIndices(int boardSize) {
  final last = boardSize - 1;
  final indices = <int>[];
  for (int col = 1; col < last; col++) {
    indices.add(col);
    indices.add(last * boardSize + col);
  }
  for (int row = 1; row < last; row++) {
    indices.add(row * boardSize);
    indices.add(row * boardSize + last);
  }
  return indices;
}

double matchBoardMaxExtent(int boardSize) {
  return boardSize >= 5
      ? 480.0
      : boardSize == 4
          ? 520.0
          : 560.0;
}

double matchBoardViewportSize(
  BuildContext context,
  int boardSize, {
  double? availableWidth,
  double? availableHeight,
}) {
  final screenWidth = availableWidth ?? MediaQuery.sizeOf(context).width;
  final widthFactor = boardSize >= 5
      ? 0.92
      : boardSize == 4
          ? 0.88
          : 0.82;
  var viewport = min(screenWidth * widthFactor, matchBoardMaxExtent(boardSize));
  if (availableHeight != null) {
    viewport = min(viewport, availableHeight);
  }
  return max(0.0, viewport);
}

double matchBoardViewportSizeForBounds({
  required int boardSize,
  required double maxWidth,
  required double maxHeight,
}) {
  return min(
    min(max(0.0, maxWidth), max(0.0, maxHeight)),
    matchBoardMaxExtent(boardSize),
  );
}

double matchBoardSpacing(int boardSize) {
  if (boardSize >= 5) return 6;
  if (boardSize == 4) return 8;
  return 10;
}

double matchBoardPadding(int boardSize) {
  if (boardSize >= 5) return 10;
  if (boardSize == 4) return 12;
  return 14;
}

double matchBoardCellRadius(int boardSize) {
  if (boardSize >= 5) return 14;
  if (boardSize == 4) return 16;
  return 18;
}
