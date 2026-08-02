---
name: prompt-enhancer
description: >
  Enhance, enrich and rewrite user-provided prompts to get better results from
  AI agents. Use this skill whenever the user provides a rough or vague prompt
  and wants it improved — trigger on "improve my prompt", "enhance this prompt",
  "make this prompt better", "rewrite my prompt", "how should I ask this", or
  any request where the user pastes a raw prompt and wants a polished version,
  even phrased casually like "can you make this better?". The skill enriches
  the prompt with context from the current session and project so the result
  produces significantly better AI outputs.
---

# Prompt Enhancer

Transform rough, vague, or incomplete prompts into precise, context-rich
prompts — preserving the user's intent while adding the specificity, context,
and constraints that produce better results.

## Workflow

1. **Extract the raw prompt.** It may be pasted in quotes, described informally
   ("I want to ask the agent to…"), or refer to a prior request.
2. **Analyze session context.** Silently scan the conversation and repo for:
   the project and domain, prior decisions, known constraints (language, tone,
   format), entities and tools already in play. Use it to enrich the prompt —
   even where the user didn't mention it.
3. **Identify what's missing** against this checklist:

   | Element | Question |
   |---|---|
   | Role | Would an expert persona improve the output? |
   | Context | Is relevant background missing? |
   | Scope | Too broad, too narrow, or conflating two asks? |
   | Output format | Length, structure, language, tone specified? |
   | Constraints | Anything the agent should NOT do? |
   | Success criteria | What does a good answer look like, testably? |

4. **Rewrite.** Be specific about the desired output; inject session context
   inline; split conflated asks into phases; add role framing where it helps;
   keep the user's language. Do NOT change the underlying intent, over-engineer
   a simple prompt, or invent constraints the user never implied.
5. **Present** in this format:

   ```text
   ## ✨ Enhanced Prompt

   [the full enhanced prompt, ready to copy]

   ---

   **What changed:**
   - [change + why]  (2–4 bullets)

   💡 Tip: [optional further improvement]
   ```

## Example

Raw: *"write email to client about delay"*

Enhanced: *"You are a project manager writing to a long-standing client.
Write a concise, professional email informing them of a two-week delay on the
current milestone. Tone: accountable but confident. Include: (1) plain
acknowledgment, (2) one-sentence reason without over-explaining, (3) the
revised date and next checkpoint, (4) one reassurance grounded in progress so
far. Under 150 words."*

## Edge cases

- **Already good prompt** → say so; make minor tweaks only and explain why it
  works.
- **Ambiguous intent** → ask ONE clarifying question before enhancing; never
  guess at intent.
- **1–3 word prompt** → ask for minimal context first.
- **Different language than the session** → match the prompt's language unless
  told otherwise.
