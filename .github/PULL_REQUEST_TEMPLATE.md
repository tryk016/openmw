## Summary

<!-- Explain what this changes and why it is needed for the iOS port. -->

## Roadmap

<!-- Every PR must update the canonical roadmap in the same PR. -->

- [ ] I updated `docs/ios-port/ROADMAP.md`.
- Completed roadmap item(s):
  - <!-- Paste the exact item text or link to the relevant section. -->

## Fork and target safety

- [ ] The base repository is `tryk016/openmw`.
- [ ] The base branch is `ios/main`.
- [ ] This PR does not target `OpenMW/openmw`.
- [ ] The change is intentionally iOS/iPadOS-only and keeps the deployment
      target at exactly **16.4**, unless a separate accepted ADR changes it.

## Validation

<!-- Link Actions runs and describe every command or repeatable manual test. -->

- GitHub Actions run:
- Simulator result:
- Additional checks:

### Physical device evidence

<!--
Required for runtime-affecting changes. For a change that cannot affect runtime,
write "Not applicable", explain why, and link the relevant CI evidence.
Do not include device identifiers, Apple account details, signing material, or
private filesystem paths.
-->

| Field | Evidence |
|---|---|
| Device model | |
| iOS/iPadOS version | |
| Build commit SHA | |
| Installation method (SideStore/Xcode) | |
| Scenario and duration | |
| Result (pass/fail/blocked) | |
| Test date | |
| Sanitized log/crash report/screenshot link | |
| Metrics (FPS/frametime/RAM/thermal, or justified N/A) | |

Select exactly one:

- [ ] Runtime change: the physical-device evidence above is complete.
- [ ] Non-runtime change: device testing is not applicable and the reason is
      recorded above.

## Data, secrets, and licenses

- [ ] No Morrowind/Bethesda game files or assets, saves, or screenshots
      containing private user data are included; visual test evidence is
      sanitized.
- [ ] No Apple ID details, certificates, private keys, provisioning profiles,
      SideStore pairing files, tokens, credentials, or other secrets are
      included.
- [ ] Logs and artifacts were checked for private paths, device identifiers,
      account data, and secrets.
- [ ] New or changed dependencies have pinned versions/hashes, license notices,
      and SBOM updates where applicable.

## Risks and follow-up

<!-- List known regressions, blockers, rollback steps, or follow-up issues. -->
