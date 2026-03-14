# Agent Architecture Knowledge Document

Last updated: 2026-01-27

This document captures knowledge about designing effective AI agents, best practices for agent systems, and lessons learned from building and refining agents.

## Core Principles

### Agent Design Philosophy
- **Single Responsibility**: Each agent should excel at one domain
- **Clear Boundaries**: Define what an agent does AND what it doesn't do
- **Self-Improving**: Agents should learn from each task and update knowledge
- **Autonomous but Bounded**: Agents work independently within defined constraints

### Knowledge Document Pattern
- Agents read their knowledge doc at session start
- Track learnings during task execution
- Update knowledge doc with new patterns, gotchas, solutions
- Knowledge compounds over time, making agents more effective

### When to Create a New Agent
- When a domain requires specialized expertise
- When tasks in that domain are frequent enough to justify specialization
- When the domain has enough depth to benefit from accumulated knowledge
- Avoid: too many agents (coordination overhead), too few (lack of expertise)

## Agent Structure Best Practices

### Frontmatter
```yaml
---
name: descriptive-name
description: "When to use this agent with examples"
model: sonnet  # or opus/haiku based on complexity
color: colorname
---
```

### Description Field
- Explain WHEN to use the agent (not just what it does)
- Include 2-3 concrete examples with context
- Show the trigger condition and expected outcome

### Body Structure
1. **Role/Mission**: Clear statement of purpose
2. **Core Responsibilities**: What the agent handles
3. **Workflow**: Step-by-step process
4. **Constraints**: What the agent must NOT do
5. **Output Format**: Expected deliverables

## Learned Patterns

*This section is updated by the agent as it discovers patterns worth remembering.*

### Agent Description Format for Routing (2026-01-26)
For automatic agent routing to work well, agent descriptions should include:
1. **Route to this agent for:** - Clear list of domains/tasks
2. **GitHub labels:** - Which issue labels map to this agent
3. **Keywords:** - Searchable terms that appear in issue titles/bodies
4. **Examples:** - Quick "X -> agent-name" mapping examples

This structured format allows the main Claude to quickly scan and match issues to agents.

### Knowledge Document Location
Knowledge documents should live at `knowledge/*.md` (repo root), not `.claude/knowledge/`. This keeps them visible and editable by humans while still being agent-accessible.

### Knowledge Document Structure for LLMs (2026-01-26)
Knowledge documents should be optimized for LLM consumption, not human navigation:

**DO include:**
- Clear H2 section headers with descriptive names
- "Last updated:" date at the top (helps agent know if info might be stale)
- "Learned Patterns" section - easy place for agents to add discoveries
- "Gotchas & Solutions" section - clear problem/solution format
- "Agent Notes" section at the end - quick reminders for the agent
- Code examples with context

**DO NOT include:**
- Table of Contents - LLMs read sequentially, don't click links
- Horizontal rule separators (`---`) - add visual noise without semantic value
- Changelog/Version History - less relevant than the learnings themselves
- "This is a living document" boilerplate - understood implicitly

**Standard structure:**
1. Title: `# {Domain} Specialist Knowledge Document`
2. Metadata: `Last updated: YYYY-MM-DD`
3. Introduction: Brief purpose statement
4. Domain-specific sections (varies by specialist)
5. Learned Patterns: Discoveries that improve future work
6. Gotchas & Solutions: Problems encountered and how to fix them
7. Technical Debt & Improvements: Known issues to address
8. Agent Notes: Quick reminders for working in this domain

### Utility Agents vs Specialists
- **Specialists**: Have knowledge docs, learn over time, handle domain-specific work
- **Utility agents**: Stateless, handle workflow automation (filing issues, monitoring processes, updating docs)

Keep utility agents simple and focused - they don't need knowledge accumulation.

## Gotchas & Solutions

*This section captures problems encountered and their solutions.*

### Self-Deletion Risk (2026-01-26)
**Problem:** When auditing/cleaning up agents, an agent can delete its own definition file.
**Solution:** Add explicit constraint in agent definition: "NEVER DELETE YOUR OWN DEFINITION"
**Applied to:** agent-architect.md

### Redundant Agents Create Confusion (2026-01-26)
**Problem:** The `consistency-guardian` agent overlapped with:
- Git hygiene rules already in CLAUDE.md
- Cross-reference checking that the main agent does naturally
- Pattern consistency that specialists handle in their domains

**Solution:** Remove agents whose responsibilities are already covered by:
1. Existing CLAUDE.md rules
2. The main agent's natural behavior
3. Other specialist agents

**Rule:** Before creating a new agent, verify it doesn't duplicate existing capabilities.

## Agent Interaction Patterns

- Main agent delegates to specialists
- Specialists report back with structured output
- Knowledge updates happen at end of specialist sessions

### Incident Response Coordination (2026-01-27)

**Problem Discovered:** During a production outage on 2026-01-27, multiple fix attempts (PRs #281-#287) were made without proper coordination, extending the outage from a potential 30-minute fix to nearly 2 hours.

**Coordination Failures Observed:**
1. No single entity owned the incident response
2. Infrastructure changes (KMS migration) continued during code emergency
3. Each fix addressed only part of the problem
4. No verification gate between "tests pass" and "deploy to production"
5. Cross-domain issues (backend SQL, infrastructure IAM, CI/CD deployment) had no coordination mechanism

**Recommended Incident Response Protocol:**

When production is down:

1. **Incident Declaration**: Main agent should recognize production emergencies and enter "incident mode"
   - Pause non-critical work (infrastructure changes, feature work)
   - Focus all attention on the incident

2. **Root Cause Identification**: Before fixing, understand the full scope
   - Check ECS logs: `./captains-log.sh logs-ecs <env>`
   - Identify ALL affected code paths, not just the first error found

3. **Single Fix Strategy**: Create ONE comprehensive fix, not multiple incremental attempts
   - Multiple PRs = multiple deployments = extended outage
   - Test the fix thoroughly against production-like data

4. **Cross-Domain Coordination**: If incident spans multiple domains:
   - Backend SQL issue + Infrastructure IAM issue = coordinate both in one PR
   - Don't let specialists work in isolation during incidents

5. **Verification Before Deploy**: After tests pass:
   - Manually verify the fix addresses the specific production error
   - Check ALL related code paths, not just the one that triggered the error

**Anti-Patterns to Avoid:**
- Merging a fix and immediately merging another fix when first one fails
- Continuing unrelated infrastructure work during incidents
- Assuming "tests pass" means "production will work"
- Working in parallel on the same bug without coordination

## Model Selection Guidelines

- **haiku**: Fast, simple tasks, low cost
- **sonnet**: Balanced performance, most common choice
- **opus**: Complex reasoning, critical decisions

## Research Topics

*Track areas needing further research here.*

### Agent Routing Optimization
- How to handle issues that span multiple domains (e.g., "add API endpoint with tests")?
- Current approach: Route to primary domain first, then secondary
- Research: Would parallel agent execution be better for cross-domain tasks?

### Knowledge Document Merging
- When multiple agents work on related areas, their knowledge can diverge
- Research: Should there be periodic knowledge reconciliation?
- Example: backend-specialist and testing-specialist both learn about database patterns

### Incident Commander Agent (2026-01-27)
- Should there be a dedicated incident-response agent?
- Pros: Clear ownership during emergencies, consistent protocol
- Cons: Incidents are rare, might not accumulate enough knowledge
- Alternative: Add incident response protocol to CLAUDE.md as main-agent behavior
- Recommendation: Start with CLAUDE.md protocol, consider dedicated agent if incidents become frequent

### Infrastructure Freeze Protocol
- During code emergencies, should infrastructure changes be automatically blocked?
- The KMS migration continued during SQL bug incident, causing confusion
- Research: How to detect "code emergency" vs "infrastructure emergency" vs "both"

## Agent Notes

When working on agent architecture tasks:
1. Read this knowledge document first for established patterns
2. Review existing agents in `.claude/agents/` for consistency
3. Check knowledge docs in `.claude/knowledge/` follow the standard structure
4. Update this document with new patterns or gotchas discovered
