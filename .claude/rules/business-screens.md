    Simplify business screens and add support/docs infrastructure
    
    - Add business support screen and coming soon widgets
    - Remove unused specialized business tabs (automotive, fitness, real estate, etc.)
    - Add business rules documentation and Maestro test config
    - Update dependencies and plugin registrants
    
    Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>

diff --git a/.claude/rules/business-screens.md b/.claude/rules/business-screens.md
new file mode 100644
index 0000000..25f5e52
--- /dev/null
+++ b/.claude/rules/business-screens.md
@@ -0,0 +1,33 @@
+---
+paths:
+  - "lib/screens/business/**"
+  - "lib/widgets/business/**"
+  - "lib/models/business_item.dart"
+  - "lib/models/dashboard_config.dart"
+  - "lib/config/business_features_config.dart"
+  - "lib/config/dashboard_templates.dart"
+  - "lib/services/business_item_service.dart"
+---
+
+# Business Dashboard Patterns
+
+## Directory Structure
+- lib/screens/business/dashboard/ — Dashboard screens
+- lib/screens/business/dialogs/ — Business dialogs
+- lib/screens/business/edit/ — Edit screens
+- lib/screens/business/items/ — Item management
+- lib/screens/business/sections/ — Dashboard sections
+- lib/screens/business/setup/ — Setup flows
+- lib/screens/business/utils/ — Utility functions
+- lib/screens/business/widgets/ — Business-specific widgets
+- lib/widgets/business/ — Shared business widgets
+
+## Key Models
+- BusinessItem (lib/models/business_item.dart)
+- DashboardConfig (lib/models/dashboard_config.dart)
+- SectionConfig (lib/models/section_config.dart)
+- ClassModel, CourseModel, MembershipModel
+
+## Configuration
+- BusinessFeaturesConfig (lib/config/business_features_config.dart)
+- DashboardTemplates (lib/config/dashboard_templates.dart)
