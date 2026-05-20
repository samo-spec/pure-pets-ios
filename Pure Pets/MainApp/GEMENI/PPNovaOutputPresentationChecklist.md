# Nova Output Presentation Manual Regression Checklist

Scope: Nova UI presentation and table-view stability only. Do not validate backend, prompt, search, or content decisions with this checklist.

1. Open Nova from the customer app and confirm the empty state remains centered.
2. Send one text message.
3. Confirm the user bubble inserts once, keeps its width after scroll, and does not trigger a full table reload loop.
4. Receive one assistant text reply.
5. Confirm the assistant bubble stays connected to the current turn, keeps the correct width, and does not flip into old content when scrolling.
6. Receive a card result from real retrieved IDs.
7. Confirm the card row appears below the assistant text, uses the correct product/ad/adoption/vet/service cards, and does not push or replace old bubbles.
8. Send a second message.
9. Confirm old card rows keep their content and the new turn does not inherit previous cards.
10. Open and close the keyboard.
11. Confirm bottom inset, empty state, and latest visible row move smoothly without clipping or jumping.
12. Scroll up and down through at least three Nova turns.
13. Confirm no cell flips, no clipped bubble/card widths, no wrong reused card content, and no repeated full table reload diagnostics.

Expected diagnostic signal:
- `[PPNovaChat][TableUpdate]` logs include `messageId`, `outputType`, `reuseIdentifier`, `renderKey`, `row`, and `reason`.
- Card rows with missing real IDs log `card_output_missing_real_id` and must not render fake cards.
