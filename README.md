# Skills and Agents with the Anthropic Claude Agent SDK

## About

This example uses the Anthropic Claude Agent SDK to automatically generate comprehensive learning guides for any programming tool, library, or framework. It is a multi-agent system that includes a `learning-a-tool` skill and 3 subagents for documentation research, repository analysis, and web research capabilities. It generates a learning guide similar to the example in the `EXAMPLE-learning-postgresql` folder.

## Skills and Agents

In Anthropic Claude, skills are predefined, general instructions or capabilities that are automatically applied by the model wrapper as it constructs the prompt based on the user request. You don't call skills explicitly; the wrapper decides when a skill should be included (for example, summarizing, extracting structured data, or enforcing a response format) and applies it transparently in the background. Skills do not plan, track history, or pursue goals, they simply shape how the model responds when triggered. In Claude's ecosystem, skills reflect an emerging open-source standard for modular, reusable model behavior, and this pattern is increasingly being adopted by other major providers in compatible forms. Agents are different: they explicitly manage state, reason over multiple steps, and decide which skills or tools to use and in what order. In short, skills are automatic behavior rules, while agents are active decision-makers.

In the Anthropic Claude Agent SDK, skills are added as self-contained folders inside a required top-level `.claude` folder. Each skill lives in its own subfolder, and the subfolder name must exactly match the skill name referenced in the prompt, so the model wrapper can resolve and load it correctly. Every skill includes a mandatory `SKILL.md` file, which defines the skill's purpose, scope, triggers, and behavioral rules in clear, model-readable language. Subfolders can contain supporting assets such as prompt fragments, examples, schemas, configuration files, or scripts for validation or tool integration. Skills can also be structured so that additional files are loaded progressively only when needed, keeping prompts small, reducing cost and noise, and ensuring the model only sees extra context when it is actually relevant, which improves reliability and performance.

This example contains a skill with the name `learning-a-tool`. This skill progressively loads the content of `references/progressive-learning.md` when needed.

This example uses three subagents: `docs_researcher`, `repo_analyzer`, and `web_researcher`.

![alt text](https://github.com/user-attachments/assets/2b44c35f-c83d-4fb1-9c4b-8435dae8db30 "Learning advisor")

## Required API key for this example

You need an Anthropic API key for this example. [Get your Anthropic API key here](https://platform.claude.com/login). Insert the Anthropic API key into the `.env.example` file and then rename this file to just `.env` (remove the ".example" ending).

### Claude Large Language Model (LLM) versions

This example uses Claude "haiku" as the LLM for each subagent, while using "sonnet" for the main agent only. You might getter better results for the subagents with Claude "sonnet" (3 times more expensive), or Claude "opus" (5 times more expensive). The more expensive Claude versions might follow instructions more strictly.

Because this example fetches data from external sources in an uncontrolled order, it can sometimes encounter errors when information is unavailable or cannot be processed. This is expected. In such cases, this example automatically retries and skips the item if retries fail. Only when no other information is available does it fall back to the LLM's built-in knowledge.

## Running the Agent

```bash
python agent.py
```

Once running, type your messages and press Enter. Type `exit` to quit.

### Example prompts

**Step 1:** Start the research process by typing the following instructions. You can replace "PostgreSQL" with any learning topic of your choice.

```bash
Help me get started with PostgreSQL. Create a learning guide. Show me your plan first.
```

**Note:** The execution will take multiple minutes to complete. You can update the skill's instructions and agent definitions if you want faster research or a simpler learning guide.

**Step 2:** Review and approve the plan

You can agree with the plan by typing `yes`. This will start the learning guide generation. Alternatively, you can provide feedback and suggestions to improve the plan before you accept the updated plan by typing `yes`.
