import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../res/config/app_colors.dart';
import '../res/config/app_assets.dart';

class CountryCodePickerSheet extends StatefulWidget {
  final List<Map<String, String>> countryCodes;
  final String selectedCountryCode;
  final Function(String code, String flag) onSelect;

  const CountryCodePickerSheet({
    super.key,
    required this.countryCodes,
    required this.selectedCountryCode,
    required this.onSelect,
  });

  @override
  State<CountryCodePickerSheet> createState() => _CountryCodePickerSheetState();
}

class _CountryCodePickerSheetState extends State<CountryCodePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _filteredCountries = [];

  @override
  void initState() {
    super.initState();
    _filteredCountries = widget.countryCodes;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCountries(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = widget.countryCodes;
      } else {
        _filteredCountries = widget.countryCodes.where((country) {
          final countryName = country['country']!.toLowerCase();
          final countryCode = country['code']!.toLowerCase();
          final searchQuery = query.toLowerCase();
          return countryName.contains(searchQuery) ||
              countryCode.contains(searchQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(
                AppAssets.homeBackgroundImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.splashGradient,
                    ),
                  );
                },
              ),
            ),
            // Dark overlay
            Positioned.fill(
              child: Container(
                color: AppColors.darkOverlay(alpha: 0.5),
              ),
            ),
            // Content with glassmorphism
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.glassBackgroundDark(alpha: 0.15),
                      AppColors.glassBackgroundDark(alpha: 0.05),
                    ],
                  ),
                  border: Border(
                    top: BorderSide(
                      color: AppColors.glassBorder(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Title
                    Text(
                      'Select Country Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search Field with glassmorphism
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _filterCountries,
                          style:
                              const TextStyle(color: Colors.white, fontSize: 16),
                          cursorColor: Colors.white,
                          decoration: InputDecoration(
                            hintText: 'Search country or code...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 15,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      _filterCountries('');
                                    },
                                  )
                                : null,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Country List
                    Expanded(
                      child: _filteredCountries.isEmpty
                          ? const Center(
                              child: Text(
                                'No countries found',
                                style:
                                    TextStyle(color: Colors.white54, fontSize: 16),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredCountries.length,
                              itemBuilder: (context, index) {
                                final country = _filteredCountries[index];
                                final isSelected =
                                    country['code'] == widget.selectedCountryCode;
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.3,
                                            ),
                                          )
                                        : null,
                                  ),
                                  child: ListTile(
                                    leading: Text(
                                      country['flag']!,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    title: Text(
                                      country['country']!,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.green.withValues(alpha: 0.3)
                                            : Colors.white.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.green.withValues(alpha: 0.5)
                                              : Colors.white.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Text(
                                        country['code']!,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.green
                                              : Colors.white,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    onTap: () {
                                      widget.onSelect(
                                        country['code']!,
                                        country['flag']!,
                                      );
                                      Navigator.pop(context);
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
