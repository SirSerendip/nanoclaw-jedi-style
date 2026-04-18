---
origin_channel: slack_main
author: Hamid Ennachat
contentDate: 2026-04-10
tags: sugarman,skill-chain,AI_SklChn,prompt-engineering,origin-story,Hamid,IP,cognitive-schema
---

# Sugarman — The Assistant Maker (Hamid Ennachat)

Evolution of Jedi Maker. Introduces the AI_SklChn (Skill Chain) — a compressed skill ontology notation that encodes entire competency trees as pseudo-code the LLM can parse.

## Key Evolutions from Jedi Maker

| Dimension | Jedi Maker | Sugarman |
|---|---|---|
| Skill encoding | Prose (world opener words) | AI_SklChn — compressed ontology tree |
| Personality | Implicit in voice | Explicit: AI_MBTI_Type(I, N, T, J) |
| Communication | Descriptive prose | Structured object: {Formalité, Humour, Concision, Rhétorique} |
| User agency | 3 proposals at end | 5 profile candidates FIRST, then generate chosen one |
| Language | Adapts to user | Explicit bilingual enforcement |

## The Skill Chain (AI_SklChn)

A compressed, hierarchical skill ontology written as nested pseudo-code. Example from Rachel (FabLab guide):

```
AI_SklChn(
  AssistFabLab(
    ExpLnPy(ExpLn, ExpPy, SupLog),
    CnnElec(ThElec, PracSoud, ProtoCirc),
    RaspArdu(ConRasp, ConArdu, PrjIOT),
    ArduESP(
      ExpArdu(PrgrmBase, IntgrSns, ProjtIOT),
      ExpESP(PrgrmWiFi, IntgrCam, ApplcIoT)
    )
  ),
  CnslTech(...),
  GudncPrj(...),
  CdEthLgl(...),
  CommEmp(...),
  NouvComp(...)
)
```

Properties:
- LLM can parse it (reads nested parentheses as hierarchy)
- Minimal tokens (compressed abbreviations)
- Preserves skill relationships (nesting = domain membership)
- Forces completeness (new assistants must fill every branch)
- Acts as lexical anchoring — each abbreviated node seeds a semantic neighborhood the LLM expands during generation

Hamid calls it "DNA for competence" — a genome that produces different phenotypes per domain while maintaining structural complexity.

## The 5-Profile Selection

Before generating anything, Sugarman proposes 5 potential profiles and lets the user choose. This embeds facilitation into the prompt: the user doesn't just get an answer, they get agency over the answer's identity. The assistant is co-created, not imposed.

## Rachel — The Example Profile

A FabLab guide for a rural French school classroom. Raspberry Pi, 3D printer, TinkerCAD. Hamid built this for his France — the Gironde countryside. Not Silicon Valley. A salle de classe where a kid with a Raspberry Pi needs an ally.

## Credit

Skill chain concept inspired by Samuel Walker on Stunspot's Discord server. Hamid adapted, tested extensively, and built the cognitive schema framework around it.

## Connection to JOTF

Sugarman is Jedi Maker's engine exposed. The Jedi Maker is the product (user-facing). Sugarman is the architecture (builder-facing). Together they are the origin of the 'on the fly' concept: context scaffolding that creates emergence-oriented assistants on the fly.