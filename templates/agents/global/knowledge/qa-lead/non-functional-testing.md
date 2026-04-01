# Non-Functional Testing

## Performance Testing

| Type | Purpose | When |
|---|---|---|
| **Load** | Validate behavior under expected load | Before release, after infra changes |
| **Stress** | Find breaking point — what happens beyond capacity | Capacity planning, resilience validation |
| **Spike** | Sudden traffic burst — can the system absorb and recover? | Flash sales, marketing campaigns |
| **Soak / Endurance** | Sustained load over hours — detect memory leaks, connection pool exhaustion | Before major releases |
| **Scalability** | Does adding resources (horizontal/vertical) improve throughput linearly? | Architecture validation |

### Key metrics

- **Response time**: p50, p90, p95, p99 (not just average — tail latency matters)
- **Throughput**: requests/second the system handles
- **Error rate**: percentage of failed requests under load
- **Resource utilization**: CPU, memory, disk I/O, network, connection pools

### Best practices

- Define SLOs before testing (e.g., "p99 < 500ms at 1000 rps")
- Use realistic data volumes and user behavior patterns
- Test in an environment similar to production
- Automate performance tests in CI for regression detection

## Security Testing

| Type | Purpose |
|---|---|
| **SAST** | Static analysis — find vulnerabilities in source code without executing |
| **DAST** | Dynamic analysis — test running application for vulnerabilities |
| **SCA** | Software composition analysis — find known vulnerabilities in dependencies |
| **Secret scanning** | Detect hardcoded credentials, API keys, tokens in code and history |
| **Container scanning** | Find vulnerabilities in container images (OS packages, libraries) |
| **Penetration testing** | Simulated attack by security experts — finds what automation misses |

### OWASP Top 10 coverage

Every test strategy should address:

1. Broken Access Control
2. Cryptographic Failures
3. Injection (SQL, XSS, Command)
4. Insecure Design
5. Security Misconfiguration
6. Vulnerable Components
7. Auth Failures
8. Integrity Failures
9. Logging/Monitoring Failures
10. SSRF

## Accessibility Testing

### WCAG 2.1 levels

- **A**: minimum — all content perceivable and operable
- **AA**: standard target — most legal requirements reference this level
- **AAA**: enhanced — not required for full compliance but valuable for inclusivity

### Key checks

- Screen reader compatibility (semantic HTML, ARIA roles)
- Keyboard navigation (tab order, focus indicators, no traps)
- Color contrast (4.5:1 for text, 3:1 for large text)
- Alt text for images, captions for media
- Form labels associated with inputs
- Error messages clear and accessible

### Tools

- axe-core (automated), Lighthouse (automated), NVDA/VoiceOver (manual), Pa11y (CI)

## Reliability Testing

### Chaos Engineering

- Inject controlled failures to verify resilience
- Start small: kill a pod, add latency, drop packets
- Have a hypothesis: "If database is unavailable for 30s, the system returns cached data"
- Always have a rollback plan

### Fault injection targets

- Network: latency, packet loss, DNS failure, partition
- Infrastructure: pod/container crash, node failure, disk full
- Application: slow dependency, corrupted response, timeout
- Data: stale cache, inconsistent replica, schema mismatch

## Usability Testing

- Task completion rate — can users achieve their goals?
- Time on task — how efficiently?
- Error rate — how often do users make mistakes?
- Satisfaction — subjective assessment (SUS, NPS)
- Learnability — how quickly do new users become proficient?

## Compatibility Testing

| Dimension | What to test |
|---|---|
| **Browser** | Chrome, Firefox, Safari, Edge — latest 2 versions |
| **OS** | Windows, macOS, Linux, iOS, Android |
| **Device** | Desktop, tablet, mobile — responsive breakpoints |
| **API version** | Backward compatibility with previous API versions |
| **Database** | Supported database versions and engines |

## Observability and Monitoring

### Shift-right testing — validate in production

- **Synthetic monitoring**: automated probes running production scenarios periodically
- **Real user monitoring (RUM)**: collect actual user experience metrics
- **Canary deployments**: route small traffic percentage to new version, compare metrics
- **Feature flags**: gradual rollout with kill switch
- **Log analysis**: structured logs with correlation IDs for distributed tracing
- **Alerting**: define thresholds based on SLOs, alert on trends not just thresholds
