class LiveConnectFilter {
  // Discovery mode toggle
  bool discoveryModeEnabled;

  // Interest filters
  Set<String> selectedInterests;

  // Location filters
  double maxDistance; // in km
  String locationType; // 'near_me', 'city', 'country', 'worldwide'

  // Connection type filters
  Set<String> connectionTypes;

  LiveConnectFilter({
    this.discoveryModeEnabled = true,
    Set<String>? selectedInterests,
    this.maxDistance = 50.0,
    this.locationType = 'city',
    Set<String>? connectionTypes,
  })  : selectedInterests = selectedInterests ?? {},
        connectionTypes = connectionTypes ?? {};

  // Available connection types
  static const List<String> availableConnectionTypes = [
    'Professional Networking',
    'Activity Partner',
    'Event Companion',
    'Friendship',
    'Dating',
  ];

  // Available location types
  static const Map<String, String> locationTypes = {
    'near_me': 'Near me',
    'city': 'City',
    'country': 'Country',
    'worldwide': 'Worldwide',
  };

  LiveConnectFilter copyWith({
    bool? discoveryModeEnabled,
    Set<String>? selectedInterests,
    double? maxDistance,
    String? locationType,
    Set<String>? connectionTypes,
  }) {
    return LiveConnectFilter(
      discoveryModeEnabled: discoveryModeEnabled ?? this.discoveryModeEnabled,
      selectedInterests: selectedInterests ?? this.selectedInterests,
      maxDistance: maxDistance ?? this.maxDistance,
      locationType: locationType ?? this.locationType,
      connectionTypes: connectionTypes ?? this.connectionTypes,
    );
  }

  bool get hasActiveFilters {
    return selectedInterests.isNotEmpty ||
        maxDistance < 100 ||
        connectionTypes.isNotEmpty;
  }

  int get activeFilterCount {
    int count = 0;
    if (selectedInterests.isNotEmpty) count++;
    if (maxDistance < 100) count++;
    if (connectionTypes.isNotEmpty) count++;
    return count;
  }

  void reset() {
    selectedInterests.clear();
    maxDistance = 50.0;
    locationType = 'city';
    connectionTypes.clear();
  }
}
