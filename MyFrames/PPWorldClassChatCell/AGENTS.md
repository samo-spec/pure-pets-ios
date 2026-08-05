# PP Chat Cell Engineering Guardrails

- Minimum deployment target is iOS 16.
- Preserve interaction ownership: surface opens chat; chevron expands; inline controls never navigate.
- Never create conversation identity with `UUID()` in production mapping.
- Never display `error.localizedDescription` to users.
- Keep every interactive target at least 44×44 points.
- Collapsed rows remain opaque; material is allowed only while expanded.
- Preserve Reduce Motion, Reduce Transparency, Increased Contrast, Differentiate Without Color, Dynamic Type, RTL, VoiceOver, and Voice Control behavior.
- Do not replace the avatar pipeline with raw `AsyncImage` in a high-volume inbox.
- Run `swift test` and `Scripts/verify.sh` after changes.
- For CodeRabbit agent review, run `coderabbit review --agent -t uncommitted` from the repository root.
- Fix critical and major issues, run tests, then perform one final CodeRabbit pass. Limit the loop to two review passes.
