---
name: learning-a-tool
description: Create learning paths for programming tools, and define what information should be researched to  create learning guides. Use when user asks to learn, understand, or get started with any programming tool, library, or framework.
---

# Learning a Tool

Create comprehensive learning paths for programming tools.

## Workflow

### Phase 1: Research

Gather information from three sources. Research each source independently, then aggregate findings.

#### From Official Documentation

- Official docs URL and current version
- The motivation behind the tool
- What problem does it solve / what does it help with
- What types of applications can be built using the tool
- Use cases
- Installation steps and prerequisites
- Core concepts (3-5 fundamental ideas)
- Official code examples
- Getting started or tutorial content
- API reference highlights
- Known limitations or caveats

#### From the Repository

- Repository URL and metadata (stars, last commit, license)
- Core system architecture (configuration, data processing flow, ...)
- README quick start section
- Examples folder contents (what each example demonstrates)
- Concise summary of the project's main function and the technologies used

#### From Community Content

- Top tutorials (title, author, URL, why it's valuable)
- Video resources (title, channel, duration)
- Comparison articles (vs alternatives, key tradeoffs)
- Common gotchas and mistakes people mention
- Community channels (Discord, Reddit, forums)
- Real-world use cases and testimonials

### Phase 2: Structure

Organize content into progressive levels. `references/progressive-learning.md` is the source of truth.

You MUST create exactly 5 levels in this order:

1. Level 1: Overview & Motivation
2. Level 2: Installation & Hello World
3. Level 3: Core Concepts
4. Level 4: Practical Patterns
5. Level 5: Next Steps

Do NOT merge, skip, or rename levels. Each level's content requirements are defined in the reference file.

### Phase 3: Output

Generate the learning path folder. **Write one file at a time.** Do NOT try to generate multiple large files in a single step.

## Output Format

**IMPORTANT**: Create the output folder in the **project root directory** (the workspace root), NOT inside the `.claude/` folder or the skill folder. The very first step must be to `cd` to the project root or use absolute paths.

The final folder structure (relative to the project root):

```
learning-{tool-name}/
├── README.md           # Overview and how to use this learning path
├── resources.md        # All links organized by source (official, community)
├── learning-path.md    # Main content following the five levels
└── code-examples/      # Runnable code for each section
    ├── 01-hello-world/
    ├── 02-core-concepts/
    └── 03-patterns/
```

### Writing Strategy

To avoid timeouts on large files, write the learning path as **separate level files first**, then merge them into a single `learning-path.md` at the end.

You MUST write files **one at a time**, in this order:
1. Create the directory structure first (single Bash command)
2. Write `README.md`
3. Write `resources.md`
4. Write `_00-intro.md` (temporary) — title and table of contents (see format below)
5. Write `_01-overview-and-motivation.md` (temporary)
6. Write `_02-installation-and-hello-world.md` (temporary)
7. Write `_03-core-concepts.md` (temporary)
8. Write `_04-practical-patterns.md` (temporary)
9. Write `_05-next-steps.md` (temporary)
10. Write code example files (one file per Write call)
11. **Merge and clean up**: Concatenate all temporary files into `learning-path.md`, then delete them:
    ```bash
    cat _00-intro.md _01-overview-and-motivation.md _02-installation-and-hello-world.md _03-core-concepts.md _04-practical-patterns.md _05-next-steps.md > learning-path.md && rm _00-intro.md _01-overview-and-motivation.md _02-installation-and-hello-world.md _03-core-concepts.md _04-practical-patterns.md _05-next-steps.md
    ```

**NEVER combine multiple files into a single Write call. NEVER skip a file.**

### Heading and Formatting Rules for Temporary Level Files

Because the temporary files are concatenated into a single `learning-path.md`, they must follow these rules so the merged file reads as one cohesive document:

1. **`_00-intro.md`** must contain:
   - A top-level heading: `# {Tool Name} Learning Path`
   - A brief intro paragraph
   - A table of contents linking to the 5 levels using markdown anchors

2. **Each level file (`_01` through `_05`)** must:
   - Start with `## Level N: {Title}` (second-level heading, NOT first-level)
   - Use `###` for subsections within the level
   - End with a horizontal rule (`---`) and a blank line (for clean separation when merged)
   - **NOT** include "Next" links — the table of contents in the intro handles navigation

3. **Do not repeat the tool name as a heading** inside level files — the intro already has the top-level heading.
