# Release workflow

For every SOLARIT game update, complete the full release path unless the user explicitly asks for a local-only change:

1. Bump the version consistently in `data/update_history.json`, `export_presets.cfg`, and `installer/SOLARIT-RANDSEKTOR-07.iss`.
2. Add a dated `Updateinfo` entry describing the user-visible changes. Keep the in-game installed-version and new-version labels accurate.
3. Run the relevant focused tests and the full `Test-Solarit.ps1` regression suite.
4. Commit and push the source to GitHub, then create and push the matching `v<version>` tag to trigger the Windows release workflow.
5. Wait for GitHub Actions to succeed. Verify the public GitHub release includes the new Windows installer, SHA-256 file, and release manifest before reporting it as available.

Do not report an installer as released until the workflow and uploaded assets have been verified. Keep release version, Updateinfo, exported executable metadata, installer name, and Git tag in sync.
