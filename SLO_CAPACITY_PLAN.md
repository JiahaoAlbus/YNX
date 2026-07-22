# SLO and Capacity Plan

## Measurement contract

Every measurement record must include source commit, environment, UTC interval, sample count, method, p50/p95/p99, throughput, error rate, concurrent load, provider latency, and raw evidence path. Small local samples prove only local behavior.

## Initial testnet objectives

| Signal | Objective | Window | Alert |
| --- | --- | --- | --- |
| public read API availability | 99.5% | rolling 30 days | 2% budget burn in 1 hour |
| public write API successful handling | 99.0%, excluding valid client rejection | rolling 30 days | 5% budget burn in 1 hour |
| read API latency | p95 under 750 ms, p99 under 2 s | 15 minutes | two consecutive windows |
| write acceptance latency | p95 under 2 s | 15 minutes | two consecutive windows |
| queue age | under 60 s | 5 minutes | any 10-minute breach |
| restore point | RPO at most 24 h until continuous replication is evidenced | per backup | missed successful backup |
| service restoration | RTO at most 4 h after declared disaster | per drill | drill exceeds objective |

## Capacity envelope

The platform has no defensible public scale claim yet. The next evidence run must sweep concurrency 1, 10, 50, and 100; record cold and warm starts; observe CPU, memory, disk, queue depth, database connections, network, provider limits, and cost; and stop when p99, errors, saturation, or spend crosses a guardrail. Autoscaling must have minimum, maximum, cooldown, and cost ceilings.

Storage forecasts must separately model chain state, operational databases, object artifacts, logs, traces, audit records, and backups at 7-, 30-, 90-, and 365-day horizons. Retention changes require privacy, forensics, legal, and cost review.

## Release gate

`deployedPublic` cannot become true from a local load test. Public synthetic evidence, alert delivery evidence, a restore drill, and an identified on-call owner are required.
