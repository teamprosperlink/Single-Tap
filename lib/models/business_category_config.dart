import 'package:flutter/material.dart';

/// Master categories covering all major business domains
enum BusinessCategory {
  hospitality,       // Hotels, Resorts, Guesthouses
  foodBeverage,      // Restaurants, Cafes, Bakeries
  retail,            // Shops, Stores, Boutiques
  beautyWellness,    // Salons, Spas, Beauty Parlors
  healthcare,        // Clinics, Doctors, Pharmacies
  education,         // Schools, Tutors, Training Centers
  fitness,           // Gyms, Yoga, Sports Academies
  automotive,        // Car Services, Dealerships, Workshops
  realEstate,        // Property, Rentals, Brokers
  travelTourism,     // Travel Agencies, Tour Operators
  entertainment,     // Events, Gaming, Cinema
  petServices,       // Pet Shops, Grooming, Boarding
  homeServices,      // Plumbing, Electrical, Cleaning
  technology,        // IT Services, Software, Tech Repair
  legal,             // Lawyers, Notaries, Legal Services
  professional,      // Consultants, HR, Marketing Agencies
  transportation,    // Courier, Logistics, Taxi
  artCreative,       // Photography, Design, Art Studios
  construction,      // Contractors, Interior Design
  agriculture,       // Farms, Nurseries, Dairy
  manufacturing,     // Factories, Workshops, Production
  weddingEvents,     // Wedding Planning, Decorators
  grocery,           // Supermarkets, Kirana, Wholesale
}

/// Features available for each business category
enum BusinessFeature {
  rooms,        // For hospitality - manage room types
  menu,         // For food & beverage - manage menu items
  products,     // For retail - manage product catalog
  services,     // For services - manage service offerings
  appointments, // For healthcare, services - booking system
  courses,      // For education - manage courses/classes
  portfolio,    // For professional, services - showcase work
  classes,      // For fitness, education - group classes
  bookings,     // For hospitality - room bookings
  orders,       // For retail, food - customer orders
  vehicles,     // For automotive - manage vehicles/inventory
  properties,   // For real estate - property listings
  packages,     // For travel, events - tour/event packages
}

/// Configuration for each business category
class BusinessCategoryConfig {
  final BusinessCategory category;
  final String id;
  final String displayName;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> subTypes;
  final List<BusinessFeature> features;
  final List<CategorySetupField> setupFields;

  const BusinessCategoryConfig({
    required this.category,
    required this.id,
    required this.displayName,
    required this.description,
    required this.icon,
    required this.color,
    required this.subTypes,
    required this.features,
    required this.setupFields,
  });

  /// Get all category configurations
  static List<BusinessCategoryConfig> get all => [
        hospitality,
        foodBeverage,
        grocery,
        retail,
        beautyWellness,
        healthcare,
        education,
        fitness,
        automotive,
        realEstate,
        travelTourism,
        entertainment,
        petServices,
        homeServices,
        technology,
        legal,
        professional,
        transportation,
        artCreative,
        construction,
        agriculture,
        manufacturing,
        weddingEvents,
      ];

  /// Get config by category enum
  static BusinessCategoryConfig getConfig(BusinessCategory category) {
    return all.firstWhere((c) => c.category == category);
  }

  /// Get config by category id string
  static BusinessCategoryConfig? getConfigById(String id) {
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Map old businessType to new category
  static BusinessCategory? getCategoryFromBusinessType(String businessType) {
    return _businessTypeToCategory[businessType];
  }

  // ============ HOSPITALITY ============
  static const hospitality = BusinessCategoryConfig(
    category: BusinessCategory.hospitality,
    id: 'hospitality',
    displayName: 'Hospitality',
    description: 'Hotels, Resorts & Stays',
    icon: Icons.hotel,
    color: Color(0xFF6366F1), // Indigo
    subTypes: [
      'Hotel',
      'Resort',
      'Guesthouse',
      'Hostel',
      'Villa',
      'Homestay',
      'Motel',
      'Service Apartment',
    ],
    features: [
      BusinessFeature.rooms,
      BusinessFeature.bookings,
      BusinessFeature.services,
    ],
    setupFields: [
      CategorySetupField(
        id: 'checkInTime',
        label: 'Check-in Time',
        type: FieldType.time,
        defaultValue: '14:00',
      ),
      CategorySetupField(
        id: 'checkOutTime',
        label: 'Check-out Time',
        type: FieldType.time,
        defaultValue: '11:00',
      ),
      CategorySetupField(
        id: 'amenities',
        label: 'Amenities',
        type: FieldType.multiSelect,
        options: [
          'WiFi',
          'Parking',
          'Pool',
          'Gym',
          'Restaurant',
          'Room Service',
          'AC',
          'Pet Friendly',
        ],
      ),
    ],
  );

  // ============ FOOD & BEVERAGE ============
  static const foodBeverage = BusinessCategoryConfig(
    category: BusinessCategory.foodBeverage,
    id: 'food_beverage',
    displayName: 'Food & Beverage',
    description: 'Restaurants, Cafes & Bakeries',
    icon: Icons.restaurant,
    color: Color(0xFFF59E0B), // Amber
    subTypes: [
      'Restaurant',
      'Cafe',
      'Bakery',
      'Bar & Pub',
      'Cloud Kitchen',
      'Food Truck',
      'Fast Food',
      'Fine Dining',
      'Catering',
      'Ice Cream & Desserts',
    ],
    features: [
      BusinessFeature.menu,
      BusinessFeature.orders,
      BusinessFeature.services,
    ],
    setupFields: [
      CategorySetupField(
        id: 'cuisineTypes',
        label: 'Cuisine Types',
        type: FieldType.multiSelect,
        options: [
          'Indian',
          'Chinese',
          'Italian',
          'Mexican',
          'Thai',
          'Japanese',
          'American',
          'Continental',
        ],
      ),
      CategorySetupField(
        id: 'diningOptions',
        label: 'Dining Options',
        type: FieldType.multiSelect,
        options: ['Dine-in', 'Takeaway', 'Delivery', 'Drive-through'],
      ),
      CategorySetupField(
        id: 'foodType',
        label: 'Food Type',
        type: FieldType.dropdown,
        options: ['Pure Veg', 'Non-Veg', 'Both'],
      ),
    ],
  );

  // ============ GROCERY ============
  static const grocery = BusinessCategoryConfig(
    category: BusinessCategory.grocery,
    id: 'grocery',
    displayName: 'Grocery & Essentials',
    description: 'Supermarkets, Kirana & Wholesale',
    icon: Icons.shopping_basket,
    color: Color(0xFF22C55E), // Green
    subTypes: [
      'Supermarket',
      'Kirana Store',
      'Wholesale',
      'Organic Store',
      'Fruits & Vegetables',
      'Dairy Shop',
      'Meat & Fish',
      'Convenience Store',
    ],
    features: [
      BusinessFeature.products,
      BusinessFeature.orders,
    ],
    setupFields: [
      CategorySetupField(
        id: 'productTypes',
        label: 'Product Types',
        type: FieldType.multiSelect,
        options: [
          'Groceries',
          'Fruits & Vegetables',
          'Dairy',
          'Meat & Fish',
          'Beverages',
          'Snacks',
          'Household',
          'Personal Care',
        ],
      ),
      CategorySetupField(
        id: 'deliveryOptions',
        label: 'Delivery Options',
        type: FieldType.multiSelect,
        options: ['Walk-in', 'Home Delivery', 'Store Pickup'],
      ),
    ],
  );

  // ============ RETAIL ============
  static const retail = BusinessCategoryConfig(
    category: BusinessCategory.retail,
    id: 'retail',
    displayName: 'Retail & Shopping',
    description: 'Shops, Stores & Boutiques',
    icon: Icons.storefront,
    color: Color(0xFF10B981), // Emerald
    subTypes: [
      'Clothing Store',
      'Electronics Store',
      'Boutique',
      'Jewelry Store',
      'Footwear Store',
      'Home & Furniture',
      'Sports & Outdoors',
      'Books & Stationery',
      'Gift Shop',
      'Mobile Store',
    ],
    features: [
      BusinessFeature.products,
      BusinessFeature.orders,
    ],
    setupFields: [
      CategorySetupField(
        id: 'productCategories',
        label: 'Product Categories',
        type: FieldType.multiSelect,
        options: [
          'Clothing',
          'Electronics',
          'Home & Living',
          'Beauty & Personal Care',
          'Jewelry & Accessories',
          'Sports & Fitness',
          'Books & Stationery',
        ],
      ),
      CategorySetupField(
        id: 'orderOptions',
        label: 'Order Options',
        type: FieldType.multiSelect,
        options: ['Walk-in', 'Online Orders', 'Home Delivery', 'Store Pickup'],
      ),
    ],
  );

  // ============ BEAUTY & WELLNESS ============
  static const beautyWellness = BusinessCategoryConfig(
    category: BusinessCategory.beautyWellness,
    id: 'beauty_wellness',
    displayName: 'Beauty & Wellness',
    description: 'Salons, Spas & Beauty Studios',
    icon: Icons.spa,
    color: Color(0xFFEC4899), // Pink
    subTypes: [
      'Hair Salon',
      'Day Spa',
      'Beauty Studio',
      'Barbershop',
      'Nail Bar',
      'Makeup Studio',
      'Brow & Lash Bar',
      'Wellness Center',
      'Med Spa',
      'Tattoo Studio',
      'Tanning Studio',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.appointments,
      BusinessFeature.products,
    ],
    setupFields: [
      CategorySetupField(
        id: 'serviceCategories',
        label: 'Treatment Categories',
        type: FieldType.multiSelect,
        options: [
          'Hair Styling & Cuts',
          'Hair Coloring',
          'Skin & Facials',
          'Nails',
          'Brows & Lashes',
          'Makeup',
          'Body Treatments',
          'Hair Removal',
          'Bridal',
          'Barbering',
        ],
      ),
      CategorySetupField(
        id: 'bookingType',
        label: 'Booking Type',
        type: FieldType.multiSelect,
        options: ['Walk-in Welcome', 'Booking Only', 'Both'],
      ),
      CategorySetupField(
        id: 'genderServed',
        label: 'Clientele',
        type: FieldType.dropdown,
        options: ['Men', 'Women', 'Unisex'],
      ),
    ],
  );

  // ============ HEALTHCARE ============
  static const healthcare = BusinessCategoryConfig(
    category: BusinessCategory.healthcare,
    id: 'healthcare',
    displayName: 'Healthcare',
    description: 'Hospitals, Clinics & Diagnostics',
    icon: Icons.local_hospital,
    color: Color(0xFFEF4444), // Red
    subTypes: [
      'Multi-Specialty Hospital',
      'Single-Specialty Hospital',
      'Clinic',
      'Polyclinic',
      'Diagnostic Center',
      'Dental Clinic',
      'Eye Hospital',
      'Pharmacy',
      'Physiotherapy Center',
      'Mental Health Clinic',
      'Ayurveda / Homeopathy',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'specializations',
        label: 'Departments & Specialties',
        type: FieldType.multiSelect,
        options: [
          'General Medicine',
          'Cardiology',
          'Orthopedics',
          'Neurology',
          'Dermatology',
          'Pediatrics',
          'Gynecology & Obstetrics',
          'ENT',
          'Ophthalmology',
          'Dental',
          'Oncology',
          'Gastroenterology',
          'Urology',
          'Pulmonology',
          'Nephrology',
          'Psychiatry',
          'Physiotherapy',
          'Radiology',
          'Pathology',
        ],
      ),
      CategorySetupField(
        id: 'appointmentType',
        label: 'Consultation Mode',
        type: FieldType.multiSelect,
        options: ['In-Person Visit', 'Video Consultation', 'Chat Consultation', 'Home Visit'],
      ),
      CategorySetupField(
        id: 'insuranceAccepted',
        label: 'Insurance & Payments',
        type: FieldType.multiSelect,
        options: ['Cashless Insurance', 'Reimbursement', 'Government Schemes', 'Cash / UPI / Card'],
      ),
      CategorySetupField(
        id: 'facilityFeatures',
        label: 'Facility Features',
        type: FieldType.multiSelect,
        options: ['Emergency / 24x7', 'Pharmacy On-Site', 'Lab & Diagnostics', 'Ambulance Service', 'Parking', 'Wheelchair Accessible'],
      ),
    ],
  );

  // ============ EDUCATION ============
  static const education = BusinessCategoryConfig(
    category: BusinessCategory.education,
    id: 'education',
    displayName: 'Education & Training',
    description: 'Coaching Institutes, Training Centers, Online Academies & Tutors',
    icon: Icons.school,
    color: Color(0xFF3B82F6), // Blue
    subTypes: [
      'Coaching Institute',
      'Training Academy',
      'Online Academy',
      'Tutoring Center',
      'Test Prep Center',
      'Language School',
      'Skill Development Center',
      'Computer & IT Training',
      'Music Academy',
      'Dance Academy',
      'Art & Design School',
      'Professional Certification Center',
      'Preschool & Playschool',
      'School',
    ],
    features: [
      BusinessFeature.courses,
      BusinessFeature.classes,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'courseCategories',
        label: 'Course Categories',
        type: FieldType.multiSelect,
        options: [
          'Technology & IT',
          'Data Science & AI',
          'Business & Management',
          'Digital Marketing',
          'Creative & Design',
          'Language & Communication',
          'Competitive Exams',
          'Academic (School/College)',
          'Music & Performing Arts',
          'Professional Certification',
          'Skill Development',
          'Finance & Accounting',
          'Health & Wellness',
          'Photography & Videography',
          'Spoken English',
        ],
      ),
      CategorySetupField(
        id: 'deliveryMode',
        label: 'Delivery Mode',
        type: FieldType.multiSelect,
        options: [
          'In-Person / Classroom',
          'Live Online',
          'Hybrid (Online + Offline)',
          'Self-Paced / Recorded',
          'One-on-One Tutoring',
        ],
      ),
      CategorySetupField(
        id: 'certificationPartners',
        label: 'Certification Partners',
        type: FieldType.multiSelect,
        options: [
          'Google',
          'Microsoft',
          'AWS',
          'Meta',
          'IBM',
          'Salesforce',
          'Adobe',
          'Cisco',
          'Oracle',
          'HubSpot',
          'Self-Certified',
        ],
      ),
      CategorySetupField(
        id: 'learningFeatures',
        label: 'Learning Features',
        type: FieldType.multiSelect,
        options: [
          'Live Classes',
          'Recorded Lectures',
          'Practice Tests & Quizzes',
          'Doubt Resolution',
          'Study Materials',
          'Project-Based Learning',
          'Mentorship',
          'Placement Assistance',
          'Internship Support',
          'Certificate on Completion',
          'EMI Payment Options',
          'Free Trial / Demo Class',
        ],
      ),
    ],
  );

  // ============ FITNESS ============
  static const fitness = BusinessCategoryConfig(
    category: BusinessCategory.fitness,
    id: 'fitness',
    displayName: 'Fitness & Sports',
    description: 'Gyms, Yoga Studios, Sports Academies & Wellness Centers',
    icon: Icons.fitness_center,
    color: Color(0xFF8B5CF6), // Violet
    subTypes: [
      'Gym & Fitness Center',
      'Yoga Studio',
      'CrossFit Box',
      'Pilates Studio',
      'Martial Arts Academy',
      'Boxing Gym',
      'Swimming & Aquatics Center',
      'Dance & Zumba Studio',
      'Sports Academy',
      'Personal Training Studio',
      'Sports Club',
      'Wellness & Recovery Center',
    ],
    features: [
      BusinessFeature.classes,
      BusinessFeature.appointments,
      BusinessFeature.services,
    ],
    setupFields: [
      CategorySetupField(
        id: 'workoutFormats',
        label: 'Workout Formats',
        type: FieldType.multiSelect,
        options: [
          'Weight Training',
          'Cardio',
          'HIIT',
          'Yoga',
          'Pilates',
          'CrossFit',
          'Boxing & Kickboxing',
          'Martial Arts',
          'Swimming',
          'Dance & Zumba',
          'Cycling / Spinning',
          'Functional Training',
          'Stretching & Mobility',
          'Personal Training',
          'Group Fitness',
        ],
      ),
      CategorySetupField(
        id: 'membershipPlans',
        label: 'Membership Plans',
        type: FieldType.multiSelect,
        options: [
          'Day Pass',
          'Monthly',
          'Quarterly',
          'Half-Yearly',
          'Annual',
          'Class Pack',
          'Unlimited',
        ],
      ),
      CategorySetupField(
        id: 'facilities',
        label: 'Facilities & Amenities',
        type: FieldType.multiSelect,
        options: [
          'Cardio Zone',
          'Strength Training Zone',
          'Free Weights Area',
          'Functional Training Zone',
          'Group Class Studios',
          'Swimming Pool',
          'Steam / Sauna',
          'Locker Rooms & Showers',
          'Juice Bar / Cafe',
          'Parking',
          'Wi-Fi',
          'AC / Climate Control',
          'Towel Service',
          'Personal Training Area',
          'Recovery / Physio Room',
        ],
      ),
      CategorySetupField(
        id: 'genderPolicy',
        label: 'Gender Policy',
        type: FieldType.dropdown,
        options: [
          'Co-Ed (Men & Women)',
          'Women Only',
          'Men Only',
        ],
      ),
    ],
  );

  // ============ AUTOMOTIVE ============
  static const automotive = BusinessCategoryConfig(
    category: BusinessCategory.automotive,
    id: 'automotive',
    displayName: 'Automotive',
    description: 'Dealerships, Service Centers, Car Wash & Auto Parts',
    icon: Icons.directions_car,
    color: Color(0xFF64748B), // Slate
    subTypes: [
      'Car Dealership (New)',
      'Used Car Dealership',
      'Two-Wheeler Dealership',
      'Multi-Brand Service Center',
      'Authorized Service Center',
      'Quick Service / Express Center',
      'Collision & Body Repair Shop',
      'Car Wash & Detailing',
      'Tire & Wheel Shop',
      'Auto Parts & Accessories',
      'Auto Electrical Shop',
      'EV Service Center',
      'Car Rental',
      'Vehicle Inspection Center',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.vehicles,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'vehicleTypes',
        label: 'Vehicle Types Handled',
        type: FieldType.multiSelect,
        options: [
          'Hatchback',
          'Sedan',
          'SUV / Crossover',
          'Truck / Pickup',
          'Van / MUV',
          'Luxury / Premium',
          'Sports / Performance',
          'Motorcycle / Scooter',
          'Commercial Vehicle',
          'Electric Vehicle (EV)',
          'Hybrid Vehicle',
          'Classic / Vintage',
        ],
      ),
      CategorySetupField(
        id: 'serviceCategories',
        label: 'Service Categories',
        type: FieldType.multiSelect,
        options: [
          'Periodic Maintenance',
          'Oil Change & Lube',
          'Brake Service',
          'Engine Repair',
          'Transmission Repair',
          'AC / Climate Control',
          'Electrical & Battery',
          'Suspension & Steering',
          'Tire & Wheel Service',
          'Denting & Painting',
          'Car Wash & Detailing',
          'Diagnostics & Inspection',
          'Exhaust System',
          'Body Work / Collision Repair',
          'EV Battery & Motor',
        ],
      ),
      CategorySetupField(
        id: 'brandsHandled',
        label: 'Brands Handled',
        type: FieldType.multiSelect,
        options: [
          'Maruti Suzuki',
          'Hyundai',
          'Tata',
          'Mahindra',
          'Kia',
          'Toyota',
          'Honda',
          'MG',
          'Volkswagen',
          'Skoda',
          'BMW',
          'Mercedes-Benz',
          'Audi',
          'Multi-Brand',
        ],
      ),
      CategorySetupField(
        id: 'facilityFeatures',
        label: 'Facility Features',
        type: FieldType.multiSelect,
        options: [
          'Pickup & Drop Service',
          'Genuine / OEM Parts',
          'Warranty on Service',
          'Loaner / Rental Car',
          'Waiting Lounge',
          'Wi-Fi',
          'CCTV Monitoring',
          'Computerized Diagnostics',
          'Roadside Assistance',
          'Insurance Claim Support',
          'EMI / Financing Options',
          'Free Estimates',
        ],
      ),
    ],
  );

  // ============ REAL ESTATE ============
  static const realEstate = BusinessCategoryConfig(
    category: BusinessCategory.realEstate,
    id: 'real_estate',
    displayName: 'Real Estate',
    description: 'Property Dealers, Builders & Brokers',
    icon: Icons.apartment,
    color: Color(0xFF0EA5E9), // Sky Blue
    subTypes: [
      'Real Estate Agency',
      'Property Dealer / Broker',
      'Builder / Developer',
      'Construction Company',
      'Property Management Company',
      'Real Estate Consultant',
      'Interior Designer',
      'PG / Hostel',
      'Co-working Space',
      'Commercial Leasing',
      'Land & Plot Dealer',
      'Housing Society',
      'Relocation Services',
      'Vastu / Feng Shui Consultant',
    ],
    features: [
      BusinessFeature.properties,
      BusinessFeature.services,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'propertyTypes',
        label: 'Property Types Handled',
        type: FieldType.multiSelect,
        options: [
          'Apartment / Flat',
          'Independent House / Bungalow',
          'Villa',
          'Penthouse',
          'Duplex / Triplex',
          'Studio Apartment',
          'Builder Floor',
          'Farmhouse',
          'Row House / Townhouse',
          'Plot / Land',
          'Office Space',
          'Retail Shop / Showroom',
          'Warehouse / Godown',
          'Commercial Building',
          'PG / Co-living',
        ],
      ),
      CategorySetupField(
        id: 'transactionTypes',
        label: 'Transaction Types',
        type: FieldType.multiSelect,
        options: [
          'Sale',
          'Rent',
          'Lease',
          'PG / Co-living',
          'New Projects',
          'Resale',
        ],
      ),
      CategorySetupField(
        id: 'operatingAreas',
        label: 'Operating Areas / Localities',
        type: FieldType.multiSelect,
        options: [
          'City Center',
          'Suburbs',
          'IT / Business Hub',
          'Residential Colony',
          'Highway / Outskirts',
          'Industrial Area',
          'Tier 1 Cities',
          'Tier 2 Cities',
          'Pan India',
          'International',
        ],
      ),
      CategorySetupField(
        id: 'agencyFeatures',
        label: 'Agency Features',
        type: FieldType.multiSelect,
        options: [
          'RERA Registered',
          'Verified Listings',
          'Virtual Tours / 3D',
          'Home Loan Assistance',
          'Legal Documentation',
          'Interior Design Services',
          'Property Valuation',
          'NRI Services',
          'Vastu Consultation',
          'Site Visits Arranged',
          'Property Management',
          'Rental Agreement Help',
        ],
      ),
    ],
  );

  // ============ TRAVEL & TOURISM ============
  static const travelTourism = BusinessCategoryConfig(
    category: BusinessCategory.travelTourism,
    id: 'travel_tourism',
    displayName: 'Travel & Tourism',
    description: 'Travel Agencies & Tour Operators',
    icon: Icons.flight,
    color: Color(0xFF06B6D4), // Cyan
    subTypes: [
      'Travel Agency',
      'Tour Operator',
      'Adventure Tourism',
      'Pilgrimage & Spiritual Tours',
      'Wildlife & Safari Operator',
      'Luxury Travel Specialist',
      'Cruise Operator',
      'Corporate Travel Provider',
      'Destination Management Company',
      'Activity & Experience Provider',
      'Visa & Passport Services',
      'Homestay & Eco Tourism',
      'Transport & Cab Service',
      'Trekking & Mountaineering',
    ],
    features: [
      BusinessFeature.packages,
      BusinessFeature.bookings,
      BusinessFeature.services,
    ],
    setupFields: [
      CategorySetupField(
        id: 'tourTypes',
        label: 'Tour Types',
        type: FieldType.multiSelect,
        options: [
          'Domestic Tours',
          'International Tours',
          'Pilgrimage / Spiritual',
          'Adventure / Trekking',
          'Honeymoon / Romantic',
          'Corporate / MICE',
          'Group Tours',
          'Wildlife & Safari',
          'Beach & Island',
          'Heritage & Culture',
          'Hill Station / Mountain',
          'Cruise',
          'Road Trip',
          'Backpacking / Budget',
        ],
      ),
      CategorySetupField(
        id: 'destinationsCovered',
        label: 'Destinations Covered',
        type: FieldType.multiSelect,
        options: [
          'North India',
          'South India',
          'East India',
          'West India',
          'Rajasthan',
          'Kerala',
          'Himachal & Uttarakhand',
          'Kashmir',
          'North East India',
          'Goa',
          'Southeast Asia',
          'Europe',
          'Middle East',
          'Americas',
          'Africa',
          'Australia & Oceania',
        ],
      ),
      CategorySetupField(
        id: 'servicesOffered',
        label: 'Services Offered',
        type: FieldType.multiSelect,
        options: [
          'Flight Booking',
          'Hotel Booking',
          'Visa Assistance',
          'Passport Services',
          'Travel Insurance',
          'Forex / Currency Exchange',
          'Airport Transfers',
          'Car / Cab Rental',
          'Train / Bus Booking',
          'Cruise Booking',
          'Tour Guide',
          'Custom Itinerary Planning',
        ],
      ),
      CategorySetupField(
        id: 'agencyFeatures',
        label: 'Agency Features',
        type: FieldType.multiSelect,
        options: [
          'IATA Accredited',
          'Government Approved',
          '24/7 Travel Support',
          'EMI / Easy Payment',
          'Group Discounts',
          'Multilingual Guides',
          'Pick-Up & Drop',
          'Customized Packages',
          'Corporate Tie-Ups',
          'Online Booking Portal',
          'Travel Blog / Resources',
          'Loyalty / Reward Program',
        ],
      ),
    ],
  );

  // ============ ENTERTAINMENT ============
  static const entertainment = BusinessCategoryConfig(
    category: BusinessCategory.entertainment,
    id: 'entertainment',
    displayName: 'Entertainment',
    description: 'Events, Gaming & Recreation',
    icon: Icons.celebration,
    color: Color(0xFFF97316), // Orange
    subTypes: [
      'Event Venue',
      'Banquet Hall',
      'Party Hall',
      'Gaming Zone',
      'Amusement Park',
      'Water Park',
      'Cinema / Multiplex',
      'Theatre / Auditorium',
      'Night Club / Lounge',
      'Comedy Club',
      'Bowling Alley',
      'Escape Room',
      'VR / AR Experience Center',
      'Go-Karting',
      'Trampoline Park',
      'Laser Tag Arena',
    ],
    features: [
      BusinessFeature.bookings,
      BusinessFeature.packages,
      BusinessFeature.services,
      BusinessFeature.portfolio,
    ],
    setupFields: [
      CategorySetupField(
        id: 'eventTypes',
        label: 'Event Types',
        type: FieldType.multiSelect,
        options: [
          'Weddings & Receptions',
          'Corporate Events',
          'Birthday Parties',
          'Conferences & Seminars',
          'Live Music / Concerts',
          'Stand-Up Comedy',
          'DJ Nights',
          'Theatre / Drama',
          'Private Parties',
          'Award Ceremonies',
          'Cultural Programs',
          'Kids Parties',
          'Gaming Tournaments',
          'Film Screenings',
        ],
      ),
      CategorySetupField(
        id: 'amenities',
        label: 'Amenities & Facilities',
        type: FieldType.multiSelect,
        options: [
          'Parking',
          'Valet Parking',
          'AC / Climate Control',
          'Sound System',
          'Professional Lighting',
          'Stage / Performance Area',
          'Dance Floor',
          'Outdoor Area',
          'Food & Beverage',
          'Liquor License',
          'Wi-Fi',
          'Wheelchair Accessible',
          'Kids Play Area',
          'VIP / Premium Seating',
        ],
      ),
      CategorySetupField(
        id: 'venueFeatures',
        label: 'Venue Features',
        type: FieldType.multiSelect,
        options: [
          'Online Booking',
          'Group Discounts',
          'Membership Plans',
          'Birthday Packages',
          'Corporate Packages',
          'In-House Catering',
          'External Catering Allowed',
          'Decoration Services',
          'Photography / Videography',
          'Live Streaming',
          'Smoke Machine / Effects',
          'Security / Bouncers',
        ],
      ),
      CategorySetupField(
        id: 'capacity',
        label: 'Capacity',
        type: FieldType.dropdown,
        options: [
          'Up to 50',
          '50-100',
          '100-300',
          '300-500',
          '500-1000',
          '1000+',
        ],
      ),
    ],
  );

  // ============ PET SERVICES ============
  static const petServices = BusinessCategoryConfig(
    category: BusinessCategory.petServices,
    id: 'pet_services',
    displayName: 'Pet Services',
    description: 'Pet Shops, Grooming & Boarding',
    icon: Icons.pets,
    color: Color(0xFFA855F7), // Purple
    subTypes: [
      'Pet Shop',
      'Pet Grooming Salon',
      'Pet Boarding & Kennel',
      'Pet Training Center',
      'Veterinary Clinic',
      'Pet Food Store',
      'Pet Accessories Store',
      'Pet Adoption Center',
      'Pet Daycare',
      'Pet Spa & Wellness',
      'Pet Taxi & Transport',
      'Aquarium & Fish Store',
      'Dog Walking Service',
      'Pet Pharmacy',
      'Pet Photography',
      'Mobile Pet Grooming',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.products,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'petTypes',
        label: 'Pet Types Served',
        type: FieldType.multiSelect,
        options: [
          'Dogs',
          'Cats',
          'Birds',
          'Fish',
          'Rabbits',
          'Hamsters',
          'Guinea Pigs',
          'Reptiles',
          'Ferrets',
          'Exotic Pets',
        ],
      ),
      CategorySetupField(
        id: 'servicesOffered',
        label: 'Services Offered',
        type: FieldType.multiSelect,
        options: [
          'Grooming (Bath & Trim)',
          'Full Grooming & Styling',
          'Boarding (Overnight)',
          'Daycare',
          'Dog Walking',
          'Pet Training (Basic)',
          'Advanced / Behavioral Training',
          'Veterinary Consultation',
          'Vaccination & Deworming',
          'Pet Taxi / Transport',
          'Pet Sitting (In-Home)',
          'Pet Adoption',
          'Emergency Care',
          'Dental Care',
        ],
      ),
      CategorySetupField(
        id: 'facilities',
        label: 'Facilities & Amenities',
        type: FieldType.multiSelect,
        options: [
          'AC Kennels / Suites',
          'Outdoor Play Area',
          'Indoor Play Zone',
          'Swimming Pool',
          'CCTV Monitoring',
          'Live Webcam for Owners',
          'Grooming Station',
          'Veterinary On-Site',
          'Pet Pharmacy',
          'Pet Food Court',
          'Training Ground',
          'Pickup & Drop Service',
          'Parking',
          'Wheelchair Accessible',
        ],
      ),
      CategorySetupField(
        id: 'certifications',
        label: 'Certifications',
        type: FieldType.multiSelect,
        options: [
          'Veterinary Council License',
          'Animal Welfare Board Registered',
          'CPDT-KA Certified Trainers',
          'Pet First Aid Certified',
          'Professional Grooming Certified',
          'FSSAI (Pet Food)',
        ],
      ),
    ],
  );

  // ============ HOME SERVICES ============
  static const homeServices = BusinessCategoryConfig(
    category: BusinessCategory.homeServices,
    id: 'home_services',
    displayName: 'Home Services',
    description: 'Plumbing, Electrical & Cleaning',
    icon: Icons.home_repair_service,
    color: Color(0xFF84CC16), // Lime
    subTypes: [
      'Plumber',
      'Electrician',
      'Carpenter',
      'Painter',
      'AC Service & Repair',
      'Pest Control',
      'Home Cleaning Service',
      'Appliance Repair',
      'Handyman',
      'Movers & Packers',
      'Waterproofing',
      'Home Renovation',
      'RO & Water Purifier Service',
      'Interior Designer',
      'Landscaping & Gardening',
      'CCTV & Security Installation',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'serviceTypes',
        label: 'Service Types',
        type: FieldType.multiSelect,
        options: [
          'Plumbing',
          'Electrical',
          'Carpentry',
          'Painting (Interior & Exterior)',
          'AC / Refrigeration',
          'Pest Control',
          'Deep Cleaning',
          'Appliance Repair',
          'Waterproofing & Seepage',
          'Modular Kitchen',
          'RO / Water Purifier',
          'Inverter / UPS Repair',
          'Geyser / Water Heater',
          'CCTV & Security',
        ],
      ),
      CategorySetupField(
        id: 'serviceArea',
        label: 'Service Area',
        type: FieldType.dropdown,
        options: [
          'Within 5 km',
          'Within 10 km',
          'Within 25 km',
          'City-wide',
          'Multiple Cities',
        ],
      ),
      CategorySetupField(
        id: 'serviceFeatures',
        label: 'Service Features',
        type: FieldType.multiSelect,
        options: [
          'Same-Day Service',
          '24/7 Emergency Service',
          'Background-Verified Professionals',
          'Warranty on Work',
          'Annual Maintenance Contracts',
          'Free Inspection',
          'Genuine Spare Parts',
          'Eco-Friendly Products',
          'Doorstep Service',
          'Online Booking',
          'Subscription Plans',
          'Corporate / Bulk Services',
        ],
      ),
      CategorySetupField(
        id: 'certifications',
        label: 'Certifications & Compliance',
        type: FieldType.multiSelect,
        options: [
          'Licensed Electricians',
          'Licensed Plumbers',
          'ISI Certified',
          'Pest Control License (CIB)',
          'Fire Safety Certified',
          'ISO Certified',
          'Background Verified Team',
          'Insured & Bonded',
        ],
      ),
    ],
  );

  // ============ TECHNOLOGY ============
  static const technology = BusinessCategoryConfig(
    category: BusinessCategory.technology,
    id: 'technology',
    displayName: 'Technology & IT',
    description: 'IT Services, Software & Repair',
    icon: Icons.computer,
    color: Color(0xFF14B8A6), // Teal
    subTypes: [
      'IT Services & Consulting',
      'Software Development Company',
      'Web Development Agency',
      'Mobile App Development',
      'Cloud Solutions Provider',
      'Cybersecurity Firm',
      'Digital Marketing Agency',
      'Data Analytics & AI/ML',
      'ERP & CRM Solutions',
      'IT Support & AMC',
      'Networking & Infrastructure',
      'UI/UX Design Studio',
      'Computer & Laptop Repair',
      'Mobile Repair Center',
      'DevOps & Automation',
      'SaaS Product Company',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'techServices',
        label: 'Services Offered',
        type: FieldType.multiSelect,
        options: [
          'Software Development',
          'Web Development',
          'Mobile App Development',
          'Cloud Migration & Management',
          'Cybersecurity & Compliance',
          'Data Analytics & BI',
          'AI / ML Solutions',
          'UI/UX Design',
          'DevOps & CI/CD',
          'ERP Implementation',
          'CRM Solutions',
          'IT Support & AMC',
          'Digital Marketing & SEO',
          'Networking & Infrastructure',
        ],
      ),
      CategorySetupField(
        id: 'techStack',
        label: 'Technology Stack',
        type: FieldType.multiSelect,
        options: [
          'React / Next.js',
          'Angular / Vue.js',
          'Flutter / Dart',
          'React Native',
          'Node.js / Express',
          'Python / Django',
          'Java / Spring Boot',
          '.NET / C#',
          'PHP / Laravel',
          'AWS',
          'Azure',
          'Google Cloud',
          'Firebase',
          'Docker / Kubernetes',
        ],
      ),
      CategorySetupField(
        id: 'clientType',
        label: 'Client Type',
        type: FieldType.multiSelect,
        options: [
          'Individuals',
          'Startups',
          'SMBs',
          'Mid-Market',
          'Enterprises',
          'Government',
        ],
      ),
      CategorySetupField(
        id: 'certifications',
        label: 'Certifications & Partnerships',
        type: FieldType.multiSelect,
        options: [
          'ISO 27001 Certified',
          'ISO 9001 Certified',
          'CMMI Level 3+',
          'SOC 2 Compliant',
          'AWS Partner',
          'Microsoft Gold Partner',
          'Google Cloud Partner',
          'NASSCOM Member',
          'STPI Registered',
        ],
      ),
    ],
  );

  // ============ LEGAL ============
  static const legal = BusinessCategoryConfig(
    category: BusinessCategory.legal,
    id: 'legal',
    displayName: 'Legal Services',
    description: 'Lawyers, Notaries & Legal Aid',
    icon: Icons.gavel,
    color: Color(0xFF78716C), // Stone
    subTypes: [
      'Lawyer / Advocate',
      'Corporate Law Firm',
      'Boutique Law Firm',
      'Notary Public',
      'Legal Consultant',
      'Tax Consultant / CA-Lawyer',
      'Patent / Trademark Attorney',
      'Criminal Defense Lawyer',
      'Family Court Lawyer',
      'Property / Real Estate Lawyer',
      'Immigration Lawyer',
      'Cyber / IT Law Specialist',
      'Arbitration & Mediation Center',
      'Legal Aid / Pro Bono',
      'Labour & Employment Lawyer',
      'Insolvency Professional',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'practiceAreas',
        label: 'Practice Areas',
        type: FieldType.multiSelect,
        options: [
          'Civil Litigation',
          'Criminal Defense',
          'Family & Matrimonial',
          'Property & Real Estate',
          'Corporate & Commercial',
          'Tax Law (Direct & GST)',
          'Intellectual Property',
          'Labour & Employment',
          'Immigration & Visa',
          'Banking & Finance',
          'Arbitration & Dispute Resolution',
          'Insolvency & Bankruptcy (IBC)',
          'Consumer Protection',
          'Cyber Law & Data Privacy',
          'Constitutional & Writ',
          'Environmental Law',
          'Startup & Business Formation',
          'Wills, Trusts & Estate Planning',
        ],
      ),
      CategorySetupField(
        id: 'courtsPracticedIn',
        label: 'Courts Practiced In',
        type: FieldType.multiSelect,
        options: [
          'Supreme Court',
          'High Court',
          'District Court',
          'NCLT / NCLAT',
          'Consumer Forum',
          'Family Court',
          'Labour Court / Tribunal',
          'ITAT / SAT / NGT',
        ],
      ),
      CategorySetupField(
        id: 'feeStructure',
        label: 'Fee Structure',
        type: FieldType.multiSelect,
        options: [
          'Consultation Fee',
          'Hourly Rate',
          'Per Hearing',
          'Fixed / Flat Fee',
          'Monthly Retainer',
          'Per Case / Package',
        ],
      ),
      CategorySetupField(
        id: 'credentials',
        label: 'Credentials & Memberships',
        type: FieldType.multiSelect,
        options: [
          'Bar Council Registered',
          'AIBE Certificate of Practice',
          'Senior Advocate Designation',
          'Advocate on Record (AOR)',
          'Registered Patent Agent',
          'Registered Trademark Agent',
          'Insolvency Professional (IBBI)',
          'Certified Mediator',
          'NASSCOM Legal Member',
          'Chambers & Partners Ranked',
        ],
      ),
    ],
  );

  // ============ PROFESSIONAL ============
  static const professional = BusinessCategoryConfig(
    category: BusinessCategory.professional,
    id: 'professional',
    displayName: 'Professional Services',
    description: 'Consultants, HR & Agencies',
    icon: Icons.work,
    color: Color(0xFF6B7280), // Gray
    subTypes: [
      'Management Consultant',
      'Business Strategy Consultant',
      'HR / Recruitment Agency',
      'Digital Marketing Agency',
      'PR / Communications Agency',
      'Branding & Design Agency',
      'Chartered Accountant (CA) Firm',
      'Company Secretary (CS) Firm',
      'Architecture / Interior Design Firm',
      'Event Management Company',
      'Training & Development Company',
      'Financial Advisory',
      'Operations Consultant',
      'Research & Analytics Firm',
      'ESG / Sustainability Consultant',
      'Freelance Consultant',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.appointments,
      BusinessFeature.portfolio,
    ],
    setupFields: [
      CategorySetupField(
        id: 'expertise',
        label: 'Areas of Expertise',
        type: FieldType.multiSelect,
        options: [
          'Business Strategy',
          'Marketing & Branding',
          'Digital Marketing (SEO/SEM/Social)',
          'HR & Recruitment',
          'Operations & Supply Chain',
          'Sales & Revenue Growth',
          'Finance & Accounting',
          'Tax & GST Advisory',
          'Audit & Assurance',
          'Architecture & Interior Design',
          'Event Management (Corporate/Social)',
          'Public Relations & Media',
          'Training & L&D',
          'Sustainability / ESG',
        ],
      ),
      CategorySetupField(
        id: 'clientType',
        label: 'Client Types Served',
        type: FieldType.multiSelect,
        options: [
          'Startups',
          'SMEs / MSMEs',
          'Mid-Market',
          'Large Enterprises',
          'MNCs',
          'Government / PSUs',
          'Non-Profits / NGOs',
          'Individuals',
        ],
      ),
      CategorySetupField(
        id: 'pricingModels',
        label: 'Pricing Models',
        type: FieldType.multiSelect,
        options: [
          'Hourly Rate',
          'Project-Based / Fixed Fee',
          'Monthly Retainer',
          'Milestone-Based',
          'Performance / Success Fee',
          'Packaged (Basic/Standard/Premium)',
        ],
      ),
      CategorySetupField(
        id: 'certifications',
        label: 'Certifications & Credentials',
        type: FieldType.multiSelect,
        options: [
          'CA (ICAI)',
          'CS (ICSI)',
          'CMA (ICMAI)',
          'PMP (PMI)',
          'Google Partner / Certified',
          'Meta Business Partner',
          'HubSpot Certified',
          'ISO 9001 Certified',
          'SHRM-CP / SHRM-SCP',
          'LEED / GRIHA Certified',
          'CMC (Certified Management Consultant)',
        ],
      ),
    ],
  );

  // ============ TRANSPORTATION ============
  static const transportation = BusinessCategoryConfig(
    category: BusinessCategory.transportation,
    id: 'transportation',
    displayName: 'Transportation',
    description: 'Courier, Logistics & Taxi',
    icon: Icons.local_shipping,
    color: Color(0xFFDC2626), // Red Dark
    subTypes: [
      'Courier Service',
      'Logistics Company',
      'Taxi Service',
      'Auto Rickshaw',
      'Truck Transport',
      'Movers & Packers',
      'Ambulance Service',
      'School Bus',
      'Bike Taxi',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.bookings,
      BusinessFeature.vehicles,
    ],
    setupFields: [
      CategorySetupField(
        id: 'transportTypes',
        label: 'Transport Types',
        type: FieldType.multiSelect,
        options: ['Passenger', 'Goods', 'Documents', 'Medical', 'Food Delivery'],
      ),
      CategorySetupField(
        id: 'serviceArea',
        label: 'Service Area',
        type: FieldType.dropdown,
        options: ['Local', 'City', 'State', 'National', 'International'],
      ),
    ],
  );

  // ============ ART & CREATIVE ============
  static const artCreative = BusinessCategoryConfig(
    category: BusinessCategory.artCreative,
    id: 'art_creative',
    displayName: 'Art & Creative',
    description: 'Photography, Design & Studios',
    icon: Icons.palette,
    color: Color(0xFFE11D48), // Rose
    subTypes: [
      'Photography Studio',
      'Graphic Designer',
      'Video Production',
      'Art Gallery',
      'Printing Press',
      'Signage & Banners',
      'Animation Studio',
      'Music Studio',
      'Content Creator',
    ],
    features: [
      BusinessFeature.portfolio,
      BusinessFeature.services,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'creativeServices',
        label: 'Creative Services',
        type: FieldType.multiSelect,
        options: [
          'Photography',
          'Videography',
          'Graphic Design',
          'Logo Design',
          'Printing',
          'Editing',
          'Animation',
          'Social Media Content',
        ],
      ),
      CategorySetupField(
        id: 'eventTypes',
        label: 'Event Types',
        type: FieldType.multiSelect,
        options: ['Weddings', 'Corporate', 'Product', 'Fashion', 'Food', 'Real Estate'],
      ),
    ],
  );

  // ============ CONSTRUCTION ============
  static const construction = BusinessCategoryConfig(
    category: BusinessCategory.construction,
    id: 'construction',
    displayName: 'Construction',
    description: 'Contractors, Interior & Renovation',
    icon: Icons.construction,
    color: Color(0xFFCA8A04), // Yellow Dark
    subTypes: [
      'Building Contractor',
      'Civil Engineer',
      'Architect',
      'Interior Designer',
      'Renovation',
      'Flooring',
      'Roofing',
      'False Ceiling',
      'Modular Kitchen',
    ],
    features: [
      BusinessFeature.services,
      BusinessFeature.portfolio,
      BusinessFeature.appointments,
    ],
    setupFields: [
      CategorySetupField(
        id: 'constructionServices',
        label: 'Construction Services',
        type: FieldType.multiSelect,
        options: [
          'New Construction',
          'Renovation',
          'Interior Design',
          'Architecture',
          'Civil Work',
          'Electrical',
          'Plumbing',
          'Finishing',
        ],
      ),
      CategorySetupField(
        id: 'projectTypes',
        label: 'Project Types',
        type: FieldType.multiSelect,
        options: ['Residential', 'Commercial', 'Industrial', 'Institutional'],
      ),
    ],
  );

  // ============ AGRICULTURE ============
  static const agriculture = BusinessCategoryConfig(
    category: BusinessCategory.agriculture,
    id: 'agriculture',
    displayName: 'Agriculture & Nursery',
    description: 'Farms, Nurseries & Dairy',
    icon: Icons.agriculture,
    color: Color(0xFF16A34A), // Green Dark
    subTypes: [
      'Farm',
      'Nursery',
      'Dairy Farm',
      'Poultry Farm',
      'Organic Farm',
      'Seed Shop',
      'Fertilizer Shop',
      'Agri Equipment',
      'Fishery',
    ],
    features: [
      BusinessFeature.products,
      BusinessFeature.services,
    ],
    setupFields: [
      CategorySetupField(
        id: 'farmTypes',
        label: 'Farm/Product Types',
        type: FieldType.multiSelect,
        options: [
          'Vegetables',
          'Fruits',
          'Grains',
          'Dairy',
          'Poultry',
          'Fishery',
          'Flowers',
          'Plants',
          'Organic',
        ],
      ),
      CategorySetupField(
        id: 'salesType',
        label: 'Sales Type',
        type: FieldType.multiSelect,
        options: ['Wholesale', 'Retail', 'Direct to Consumer', 'B2B'],
      ),
    ],
  );

  // ============ MANUFACTURING ============
  static const manufacturing = BusinessCategoryConfig(
    category: BusinessCategory.manufacturing,
    id: 'manufacturing',
    displayName: 'Manufacturing',
    description: 'Factories, Workshops & Production',
    icon: Icons.factory,
    color: Color(0xFF57534E), // Warm Gray
    subTypes: [
      'Factory',
      'Workshop',
      'Fabrication',
      'Packaging',
      'Textile',
      'Food Processing',
      'Furniture Manufacturing',
      'Machine Shop',
      'Printing Press',
    ],
    features: [
      BusinessFeature.products,
      BusinessFeature.services,
      BusinessFeature.orders,
    ],
    setupFields: [
      CategorySetupField(
        id: 'manufacturingTypes',
        label: 'Manufacturing Types',
        type: FieldType.multiSelect,
        options: [
          'Consumer Goods',
          'Industrial Products',
          'Food & Beverage',
          'Textiles',
          'Machinery',
          'Packaging',
          'Custom Manufacturing',
        ],
      ),
      CategorySetupField(
        id: 'orderTypes',
        label: 'Order Types',
        type: FieldType.multiSelect,
        options: ['Bulk Orders', 'Custom Orders', 'Retail', 'B2B'],
      ),
    ],
  );

  // ============ WEDDING & EVENTS ============
  static const weddingEvents = BusinessCategoryConfig(
    category: BusinessCategory.weddingEvents,
    id: 'wedding_events',
    displayName: 'Wedding & Events',
    description: 'Wedding Planning & Decorators',
    icon: Icons.cake,
    color: Color(0xFFDB2777), // Pink Dark
    subTypes: [
      'Wedding Planner',
      'Event Decorator',
      'Caterer',
      'DJ & Sound',
      'Florist',
      'Mehndi Artist',
      'Wedding Card',
      'Pandit/Priest',
      'Wedding Venue',
      'Choreographer',
    ],
    features: [
      BusinessFeature.packages,
      BusinessFeature.services,
      BusinessFeature.portfolio,
      BusinessFeature.bookings,
    ],
    setupFields: [
      CategorySetupField(
        id: 'eventServices',
        label: 'Event Services',
        type: FieldType.multiSelect,
        options: [
          'Wedding Planning',
          'Decoration',
          'Catering',
          'Photography',
          'Videography',
          'DJ & Music',
          'Makeup',
          'Mehndi',
          'Flowers',
        ],
      ),
      CategorySetupField(
        id: 'eventTypes',
        label: 'Event Types',
        type: FieldType.multiSelect,
        options: [
          'Wedding',
          'Engagement',
          'Reception',
          'Birthday',
          'Corporate',
          'Anniversary',
          'Baby Shower',
        ],
      ),
    ],
  );

  /// Map old business types to new categories
  static const Map<String, BusinessCategory> _businessTypeToCategory = {
    'Retail Store': BusinessCategory.retail,
    'Restaurant & Cafe': BusinessCategory.foodBeverage,
    'Professional Services': BusinessCategory.professional,
    'Healthcare': BusinessCategory.healthcare,
    'Beauty & Wellness': BusinessCategory.beautyWellness,
    'Fitness & Sports': BusinessCategory.fitness,
    'Education & Training': BusinessCategory.education,
    'Technology & IT': BusinessCategory.technology,
    'Manufacturing': BusinessCategory.manufacturing,
    'Construction': BusinessCategory.construction,
    'Real Estate': BusinessCategory.realEstate,
    'Transportation & Logistics': BusinessCategory.transportation,
    'Entertainment & Media': BusinessCategory.entertainment,
    'Hospitality & Tourism': BusinessCategory.hospitality,
    'Non-Profit Organization': BusinessCategory.professional,
    'Home Services': BusinessCategory.homeServices,
    'Automotive': BusinessCategory.automotive,
    'Agriculture': BusinessCategory.agriculture,
    'Other': BusinessCategory.professional,
  };
}

/// Field types for category-specific setup
enum FieldType {
  text,
  dropdown,
  multiSelect,
  toggle,
  time,
  number,
}

/// Setup field configuration
class CategorySetupField {
  final String id;
  final String label;
  final FieldType type;
  final List<String>? options;
  final String? defaultValue;
  final bool required;

  const CategorySetupField({
    required this.id,
    required this.label,
    required this.type,
    this.options,
    this.defaultValue,
    this.required = false,
  });
}

/// Extension to get string value of category
extension BusinessCategoryExtension on BusinessCategory {
  String get id {
    switch (this) {
      case BusinessCategory.hospitality:
        return 'hospitality';
      case BusinessCategory.foodBeverage:
        return 'food_beverage';
      case BusinessCategory.grocery:
        return 'grocery';
      case BusinessCategory.retail:
        return 'retail';
      case BusinessCategory.beautyWellness:
        return 'beauty_wellness';
      case BusinessCategory.healthcare:
        return 'healthcare';
      case BusinessCategory.education:
        return 'education';
      case BusinessCategory.fitness:
        return 'fitness';
      case BusinessCategory.automotive:
        return 'automotive';
      case BusinessCategory.realEstate:
        return 'real_estate';
      case BusinessCategory.travelTourism:
        return 'travel_tourism';
      case BusinessCategory.entertainment:
        return 'entertainment';
      case BusinessCategory.petServices:
        return 'pet_services';
      case BusinessCategory.homeServices:
        return 'home_services';
      case BusinessCategory.technology:
        return 'technology';
      case BusinessCategory.legal:
        return 'legal';
      case BusinessCategory.professional:
        return 'professional';
      case BusinessCategory.transportation:
        return 'transportation';
      case BusinessCategory.artCreative:
        return 'art_creative';
      case BusinessCategory.construction:
        return 'construction';
      case BusinessCategory.agriculture:
        return 'agriculture';
      case BusinessCategory.manufacturing:
        return 'manufacturing';
      case BusinessCategory.weddingEvents:
        return 'wedding_events';
    }
  }

  String get displayName => BusinessCategoryConfig.getConfig(this).displayName;
  IconData get icon => BusinessCategoryConfig.getConfig(this).icon;
  Color get color => BusinessCategoryConfig.getConfig(this).color;
  List<String> get subTypes => BusinessCategoryConfig.getConfig(this).subTypes;
  List<BusinessFeature> get features => BusinessCategoryConfig.getConfig(this).features;

  /// Parse category from string
  static BusinessCategory? fromString(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'hospitality':
        return BusinessCategory.hospitality;
      case 'food_beverage':
        return BusinessCategory.foodBeverage;
      case 'grocery':
        return BusinessCategory.grocery;
      case 'retail':
        return BusinessCategory.retail;
      case 'beauty_wellness':
        return BusinessCategory.beautyWellness;
      case 'healthcare':
        return BusinessCategory.healthcare;
      case 'education':
        return BusinessCategory.education;
      case 'fitness':
        return BusinessCategory.fitness;
      case 'automotive':
        return BusinessCategory.automotive;
      case 'real_estate':
        return BusinessCategory.realEstate;
      case 'travel_tourism':
        return BusinessCategory.travelTourism;
      case 'entertainment':
        return BusinessCategory.entertainment;
      case 'pet_services':
        return BusinessCategory.petServices;
      case 'home_services':
        return BusinessCategory.homeServices;
      case 'technology':
        return BusinessCategory.technology;
      case 'legal':
        return BusinessCategory.legal;
      case 'professional':
        return BusinessCategory.professional;
      case 'transportation':
        return BusinessCategory.transportation;
      case 'art_creative':
        return BusinessCategory.artCreative;
      case 'construction':
        return BusinessCategory.construction;
      case 'agriculture':
        return BusinessCategory.agriculture;
      case 'manufacturing':
        return BusinessCategory.manufacturing;
      case 'wedding_events':
        return BusinessCategory.weddingEvents;
      default:
        return null;
    }
  }
}
