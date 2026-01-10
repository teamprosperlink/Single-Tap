# Version Management Guide

## Current Version
**v1.0.0+1** (as of 2025-11-14)

## Version Format
```
MAJOR.MINOR.PATCH+BUILD
Example: 1.0.0+1
```

- **MAJOR**: Breaking changes or major new features (1.x.x)
- **MINOR**: New features, backwards compatible (x.1.x)
- **PATCH**: Bug fixes and minor improvements (x.x.1)
- **BUILD**: Internal build number, increments with every release (x.x.x+1)

## Semantic Versioning Rules

### When to increment MAJOR (1.x.x → 2.x.x)
- Breaking API changes
- Complete redesign
- Major architectural changes
- Incompatible with previous versions

### When to increment MINOR (x.1.x → x.2.x)
- New features added
- Significant improvements
- New functionality that's backwards compatible
- Examples: new matching algorithm, new screen, major UI update

### When to increment PATCH (x.x.1 → x.x.2)
- Bug fixes
- Performance improvements
- Small UI tweaks
- Security patches
- Examples: fixing voice call bug, improving load times

### When to increment BUILD (+1 → +2)
- Every single release (even for testing)
- Internal builds
- Always increments

## Quick Update Commands

### Using the update script (Windows):
```bash
# For bug fixes
scripts\update_version.bat patch "Fixed voice call profile display bug"

# For new features
scripts\update_version.bat minor "Added video calling feature"

# For breaking changes
scripts\update_version.bat major "Redesigned entire app architecture"
```

### Manual update:
1. Edit `pubspec.yaml` - update the version line
2. Update `CHANGELOG.md` - document your changes
3. Commit and tag:
```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "Bump version to 1.0.1+2"
git tag -a v1.0.1 -m "Version 1.0.1 - Bug fixes"
```

## Version History

All versions are tracked in:
- **Git tags**: `git tag -l` to see all versions
- **CHANGELOG.md**: Detailed change history
- **Git commits**: Full development history

## Release Workflow

1. **Make your changes** and test thoroughly
2. **Decide version type**: major, minor, or patch
3. **Run update script** or manually update version
4. **Update CHANGELOG.md** with your changes
5. **Commit changes**:
   ```bash
   git add .
   git commit -m "Your commit message"
   ```
6. **Tag the version**:
   ```bash
   git tag -a v1.0.1 -m "Version 1.0.1 - Description"
   ```
7. **Push to remote** (when ready):
   ```bash
   git push origin master
   git push origin --tags
   ```

## View Version History

```bash
# List all version tags
git tag -l

# View specific version details
git show v1.0.0

# View version history with dates
git log --tags --simplify-by-decoration --pretty="format:%ai %d"

# Compare versions
git diff v1.0.0 v1.0.1
```

## Best Practices

1. **Always update CHANGELOG.md** when changing version
2. **Never skip build numbers** - they should always increment
3. **Tag immediately after release commits**
4. **Use descriptive tag messages**
5. **Test before tagging** - tags represent stable releases
6. **Keep version in sync** across pubspec.yaml and git tags

## Current Status
- Git repository: **Initialized**
- Git user: **Kiran** (kiranimmadi2@gmail.com)
- Initial commit: **Created**
- Version tag: **v1.0.0**
- Version scripts: **Ready**
