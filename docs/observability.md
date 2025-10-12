# Observability Guide

This guide covers monitoring, logging, alerting, and troubleshooting using Application Insights and Azure Monitor.

## Overview

The solution implements comprehensive observability across all layers:
- **Application Insights**: Telemetry, distributed tracing, metrics
- **Log Analytics**: Centralized logging and querying
- **Azure Monitor**: Alerting and dashboards
- **Structured Logging**: JSON logs with correlation IDs

## Application Insights Integration

### Backend Telemetry

The FastAPI backend automatically tracks:
- HTTP requests (duration, status, endpoint)
- Dependencies (Translator API, Storage, Key Vault)
- Exceptions with stack traces
- Custom events and metrics

**Key Metrics Tracked:**

```python
# Character count per translation
ai_client.track_metric("translation.characters", character_count)

# Language pair usage
ai_client.track_event("translation.completed", {
    "source_language": source_lang,
    "target_language": target_lang,
    "character_count": count
})

# Cache hit rate
ai_client.track_metric("cache.hit_rate", hit_rate)
```

### Frontend Telemetry

React application tracks:
- Page views and navigation
- User interactions (button clicks, form submissions)
- API call success/failure
- Performance metrics (load time, render time)

**Implementation:**

```typescript
import { ApplicationInsights } from '@microsoft/applicationinsights-web';

const appInsights = new ApplicationInsights({
  config: {
    connectionString: import.meta.env.VITE_APPINSIGHTS_CONNECTION_STRING,
    enableAutoRouteTracking: true,
  }
});

// Track translation event
appInsights.trackEvent({
  name: 'TranslationCompleted',
  properties: {
    sourceLanguage: 'en',
    targetLanguage: 'es',
    characterCount: 150
  }
});
```

## Key Performance Indicators (KPIs)

### Service Health

| Metric | Target | Alert Threshold |
|--------|--------|----------------|
| Availability | > 99.9% | < 99.5% for 5 min |
| Error Rate | < 0.1% | > 1% for 5 min |
| P95 Latency | < 500ms | > 2s for 10 min |
| P99 Latency | < 1s | > 5s for 10 min |

### Business Metrics

| Metric | Purpose |
|--------|---------|
| Translations per day | Usage tracking |
| Characters translated | Cost forecasting |
| Unique language pairs | Feature adoption |
| Average translation length | User behavior |
| Cache hit rate | Performance optimization |

### Cost Metrics

| Metric | Purpose |
|--------|---------|
| Daily Translator API calls | Quota monitoring |
| Monthly character count | Billing prediction |
| Storage usage growth | Capacity planning |

## KQL Queries

### Request Performance

**Average latency by endpoint:**

```kql
requests
| where timestamp > ago(24h)
| summarize 
    count=count(), 
    avg_duration=avg(duration), 
    p95_duration=percentile(duration, 95),
    p99_duration=percentile(duration, 99)
  by name
| order by count desc
```

**Slow requests (> 2 seconds):**

```kql
requests
| where timestamp > ago(1h)
| where duration > 2000
| project timestamp, name, url, duration, resultCode, client_IP
| order by duration desc
```

### Error Analysis

**Error rate trend:**

```kql
requests
| where timestamp > ago(24h)
| summarize 
    total=count(), 
    errors=countif(success == false)
  by bin(timestamp, 5m)
| extend error_rate = (errors * 100.0) / total
| project timestamp, error_rate
| render timechart
```

**Exception details:**

```kql
exceptions
| where timestamp > ago(24h)
| summarize count=count() by type, outerMessage
| order by count desc
```

**Failed translation requests:**

```kql
requests
| where timestamp > ago(1h)
| where name contains "translate"
| where success == false
| join kind=inner (
    traces
    | where message contains "translation_failed"
  ) on operation_Id
| project timestamp, url, resultCode, customDimensions
```

### Dependency Tracking

**Translator API performance:**

```kql
dependencies
| where timestamp > ago(24h)
| where type == "HTTP"
| where target contains "microsofttranslator"
| summarize 
    count=count(),
    avg_duration=avg(duration),
    success_rate=countif(success == true) * 100.0 / count()
  by name
| order by count desc
```

**429 Rate limit events:**

```kql
dependencies
| where timestamp > ago(1h)
| where resultCode == "429"
| project timestamp, name, target, duration, data
| order by timestamp desc
```

### Custom Metrics

**Translation character count:**

```kql
customMetrics
| where name == "translation.characters"
| where timestamp > ago(7d)
| summarize total_chars=sum(value) by bin(timestamp, 1d)
| render columnchart
```

**Language pair popularity:**

```kql
customEvents
| where name == "translation.completed"
| where timestamp > ago(30d)
| extend source = tostring(customDimensions.source_language)
| extend target = tostring(customDimensions.target_language)
| summarize count=count() by strcat(source, " → ", target)
| order by count desc
| take 20
```

### Cost Analysis

**Daily translation volume (for cost projection):**

```kql
customMetrics
| where name == "translation.characters"
| where timestamp > ago(30d)
| summarize daily_chars=sum(value) by bin(timestamp, 1d)
| extend estimated_cost = daily_chars * 10.0 / 1000000  // $10 per 1M chars
| project timestamp, daily_chars, estimated_cost
| render timechart
```

**Quota usage percentage:**

```kql
let quota = 2000000;  // 2M characters for F0 tier
customMetrics
| where name == "translation.characters"
| where timestamp > ago(1d)
| summarize total_chars=sum(value)
| extend quota_percentage = (total_chars * 100.0) / quota
| project total_chars, quota_percentage
```

## Distributed Tracing

### Correlation IDs

All requests include correlation IDs to track end-to-end transactions:

```
User Request → Frontend → Backend → Translator API → Response
     ↓             ↓          ↓           ↓
  [trace-id-1] [trace-id-1] [trace-id-1] [trace-id-1]
```

**Query by correlation ID:**

```kql
let operationId = "abc123...";
union requests, dependencies, traces, exceptions
| where operation_Id == operationId
| project timestamp, itemType, name, message, duration, resultCode
| order by timestamp asc
```

### Application Map

View the dependency graph:
1. Navigate to Application Insights
2. Select "Application Map" from left menu
3. Visualize: Frontend → Backend → Translator → Storage

## Dashboards

### Custom Dashboard Configuration

Create a dashboard in Azure Portal with these pinned visualizations:

**1. Request Rate (Requests/minute)**
```kql
requests
| where timestamp > ago(1h)
| summarize count=count() by bin(timestamp, 1m)
| render timechart
```

**2. Error Rate Percentage**
```kql
requests
| summarize 
    total=count(), 
    errors=countif(success == false)
  by bin(timestamp, 5m)
| extend error_rate = (errors * 100.0) / total
| render timechart
```

**3. API Latency Distribution**
```kql
requests
| where timestamp > ago(1h)
| summarize 
    p50=percentile(duration, 50),
    p95=percentile(duration, 95),
    p99=percentile(duration, 99)
  by bin(timestamp, 5m)
| render timechart
```

**4. Translation Volume**
```kql
customMetrics
| where name == "translation.characters"
| where timestamp > ago(24h)
| summarize sum(value) by bin(timestamp, 1h)
| render columnchart
```

**5. Top Languages**
```kql
customEvents
| where name == "translation.completed"
| where timestamp > ago(7d)
| extend target_lang = tostring(customDimensions.target_language)
| summarize count=count() by target_lang
| top 10 by count
| render piechart
```

### Export Dashboard as Code

```bash
# Export dashboard definition
az portal dashboard show \
  --name "translator-dashboard" \
  --resource-group "translator-prod-rg" \
  --output json > dashboard.json

# Import to another environment
az portal dashboard create \
  --name "translator-dashboard-dev" \
  --resource-group "translator-dev-rg" \
  --input-path dashboard.json
```

## Alerting

### Alert Rules

**1. High Error Rate**

```yaml
Name: High Error Rate Alert
Condition: Percentage > 5%
Window: 5 minutes
Frequency: 1 minute
Severity: Error (2)
Action: Email + Slack
```

**KQL:**
```kql
requests
| summarize 
    total=count(), 
    errors=countif(success == false)
| extend error_rate = (errors * 100.0) / total
| where error_rate > 5
```

**2. Translator API Quota**

```yaml
Name: Translator Quota Alert
Condition: > 80% of daily limit
Window: 1 hour
Severity: Warning (1)
Action: Email team
```

**KQL:**
```kql
let quota = 2000000;  // Adjust for your tier
customMetrics
| where name == "translation.characters"
| where timestamp > ago(1d)
| summarize total=sum(value)
| extend percent = (total * 100.0) / quota
| where percent > 80
```

**3. Service Availability**

```yaml
Name: Service Down Alert
Type: Availability test
URL: https://your-api.azurewebsites.net/health
Interval: 5 minutes
Failed locations: 2 of 5
Severity: Critical (0)
Action: PagerDuty
```

**4. High Latency**

```yaml
Name: High Latency Alert
Condition: P95 duration > 2000ms
Window: 10 minutes
Severity: Warning (1)
Action: Slack notification
```

**KQL:**
```kql
requests
| summarize p95=percentile(duration, 95)
| where p95 > 2000
```

### Alert Action Groups

Configure action groups for different severities:

```bash
# Create action group for critical alerts
az monitor action-group create \
  --name "critical-alerts" \
  --resource-group "translator-prod-rg" \
  --short-name "Critical" \
  --email-receiver email admin@example.com \
  --sms-receiver sms 1 5551234567

# Create action group for warnings
az monitor action-group create \
  --name "warning-alerts" \
  --resource-group "translator-prod-rg" \
  --short-name "Warning" \
  --email-receiver email team@example.com \
  --webhook-receiver webhook "https://hooks.slack.com/services/..."
```

## Logging Best Practices

### Structured Logging

**Backend (Python):**

```python
import logging
import json
from datetime import datetime

logger = logging.getLogger(__name__)

def log_translation_event(
    correlation_id: str,
    source_lang: str,
    target_lang: str,
    char_count: int,
    duration_ms: float
):
    logger.info(json.dumps({
        "event": "translation_completed",
        "timestamp": datetime.utcnow().isoformat(),
        "correlation_id": correlation_id,
        "source_language": source_lang,
        "target_language": target_lang,
        "character_count": char_count,
        "duration_ms": duration_ms
    }))
```

**Query structured logs:**

```kql
traces
| where message startswith "{"
| extend log = parse_json(message)
| where log.event == "translation_completed"
| project 
    timestamp,
    correlation_id = log.correlation_id,
    source_language = log.source_language,
    target_language = log.target_language,
    character_count = log.character_count
```

### Log Levels

| Level | Usage | Examples |
|-------|-------|----------|
| DEBUG | Development troubleshooting | Request/response bodies, variable values |
| INFO | Normal operations | Translation completed, cache hit |
| WARNING | Recoverable errors | Rate limit hit, retry initiated |
| ERROR | Operation failed | API error, validation failure |
| CRITICAL | Service degradation | Cannot connect to Translator, Key Vault unavailable |

## Performance Monitoring

### Live Metrics Stream

View real-time telemetry:

```bash
# Open in browser
az monitor app-insights component show \
  --app translator-prod-ai \
  --resource-group translator-prod-rg \
  --query "appId" -o tsv | \
  xargs -I {} open "https://portal.azure.com/#blade/AppInsightsExtension/QuickPulseBladeV2/ComponentId/{}"
```

### Performance Profiling

Enable profiler for production:

```bash
az webapp config appsettings set \
  --resource-group translator-prod-rg \
  --name translator-prod-api \
  --settings APPINSIGHTS_PROFILERFEATURE_VERSION="1.0.0"
```

View traces: Application Insights → Performance → "Profiler traces"

### Dependency Analysis

**Slowest dependencies:**

```kql
dependencies
| where timestamp > ago(24h)
| summarize 
    count=count(),
    avg_duration=avg(duration),
    p95_duration=percentile(duration, 95)
  by target
| order by p95_duration desc
```

## Troubleshooting Scenarios

### Scenario 1: High Latency

**Investigate:**

```kql
// Find slow requests
requests
| where timestamp > ago(1h)
| where duration > 2000
| join kind=inner dependencies on operation_Id
| project 
    request_timestamp=timestamp,
    request_name=name,
    request_duration=duration,
    dependency_target=target,
    dependency_duration=duration1
| order by request_duration desc
```

**Common causes:**
- Translator API slow response (check Azure status)
- Cold start (scale up instances)
- Network latency (check region)

### Scenario 2: Error Spike

**Investigate:**

```kql
// Find error patterns
exceptions
| where timestamp > ago(1h)
| summarize count=count() by type, outerMessage
| order by count desc
```

**Common causes:**
- Translator API quota exceeded (check usage)
- Authentication failures (check Key Vault)
- Network timeouts (check connectivity)

### Scenario 3: Memory/CPU Issues

**Investigate:**

```kql
performanceCounters
| where timestamp > ago(1h)
| where name in ("% Processor Time", "Available Bytes")
| render timechart
```

**Actions:**
- Scale up App Service plan
- Review memory leaks in code
- Enable auto-scaling rules

## Cost Optimization

**Monitor Application Insights costs:**

```kql
// Daily data ingestion
union *
| where timestamp > ago(30d)
| summarize data_gb=sum(itemCount) / 1000000000 by bin(timestamp, 1d)
| extend estimated_cost=data_gb * 2.3  // $2.30 per GB
| render timechart
```

**Reduce costs:**
- Lower sampling rate in production
- Increase log retention thresholds
- Filter out noisy telemetry
- Use diagnostic settings for long-term storage (cheaper)

## Additional Resources

- [Application Insights Documentation](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [KQL Quick Reference](https://learn.microsoft.com/azure/data-explorer/kql-quick-reference)
- [Azure Monitor Best Practices](https://learn.microsoft.com/azure/azure-monitor/best-practices)
- [Distributed Tracing](https://learn.microsoft.com/azure/azure-monitor/app/distributed-tracing)

---

**Next Steps:**
1. Set up custom dashboards
2. Configure alert action groups
3. Test alert rules in dev environment
4. Document runbook procedures

