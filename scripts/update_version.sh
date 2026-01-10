#!/bin/bash

# Version Update Script for Supper App
# Usage: ./scripts/update_version.sh <version_type> [description]
# version_type: major, minor, patch
# description: Optional description of changes

VERSION_TYPE=$1
DESCRIPTION=$2

if [ -z "$VERSION_TYPE" ]; then
    echo "Usage: ./scripts/update_version.sh <major|minor|patch> [description]"
    echo ""
    echo "Examples:"
    echo "  ./scripts/update_version.sh patch \"Fixed voice call bug\""
    echo "  ./scripts/update_version.sh minor \"Added new matching algorithm\""
    echo "  ./scripts/update_version.sh major \"Complete redesign\""
    exit 1
fi

# Get current version from pubspec.yaml
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}')
CURRENT_VERSION_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f1)
CURRENT_BUILD_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f2)

# Split version into parts
IFS='.' read -r -a VERSION_PARTS <<< "$CURRENT_VERSION_NUMBER"
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

# Increment based on type
case $VERSION_TYPE in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
    *)
        echo "Invalid version type. Use: major, minor, or patch"
        exit 1
        ;;
esac

# Increment build number
NEW_BUILD_NUMBER=$((CURRENT_BUILD_NUMBER + 1))
NEW_VERSION="$MAJOR.$MINOR.$PATCH+$NEW_BUILD_NUMBER"

echo "Current version: $CURRENT_VERSION"
echo "New version: $NEW_VERSION"
echo ""

# Update pubspec.yaml
sed -i "s/^version:.*/version: $NEW_VERSION/" pubspec.yaml

echo "Updated pubspec.yaml"
echo ""
echo "Next steps:"
echo "1. Update CHANGELOG.md with your changes"
echo "2. Review and commit: git add pubspec.yaml CHANGELOG.md"
echo "3. Commit: git commit -m \"Bump version to $NEW_VERSION\""
echo "4. Tag: git tag -a v$MAJOR.$MINOR.$PATCH -m \"Version $MAJOR.$MINOR.$PATCH\""
echo ""
echo "Or run this command to commit and tag:"
echo "git add pubspec.yaml CHANGELOG.md && git commit -m \"Bump version to $NEW_VERSION\" && git tag -a v$MAJOR.$MINOR.$PATCH -m \"Version $MAJOR.$MINOR.$PATCH - ${DESCRIPTION:-Update}\""
