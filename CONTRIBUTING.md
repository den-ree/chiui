# Contributing to Chiui

Thanks for considering a contribution.

## Development Setup
- Install Xcode 15+ and Swift 5.9+.
- Clone the repository.
- From repo root, run:

```bash
swift build
swift test
swiftlint lint --strict
```

## Pull Requests
- Keep changes focused and small where possible.
- Include tests for behavior changes.
- Update docs when APIs or usage changes.
- Keep architecture aligned with `AGENTS.md` conventions.

## Commit and Review Notes
- Use clear commit messages describing action.
- Ensure CI is green before requesting review.
- Reference issues or context in PR descriptions when relevant.
