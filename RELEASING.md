# Releasing OakLFGSorter

Build a CurseForge-ready zip with:

```powershell
.\package-release.ps1
```

What it does:

- reads the version from `OakLFGSorter.toc`
- creates `dist\OakLFGSorter-v<version>.zip`
- puts all addon files under the correct top-level folder `OakLFGSorter\`
- excludes repo-only and local helper files like `.git`, `.gitignore`, browser temp profiles, PDFs, and packaging scripts

Optional examples:

```powershell
.\package-release.ps1 -Version 1.6.2
.\package-release.ps1 -OutputDir C:\Users\YourName\Desktop\OakReleases
```

Typical release flow:

1. Update `## Version:` in `OakLFGSorter.toc`
2. Test in-game
3. Commit and push to GitHub
4. Run `.\package-release.ps1`
5. Upload the generated zip from `dist\` to CurseForge
