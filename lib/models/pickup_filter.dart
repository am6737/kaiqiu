enum PickupDateRange { all, today, tomorrow, thisWeek }
enum PickupLevel { all, beginner, intermediate, advanced }
enum PickupSort { time, distance }

class PickupFilter {
  final PickupSort sortBy;
  final PickupDateRange dateRange;
  final PickupLevel level;

  const PickupFilter({
    this.sortBy = PickupSort.time,
    this.dateRange = PickupDateRange.all,
    this.level = PickupLevel.all,
  });

  PickupFilter copyWith({
    PickupSort? sortBy,
    PickupDateRange? dateRange,
    PickupLevel? level,
  }) =>
      PickupFilter(
        sortBy: sortBy ?? this.sortBy,
        dateRange: dateRange ?? this.dateRange,
        level: level ?? this.level,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PickupFilter &&
          sortBy == other.sortBy &&
          dateRange == other.dateRange &&
          level == other.level;

  @override
  int get hashCode => Object.hash(sortBy, dateRange, level);
}
