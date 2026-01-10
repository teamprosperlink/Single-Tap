import 'package:flutter/material.dart';

class ModernFilterSheet extends StatefulWidget {
  final String locationFilter;
  final double distanceFilter;
  final List<String> selectedGenders;
  final List<String> selectedInterests;
  final List<String> selectedConnectionTypes;
  final List<String> selectedActivities;
  final List<String> availableGenders;
  final List<String> availableInterests;
  final Map<String, List<String>> connectionTypeGroups;
  final Map<String, List<String>> activityGroups;
  final Future<bool> Function() checkLocationPermission;
  final VoidCallback onApply;

  const ModernFilterSheet({
    super.key,
    required this.locationFilter,
    required this.distanceFilter,
    required this.selectedGenders,
    required this.selectedInterests,
    required this.selectedConnectionTypes,
    required this.selectedActivities,
    required this.availableGenders,
    required this.availableInterests,
    required this.connectionTypeGroups,
    required this.activityGroups,
    required this.checkLocationPermission,
    required this.onApply,
  });

  @override
  State<ModernFilterSheet> createState() => _ModernFilterSheetState();
}

class _ModernFilterSheetState extends State<ModernFilterSheet> {
  late String _locationFilter;
  late double _distanceFilter;
  late Set<String> _selectedGenders;
  late Set<String> _selectedInterests;
  late Set<String> _selectedConnectionTypes;
  late Set<String> _selectedActivities;

  @override
  void initState() {
    super.initState();
    _locationFilter = widget.locationFilter;
    _distanceFilter = widget.distanceFilter;
    _selectedGenders = Set<String>.from(widget.selectedGenders);
    _selectedInterests = Set<String>.from(widget.selectedInterests);
    _selectedConnectionTypes = Set<String>.from(widget.selectedConnectionTypes);
    _selectedActivities = Set<String>.from(widget.selectedActivities);
  }

  int _getActiveFiltersCount() {
    int count = 0;
    if (_selectedGenders.isNotEmpty) count++;
    if (_selectedInterests.isNotEmpty) count++;
    if (_selectedConnectionTypes.isNotEmpty) count++;
    if (_selectedActivities.isNotEmpty) count++;
    if (_locationFilter != 'Worldwide') count++;
    return count;
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  void _showAllInterestsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.favorite_rounded, color: Color(0xFFFF6B6B), size: 20),
                        const SizedBox(width: 8),
                        const Text('All Interests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.availableInterests.map((interest) {
                          final isSelected = _selectedInterests.contains(interest);
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  _selectedInterests.remove(interest);
                                } else if (_selectedInterests.length < 10) {
                                  _selectedInterests.add(interest);
                                }
                              });
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFF6B6B).withValues(alpha: 0.2) : Colors.grey[850],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSelected ? const Color(0xFFFF6B6B) : Colors.grey[700]!),
                              ),
                              child: Text(
                                interest,
                                style: TextStyle(fontSize: 13, color: isSelected ? const Color(0xFFFF6B6B) : Colors.grey[400]),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAllConnectionTypesDialog() {
    final allTypes = widget.connectionTypeGroups.values.expand((e) => e).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.connect_without_contact_rounded, color: Color(0xFF9C27B0), size: 20),
                        const SizedBox(width: 8),
                        const Text('All Connection Types', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: allTypes.map((type) {
                          final isSelected = _selectedConnectionTypes.contains(type);
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  _selectedConnectionTypes.remove(type);
                                } else {
                                  _selectedConnectionTypes.add(type);
                                }
                              });
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF9C27B0).withValues(alpha: 0.2) : Colors.grey[850],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSelected ? const Color(0xFF9C27B0) : Colors.grey[700]!),
                              ),
                              child: Text(type, style: TextStyle(fontSize: 13, color: isSelected ? const Color(0xFF9C27B0) : Colors.grey[400])),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAllActivitiesDialog() {
    final allActivities = widget.activityGroups.values.expand((e) => e).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDarkMode = Theme.of(context).brightness == Brightness.dark;
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.sports_tennis_rounded, color: Color(0xFFFF9800), size: 20),
                        const SizedBox(width: 8),
                        const Text('All Activities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: allActivities.map((activity) {
                          final isSelected = _selectedActivities.contains(activity);
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  _selectedActivities.remove(activity);
                                } else {
                                  _selectedActivities.add(activity);
                                }
                              });
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFF9800).withValues(alpha: 0.2) : Colors.grey[850],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSelected ? const Color(0xFFFF9800) : Colors.grey[700]!),
                              ),
                              child: Text(activity, style: TextStyle(fontSize: 13, color: isSelected ? const Color(0xFFFF9800) : Colors.grey[400])),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Compact Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: Color(0xFF00D67D), size: 20),
                const SizedBox(width: 8),
                Text('Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedGenders.clear();
                      _selectedInterests.clear();
                      _selectedConnectionTypes.clear();
                      _selectedActivities.clear();
                      _locationFilter = 'Near me';
                      _distanceFilter = 50;
                    });
                  },
                  child: Text('Reset', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: textColor, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === LOCATION SECTION ===
                  _buildSectionHeader('Location', Icons.location_on_rounded, const Color(0xFF00D67D)),
                  const SizedBox(height: 12),

                  // Location buttons
                  Row(
                    children: ['Near me', 'City', 'Worldwide'].map((filter) {
                      final isSelected = _locationFilter == filter;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: filter != 'Worldwide' ? 8 : 0),
                          child: GestureDetector(
                            onTap: () async {
                              if (filter == 'Near me') {
                                final hasPermission = await widget.checkLocationPermission();
                                if (!hasPermission) return;
                              }
                              setState(() => _locationFilter = filter);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF00D67D) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isSelected ? const Color(0xFF00D67D) : Colors.grey[700]!),
                              ),
                              child: Center(
                                child: Text(
                                  filter,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: isSelected ? Colors.white : subtextColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // Distance slider
                  if (_locationFilter != 'Worldwide') ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Distance', style: TextStyle(fontSize: 13, color: subtextColor)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D67D).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_distanceFilter.round()} km',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF00D67D)),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFF00D67D),
                        inactiveTrackColor: Colors.grey[800],
                        thumbColor: const Color(0xFF00D67D),
                        overlayColor: const Color(0xFF00D67D).withValues(alpha: 0.2),
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      ),
                      child: Slider(
                        value: _distanceFilter,
                        min: 1,
                        max: 500,
                        divisions: 499,
                        onChanged: (value) => setState(() => _distanceFilter = value),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // === GENDER SECTION ===
                  _buildSectionHeader('Gender', Icons.people_rounded, const Color(0xFF4A90E2)),
                  const SizedBox(height: 12),
                  Row(
                    children: widget.availableGenders.map((gender) {
                      final isSelected = _selectedGenders.contains(gender);
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: gender != widget.availableGenders.last ? 8 : 0),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedGenders.remove(gender);
                                } else {
                                  _selectedGenders.add(gender);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF4A90E2).withValues(alpha: 0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[700]!,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    gender == 'Male' ? Icons.male_rounded
                                        : gender == 'Female' ? Icons.female_rounded
                                        : Icons.transgender_rounded,
                                    color: isSelected ? const Color(0xFF4A90E2) : subtextColor,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    gender,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      color: isSelected ? const Color(0xFF4A90E2) : subtextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // === INTERESTS SECTION ===
                  Row(
                    children: [
                      _buildSectionHeader('Interests', Icons.favorite_rounded, const Color(0xFFFF6B6B)),
                      const Spacer(),
                      if (_selectedInterests.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_selectedInterests.length}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFF6B6B)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.availableInterests.take(12).map((interest) {
                      final isSelected = _selectedInterests.contains(interest);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedInterests.remove(interest);
                            } else if (_selectedInterests.length < 10) {
                              _selectedInterests.add(interest);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFF6B6B).withValues(alpha: 0.2) : Colors.grey[850],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFFF6B6B) : Colors.grey[700]!,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            interest,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? const Color(0xFFFF6B6B) : subtextColor,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (widget.availableInterests.length > 12)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: _showAllInterestsDialog,
                        child: Text(
                          'Show all ${widget.availableInterests.length} interests →',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFFF6B6B), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // === CONNECTION TYPES ===
                  Row(
                    children: [
                      _buildSectionHeader('Looking for', Icons.connect_without_contact_rounded, const Color(0xFF9C27B0)),
                      const Spacer(),
                      if (_selectedConnectionTypes.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_selectedConnectionTypes.length}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9C27B0)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Dating', 'Friendship', 'Business', 'Networking', 'Roommate', 'Travel Buddy'].map((type) {
                      final isSelected = _selectedConnectionTypes.contains(type);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedConnectionTypes.remove(type);
                            } else {
                              _selectedConnectionTypes.add(type);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF9C27B0).withValues(alpha: 0.2) : Colors.grey[850],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF9C27B0) : Colors.grey[700]!,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? const Color(0xFF9C27B0) : subtextColor,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: _showAllConnectionTypesDialog,
                      child: const Text(
                        'Show more options →',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9C27B0), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // === ACTIVITIES ===
                  Row(
                    children: [
                      _buildSectionHeader('Activities', Icons.sports_tennis_rounded, const Color(0xFFFF9800)),
                      const Spacer(),
                      if (_selectedActivities.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_selectedActivities.length}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFF9800)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Sports', 'Gaming', 'Music', 'Movies', 'Fitness', 'Travel'].map((activity) {
                      final isSelected = _selectedActivities.contains(activity);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedActivities.remove(activity);
                            } else {
                              _selectedActivities.add(activity);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFF9800).withValues(alpha: 0.2) : Colors.grey[850],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFFF9800) : Colors.grey[700]!,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            activity,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? const Color(0xFFFF9800) : subtextColor,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: _showAllActivitiesDialog,
                      child: const Text(
                        'Show more activities →',
                        style: TextStyle(fontSize: 12, color: Color(0xFFFF9800), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Apply Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Update parent state
                    widget.selectedGenders.clear();
                    widget.selectedGenders.addAll(_selectedGenders);
                    widget.selectedInterests.clear();
                    widget.selectedInterests.addAll(_selectedInterests);
                    widget.selectedConnectionTypes.clear();
                    widget.selectedConnectionTypes.addAll(_selectedConnectionTypes);
                    widget.selectedActivities.clear();
                    widget.selectedActivities.addAll(_selectedActivities);

                    Navigator.pop(context, {
                      'locationFilter': _locationFilter,
                      'distanceFilter': _distanceFilter,
                    });
                    widget.onApply();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D67D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    _getActiveFiltersCount() > 0 ? 'Apply ${_getActiveFiltersCount()} Filters' : 'Show All Results',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
