# Observability

## Three Pillars

Observability enables understanding system behavior from its external outputs:

| Pillar | What it captures | When to use |
|---|---|---|
| **Logs** | Discrete events with context (structured text) | Debugging, audit trails, error diagnosis |
| **Metrics** | Numeric measurements over time (counters, gauges, histograms) | Alerting, dashboards, capacity planning |
| **Traces** | Request flow across services (spans with timing) | Latency diagnosis, dependency mapping, bottleneck detection |

- Logs tell you WHAT happened
- Metrics tell you HOW MUCH is happening
- Traces tell you WHERE time is spent

## Structured Logging

### Principles

- Use structured format (JSON) — never unstructured text in production
- Include context: `timestamp`, `level`, `message`, `service`, `correlation_id`
- Use consistent field names across all services
- Never log sensitive data: passwords, tokens, PII, credit card numbers
- Log at the right level — excessive logging is noise, insufficient logging is blindness

### Log Levels

| Level | When to use | Example |
|---|---|---|
| **ERROR** | Something failed and requires attention | Unhandled exception, database connection lost |
| **WARN** | Something unexpected but not broken — may need attention | Retry succeeded, deprecated API called, rate limit approaching |
| **INFO** | Significant business or lifecycle events | Request received, order placed, service started |
| **DEBUG** | Detailed diagnostic information — disabled in production | Variable values, query parameters, intermediate results |

- Default to INFO in production — DEBUG only when actively investigating
- Every ERROR should be actionable — if nothing can be done, it's a WARN
- Include enough context to diagnose without reproducing: request ID, user ID (hashed), input summary

### Correlation IDs

- Generate a unique ID at the system entry point (API gateway, message consumer)
- Propagate through all downstream calls (HTTP headers, message metadata)
- Include in every log entry — enables tracing a request across all services
- Standard header: `X-Correlation-ID` or W3C `traceparent`

## Metrics

### RED Method (for services)

| Metric | What to measure |
|---|---|
| **Rate** | Requests per second |
| **Errors** | Failed requests per second (and error rate %) |
| **Duration** | Response time distribution (P50, P95, P99) |

- Apply RED to every service endpoint
- P99 matters more than average — outliers affect real users
- Alert on error rate increase, not absolute count

### USE Method (for resources)

| Metric | What to measure |
|---|---|
| **Utilization** | Percentage of resource capacity in use (CPU %, memory %, disk %) |
| **Saturation** | Work queued because resource is fully utilized (queue depth, thread pool exhaustion) |
| **Errors** | Resource-level errors (disk I/O errors, network packet drops) |

- Apply USE to infrastructure resources: CPU, memory, disk, network, connection pools
- High utilization without saturation is fine — saturation means capacity is exceeded

### Key Metrics to Track

- **Latency**: P50, P95, P99 per endpoint — set SLOs for each
- **Error rate**: 5xx rate, 4xx rate (separate — 4xx may be expected)
- **Throughput**: requests/sec — baseline for capacity planning
- **Saturation**: queue depth, active connections, thread pool usage
- **Dependencies**: latency and error rate for each downstream service/database

## Distributed Tracing

### OpenTelemetry

- Use OpenTelemetry as the standard instrumentation framework
- Auto-instrument HTTP clients, database drivers, message consumers
- Add custom spans for significant business operations
- Export to your backend: Jaeger, Zipkin, Azure Monitor, Grafana Tempo

### Span Design

- One span per logical operation (HTTP request, database query, message processing)
- Name spans descriptively: `GET /api/orders`, `query orders_by_user`, not `handler`
- Add relevant attributes: `http.method`, `http.status_code`, `db.statement` (sanitized)
- Record errors as span events with stack traces

## Alerting

### Principles

- Alert on symptoms (user-facing impact), not causes — "error rate > 5%" not "CPU > 80%"
- Every alert must be actionable — if the response is "ignore it", delete the alert
- Include a runbook link in every alert — what to check, how to mitigate
- Use severity levels: page (immediate), ticket (next business day), log (informational)

### Alert Fatigue Prevention

- Start with few, high-signal alerts — add more only when incidents reveal gaps
- Auto-resolve alerts when the condition clears
- Group related alerts — don't send 100 alerts for the same incident
- Review alerts monthly — delete alerts nobody acts on

## Health Checks

| Type | Purpose | Frequency |
|---|---|---|
| **Liveness** | Is the process alive? (restart if not) | Every 10–30s |
| **Readiness** | Can the service handle traffic? (remove from LB if not) | Every 5–10s |
| **Startup** | Has the service finished initializing? (don't check liveness until ready) | During startup only |

- Liveness: simple — return 200 if the process is running. Do NOT check dependencies
- Readiness: check critical dependencies — database connection, required config loaded
- Keep health checks fast (< 200ms) — they run frequently
- Expose at `/health/live` and `/health/ready` (or `/healthz`, `/readyz`)
