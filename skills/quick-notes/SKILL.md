---
name: quick-notes
description: Capture, organize, and safely delete Quick Notes through the local Quick Notes MCP when a user explicitly asks to take something into Quick Notes, manage its notes, or manage its tags.
---

# Quick Notes

Use the `quick-notes` MCP server to work with the user's local Quick Notes library.

## When to use it

Use this skill when the user explicitly asks to save, capture, add, update, organize, review, or delete something in Quick Notes. Phrases such as “记入快记”, “记到 Quick Notes”, “Take into Quick Notes”, and “save this as a quick note” are clear requests to use it.

Do not create a note merely because information seems useful. Ask or wait for an explicit Quick Notes request. Do not use this skill for ordinary drafting, general advice, or notes intended for another system.

## Connection check

Before the first MCP call, confirm that the `quick-notes` server and its `quick_notes_*` tools are available. If they are not, tell the user to:

1. Open Quick Notes → Settings → MCP Server and enable the server.
2. Use the always-visible **Copy Configuration** button to add the copied JSON to the Agent's MCP settings.
3. Start a new Agent session or reconnect the MCP server.

Do not invent an executable path or pretend that Quick Notes is connected.

## Creating and updating notes

- Write note content in Markdown by default and pass `rendering_mode: "markdown"`. Preserve useful headings, lists, links, code fences, and quotations.
- Content must be meaningful and no longer than 5,000 characters. If the source is longer, make a concise Markdown note that retains the material facts, decisions, action items, and links. Do not silently truncate.
- Keep an explicitly supplied title. When no title is supplied, infer a compact descriptive title from the content; keep it within 25 characters and avoid generic titles such as “Notes” or “Summary”.
- Before creating or replacing tags, call `quick_notes_list_tags`. Compare the content with the returned tag names and attach the best one or two exact existing tags. Use no tag when none is a good fit. Do not invent, normalize, or case-adjust a tag value.
- Use `quick_notes_add_tag` only when the user specifically asks to create a new tag. Then call `quick_notes_list_tags` again before using the new tag.
- Use `quick_notes_create_note` for a new note. Use `quick_notes_update_note` only when the user identifies the existing note to change.

## Safe deletion

Deletion tools appear only after the user enables **Allow MCP Delete** in Quick Notes settings. Their absence means deletion is unavailable; do not try alternate mutations to simulate deletion.

- Delete a note only when the user explicitly supplies its exact `#<UUID>` identifier. Read notes first if needed to verify that identifier, then pass the UUID without `#` to `quick_notes_delete_note`. Never delete from a title, a search match, or an inferred identity.
- Delete a tag only when the user explicitly supplies its exact tag value. Pass that unchanged value to `quick_notes_delete_tag`. The tag must exactly match an existing tag and have no associated notes; the MCP server will reject tags that are still in use.
- Treat deletion as permanent. If the user's target is ambiguous, ask a short clarifying question instead of deleting.

## Installing this skill for Agents

In Quick Notes, open Settings → MCP Server and choose **Install for Agents**. The app installs the bundled skill into `~/.agents/skills/quick-notes` for that macOS user. To distribute it manually, choose **Save** to export `SKILL.md` as a Markdown document. MCP connection setup remains separate: use the always-visible **Copy Configuration** button to add the local server to the Agent, then restart or reconnect that Agent if it is already open.
