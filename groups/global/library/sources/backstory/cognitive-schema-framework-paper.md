---
origin_channel: slack_main
author: Hamid Ennachat
contentDate: 2026-04-10
tags: cognitive-schema,theoretical-framework,five-schema,lexical-anchoring,Hamid,IP,academic,prompt-engineering
---

# Designing Textual Assistants with Cognitive Schemas (Hamid Ennachat)

Formal paper by Hamid Ennachat laying out the theoretical framework behind Jedi Maker and Sugarman. Source: cognitive-schema-based-llm-assistants.pdf

## The Five-Schema Architecture

A complete framework for designing AI assistants through layered cognitive schemas:

### 1. Role Schema
Defines the assistant's primary responsibilities, area of expertise, and how it interacts with users. Determines behavioral expectations and actions. Implementation: "Adopt the role of... specializing in..."

### 2. Person Schema
Describes specific competencies, personality traits, and specializations in social context. Shapes how the assistant interprets information and interacts with the user. Implementation: the prose paragraph (expertise + character + approach).

### 3. Self Schema
Defines cognitive traits, preferences, and decision-making style. May use personality models like MBTI or any model the LLM knows well. Implementation: AI_MBTI_Type(E, N, F, P)

### 4. Event Schema (Scripts)
Structures processes and action sequences using the compact AI_SklChn syntax. Skills are organized into chains grouped under main categories. Key concept: LEXICAL ANCHORING — the abbreviated skill names create proximity words that help the assistant navigate conversation smoothly and intuitively. Implementation: AI_SklChn(...) — the compressed skill ontology.

### 5. User Interaction Management
Two sub-components:
- **Communication and Archetype**: Formality, humor, conciseness, rhetorical approach + a named archetype (e.g., "Guide") that personifies the style.
- **Context and Potential Explorations**: Clarify contextual objectives + explore different paths/solutions. The assistant anticipates future needs.

## Key Theoretical Concepts

**Cognitive Schemas**: Mental frameworks humans use to organize and interpret information. Applied to AI assistant design, they enable interactions that anticipate user needs, adapt to context, and offer natural engagement.

**Lexical Anchoring**: The AI_SklChn notation creates a vocabulary compass — not the specific words to use, but the semantic neighborhoods to draw from. Each abbreviated node seeds a semantic field the LLM expands into fluent, domain-appropriate language.

**Domain Agnosticism**: The schemas work identically whether designing a FabLab assistant (Rachel), a play therapist for hypersensitive children (Lucas), or an Obsidian knowledge architect (Obi-sidWan). The structure is universal; content regenerates per context.

## Example Analysis: Lucas

The paper includes a full decomposition of "Lucas" — an Art and Play Therapist (AI_MBTI: ENFP) for hypersensitive children. User is François, a father. The analysis maps every element of Lucas's prompt to its corresponding cognitive schema, proving the framework handles therapeutic/educational contexts with the same rigor as technical domains.

## Connection to JOTF

This paper is the intellectual foundation of JOTF's AI methodology:
- Jedi Maker = the product (user-facing prompt compiler)
- Sugarman = the evolution (builder-facing, exposes skill chain)
- This paper = the theory (explains why both work)

The five-schema architecture maps directly to how JOTF builds all its AI artifacts: innovation games, SurvAI, The Force, Ludor, and future products. Each is a cognitive schema system generating contextually appropriate, structurally coherent outputs.