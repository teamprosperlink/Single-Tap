---
paths:
  - "lib/screens/business/**"
  - "lib/widgets/business/**"
  - "lib/models/business_item.dart"
  - "lib/models/dashboard_config.dart"
  - "lib/config/business_features_config.dart"
  - "lib/config/dashboard_templates.dart"
  - "lib/services/business_item_service.dart"
---

# Business Dashboard Patterns

## Directory Structure
- lib/screens/business/dashboard/ — Dashboard screens
- lib/screens/business/dialogs/ — Business dialogs
- lib/screens/business/edit/ — Edit screens
- lib/screens/business/items/ — Item management
- lib/screens/business/sections/ — Dashboard sections
- lib/screens/business/setup/ — Setup flows
- lib/screens/business/utils/ — Utility functions
- lib/screens/business/widgets/ — Business-specific widgets
- lib/widgets/business/ — Shared business widgets

## Key Models
- BusinessItem (lib/models/business_item.dart)
- DashboardConfig (lib/models/dashboard_config.dart)
- SectionConfig (lib/models/section_config.dart)
- ClassModel, CourseModel, MembershipModel

## Configuration
- BusinessFeaturesConfig (lib/config/business_features_config.dart)
- DashboardTemplates (lib/config/dashboard_templates.dart)
