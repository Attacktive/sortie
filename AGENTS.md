# Sortie — Agent Instructions

Read these before changing anything:

- `README.md`: how to run and test, the architecture, and the code map.
- The [design notes](docs/DESIGN-NOTES.md): decisions, risks, and bug history.

This file covers only what neither of them does: how work is divided between agents, and where the documents they exchange live.

## How work is divided

Three agents work on this repository. The owner merges every pull request; no agent ever does.

- A **plotting agent** writes narrative: story arcs, character voices, and dialogue. It has no repository access, so whoever receives its output saves it under `docs/superpowers/specs/`.
- A **coding agent** implements from a coding brief. It writes the technical spec and the plan, then the code, tests, and pull requests.
- A **reviewing session** (Claude Code) checks the other agents' output against the engine and the repository conventions, and writes the briefs and prompts they consume. It does not implement features unless asked.

When the owner says "give me the prompt", the deliverable is a self-contained prompt with the verified facts inline. The receiving agent may have neither repository access nor these conventions.

Whichever role you hold: open the pull request, wait for its checks, report the result, and stop.

## Where briefs and specs live

- **Story specs** from the plotting agent: `docs/superpowers/specs/<date>-sortie-<topic>-story.md`. On dialogue, cells, stats, and maps, the story spec is the source of truth.
- **Coding briefs** for the coding agent: `docs/superpowers/<date>-<topic>-coding-brief.md`. A brief maps a story spec onto the engine and rules on every point the spec leaves open; on engine representation it is the source of truth.
- **Technical specs and plans**, written by the coding agent: `docs/superpowers/specs/<date>-sortie-<topic>-design.md` and `docs/superpowers/plans/<date>-sortie-<topic>.md`, following the pattern of the first six sub-projects.

A brief and its story spec stay untracked on `main` until the coding agent's first, documents-only pull request commits them. If you find them untracked, that pull request has not landed; do not commit them from another branch.
