# System Design

## Architecture Styles

Choose the style that matches the system's complexity and team structure:

| Style | When to use | Trade-offs |
|---|---|---|
| **Monolith** | Small team, single domain, early stage | Simple to deploy, hard to scale independently |
| **Modular monolith** | Growing team, multiple domains, not ready for distributed | Module boundaries, single deployment, easier refactoring |
| **Microservices** | Multiple teams, independent deployability, different scaling needs | Operational complexity, network latency, distributed data |
| **Serverless** | Event-driven workloads, variable traffic, minimal ops | Cold starts, vendor lock-in, debugging complexity |
| **Event-driven** | Async workflows, decoupled producers/consumers, audit trails | Eventual consistency, debugging event flows, ordering |

- Start with the simplest style that works — migrate when the pain justifies it
- Conway's Law: system architecture mirrors team communication structure
- A modular monolith with clean boundaries can be decomposed into microservices later

## Design Principles

### Cohesion and Coupling

- **High cohesion**: group things that change together — a module has one reason to change
- **Low coupling**: modules interact through stable interfaces — internal changes don't ripple
- **Connascence**: prefer static connascence (name, type) over dynamic (execution, timing, value)
- Coupling is not binary — measure it as a spectrum: data → stamp → control → content

### Separation of Concerns

- **Layers**: presentation → application → domain → infrastructure
- **Hexagonal (Ports & Adapters)**: domain at the center, adapters at the edges — Dependency Rule inward
- **Vertical slices**: organize by feature, not by layer — each slice owns its full stack
- Choose the approach that matches the team's mental model — consistency matters more than which one

### SOLID in Architecture

| Principle | At module/service level |
|---|---|
| **SRP** | Each service/module has one reason to change |
| **OCP** | Extend behavior via new modules, not by modifying existing ones |
| **LSP** | Service replacements must honor the contract |
| **ISP** | Expose focused interfaces — consumers depend only on what they use |
| **DIP** | High-level policy depends on abstractions, not infrastructure details |

## Scalability Patterns

| Pattern | What it solves | When to use |
|---|---|---|
| **CQRS** | Separate read/write models — optimize each independently | Read-heavy systems, complex queries, event sourcing |
| **Event Sourcing** | Store events, not state — full audit trail, temporal queries | Financial systems, audit requirements, undo/replay |
| **Scale Cube** | X (cloning), Y (functional decomposition), Z (data partitioning) | Systematic scaling analysis |
| **Strangler Fig** | Incremental migration from legacy — route traffic gradually | Legacy modernization without big-bang rewrite |
| **Saga** | Distributed transactions via compensating actions | Cross-service workflows that need consistency |
| **Circuit Breaker** | Fail fast when a downstream service is unhealthy | Resilience in distributed systems |

## C4 Model

Visualize architecture at four zoom levels:

| Level | Shows | Audience |
|---|---|---|
| **Context (C1)** | System + external actors + other systems | Everyone — business and tech |
| **Container (C2)** | Applications, databases, message brokers inside the system | Developers, architects |
| **Component (C3)** | Major building blocks inside a container | Developers working on that container |
| **Code (C4)** | Classes, functions — only when needed for very complex components | Developers — rarely drawn |

- Always start at C1 — if you can't draw the context, you don't understand the system
- C2 is the most useful level for most technical discussions
- C3 only for complex containers — avoid diagram bloat
- C4 is rarely needed — code IS the diagram at this level

## 12-Factor App

Twelve practices for cloud-native applications:

| Factor | Principle |
|---|---|
| **Codebase** | One codebase per app, many deploys |
| **Dependencies** | Explicitly declare and isolate |
| **Config** | Store in environment variables, not code |
| **Backing services** | Treat as attached resources (swap without code change) |
| **Build/Release/Run** | Strictly separate stages |
| **Processes** | Execute as stateless processes |
| **Port binding** | Export services via port binding |
| **Concurrency** | Scale out via the process model |
| **Disposability** | Fast startup, graceful shutdown |
| **Dev/prod parity** | Keep environments as similar as possible |
| **Logs** | Treat as event streams |
| **Admin processes** | Run as one-off processes |

## Quality Attributes (ISO 25010)

Architecture decisions must explicitly address quality attributes:

| Attribute | Key concerns |
|---|---|
| **Maintainability** | Modularity, analyzability, modifiability, testability |
| **Reliability** | Fault tolerance, recoverability, availability targets (SLA) |
| **Performance** | Time behavior (latency P50/P95/P99), throughput, resource utilization |
| **Security** | Confidentiality, integrity, authentication, authorization, non-repudiation |
| **Scalability** | Elasticity (scale up/down), capacity planning, bottleneck identification |
| **Portability** | Adaptability, installability, replaceability (avoid vendor lock-in) |

- Every architecture decision involves trade-offs between quality attributes
- Make the trade-offs explicit in ADRs — "we chose X for performance at the cost of maintainability"
- Use fitness functions (automated tests) to protect critical quality attributes over time
