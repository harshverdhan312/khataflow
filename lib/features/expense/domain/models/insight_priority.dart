enum InsightPriority {
  high,
  medium,
  low;

  int get rank {
    switch (this) {
      case InsightPriority.high:
        return 0;
      case InsightPriority.medium:
        return 1;
      case InsightPriority.low:
        return 2;
    }
  }
}
