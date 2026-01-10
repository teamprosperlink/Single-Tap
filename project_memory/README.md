# 📚 PROJECT MEMORY SYSTEM

## How to Use This Memory System

### Structure
```
project_memory/
├── PROJECT_MEMORY.md         # Current state (always up-to-date)
├── README.md                  # This file (instructions)
└── versions/                  # Historical snapshots
    ├── v1.0.0_2025-09-11.md  # Version 1.0.0 snapshot
    ├── v1.1.0_2025-09-XX.md  # Future versions...
    └── ...
```

### Version Naming Convention
Format: `v{major}.{minor}.{patch}_{YYYY-MM-DD}.md`

- **Major**: Big changes (new features, architecture changes)
- **Minor**: Improvements, bug fixes
- **Patch**: Small fixes, documentation updates
- **Date**: When the snapshot was taken

### When to Create New Version
1. **Before major changes**: Save current working state
2. **After completing features**: Document what was added
3. **Before risky modifications**: Backup current state
4. **When user requests**: "Save this version"

### How to Restore Previous Version
1. User says: "Go to version 1.0.0"
2. Read the version file: `versions/v1.0.0_2025-09-11.md`
3. Check what was working in that version
4. Restore code to match that state
5. Update PROJECT_MEMORY.md with restored version

### What to Include in Each Version
- ✅ Current features working
- ✅ Files created/modified
- ✅ Dependencies and versions
- ✅ Configuration and API keys
- ✅ Known issues and fixes
- ✅ Build information
- ✅ Testing status

### Commands for Version Management
- **Save current state**: Create new version file
- **List versions**: Show all files in versions/
- **Compare versions**: Show differences between versions
- **Restore version**: Revert to specific version
- **View version**: Read specific version file

### Important Rules
1. **Never delete version files** - They are historical records
2. **Always update PROJECT_MEMORY.md** - Keep it current
3. **Create version before big changes** - Safety first
4. **Document everything** - Future reference

### Current Version
**v1.0.0** - WebRTC Voice Calling Implementation (Sept 11, 2025)

### Version History
- **v1.0.0** (2025-09-11): Initial WebRTC implementation, all call features working

---

## Quick Commands

```bash
# View current state
cat project_memory/PROJECT_MEMORY.md

# List all versions
ls project_memory/versions/

# View specific version
cat project_memory/versions/v1.0.0_2025-09-11.md

# Create new version (example)
cp PROJECT_MEMORY.md versions/v1.1.0_2025-09-12.md
```

---

**Remember**: This system helps track project evolution and allows easy rollback to any previous working state!