# Rollback Runbook

This runbook provides step-by-step instructions for rolling back a failed slot swap or problematic deployment.

## When to Execute a Rollback

Execute this runbook if you observe any of the following after a slot swap:

- HTTP 5xx error rate increases significantly
- Availability drops below acceptable threshold (< 99%)
- Health check failures
- User-reported issues or service degradation
- Azure Monitor alerts firing

## Pre-Rollback Checklist

Before executing rollback:

- [ ] Verify the issue is deployment-related (not infrastructure or external dependency)
- [ ] Note the current time and symptoms for post-incident review
- [ ] Notify stakeholders of the rollback action
- [ ] Capture current state for investigation (logs, metrics, screenshots)

## Rollback Procedures

### Option 1: Immediate Rollback via Slot Swap (Fastest)

This is the quickest way to restore service by swapping back to the previous version.

#### Step 1: Execute the rollback swap

```bash
az webapp deployment slot swap \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --target-slot production
```

**Expected Time**: 30-60 seconds

#### Step 2: Verify service recovery

```bash
# Test health endpoint
curl https://my-sre-appjapaneast.azurewebsites.net/healthz

# Test main application
curl https://my-sre-appjapaneast.azurewebsites.net/
```

Expected: HTTP 200 responses

#### Step 3: Monitor metrics

```bash
# Check recent availability
az monitor metrics list \
  --resource "/subscriptions/68575d55-f60d-4d89-a32b-ad90af38faa6/resourceGroups/my-app-service-group/providers/Microsoft.Web/sites/my-sre-appjapaneast" \
  --metric "HealthCheckStatus" \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --interval PT1M
```

### Option 2: Rollback via Re-deployment (More Control)

If slot swap doesn't resolve the issue, deploy a known-good version.

#### Step 1: Identify the last known good version

```bash
# List recent deployments
az webapp deployment list \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --query "[].{id:id, author:author, message:message, start:start_time}" \
  --output table
```

#### Step 2: Deploy from source control (if using Git)

```bash
# Checkout the last known good commit
git log --oneline -10  # Find the good commit
git checkout <commit-hash>

# Build and publish
dotnet publish -c Release -o ./publish

# Create deployment package
cd publish
zip -r ../rollback.zip .
cd ..

# Deploy directly to production
az webapp deployment source config-zip \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --src rollback.zip
```

**Expected Time**: 2-5 minutes

#### Step 3: Verify deployment

```bash
# Wait for deployment to complete (check deployment status)
az webapp deployment list \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --query "[0].{status:status, message:message}"

# Test health
curl https://my-sre-appjapaneast.azurewebsites.net/healthz
```

### Option 3: Emergency Restart (If Swap/Deploy Fails)

If the application is unresponsive and swap doesn't work:

#### Step 1: Restart the web app

```bash
az webapp restart \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast
```

**Expected Time**: 30-90 seconds

#### Step 2: Monitor restart progress

```bash
# Tail logs to watch restart
az webapp log tail \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast
```

#### Step 3: Verify service recovery

```bash
curl https://my-sre-appjapaneast.azurewebsites.net/healthz
```

### Option 4: Scale In/Out (If Auto-Heal Activated)

If auto-heal has been triggered and workers are unhealthy:

#### Step 1: Scale out temporarily

```bash
az appservice plan update \
  --resource-group my-app-service-group \
  --name my-app-service-plan \
  --number-of-workers 2
```

#### Step 2: Wait for new instances to come online (2-3 minutes)

```bash
# Monitor instance health
az webapp show \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --query "state"
```

#### Step 3: Scale back down after recovery

```bash
az appservice plan update \
  --resource-group my-app-service-group \
  --name my-app-service-plan \
  --number-of-workers 1
```

## Post-Rollback Actions

After successful rollback:

### 1. Confirm Service Restoration

- [ ] Health endpoint returns 200 OK
- [ ] Main application is accessible
- [ ] Availability metrics show 100%
- [ ] No active alerts in Azure Monitor
- [ ] User-reported issues resolved

### 2. Capture Diagnostic Information

```bash
# Download recent logs from the failed deployment
az webapp log download \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --log-file failed-deployment-logs.zip

# Download slot logs if swap was attempted
az webapp log download \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --log-file staging-logs.zip
```

### 3. Query Application Insights

Run these queries in Application Insights to gather incident data:

**Exception analysis**:
```kusto
exceptions
| where timestamp > ago(1h)
| summarize count() by type, outerMessage, cloud_RoleName
| order by count_ desc
```

**Request failure analysis**:
```kusto
requests
| where timestamp > ago(1h)
| where success == false
| summarize count() by resultCode, name, cloud_RoleName
| order by count_ desc
```

**Availability during incident**:
```kusto
availabilityResults
| where timestamp > ago(2h)
| summarize AvailabilityPercentage = avg(success) * 100 by bin(timestamp, 1m)
| render timechart
```

### 4. Notify Stakeholders

Send a brief update:
- Incident start and end time
- Impact (availability, users affected)
- Rollback action taken
- Current status
- Next steps (investigation, fix, re-deployment)

### 5. Investigate Root Cause

- [ ] Review application logs for exceptions or errors
- [ ] Check Application Insights for performance degradation
- [ ] Review code changes in the failed deployment
- [ ] Verify configuration differences between slots
- [ ] Check for resource constraints (CPU, memory, connections)
- [ ] Review health check implementation

### 6. Plan Re-Deployment

Before attempting another deployment:

- [ ] Fix identified issues in code/configuration
- [ ] Test thoroughly in local/development environment
- [ ] Deploy to staging slot
- [ ] Validate health checks pass consistently
- [ ] Use swap with preview for next production deployment
- [ ] Have rollback plan ready

## Rollback Decision Matrix

| Symptom | Recommended Action | Expected Recovery Time |
|---------|-------------------|----------------------|
| 5xx errors after swap | Option 1: Slot Swap Back | 30-60 seconds |
| Health checks failing | Option 1: Slot Swap Back | 30-60 seconds |
| Application unresponsive | Option 3: Restart | 30-90 seconds |
| High memory/CPU, auto-heal triggered | Option 4: Scale Out | 2-5 minutes |
| Swap failed to complete | Option 2: Re-deploy known good version | 2-5 minutes |
| Data corruption suspected | Option 2: Re-deploy + data restore | 5-30 minutes |

## Emergency Contacts

- Primary SRE: admin@chiba-yuki.com
- Azure Support: [Azure Portal Support](https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade)

## Automation Script

For quick rollback, save this as `rollback.sh`:

```bash
#!/bin/bash
set -e

RESOURCE_GROUP="my-app-service-group"
WEB_APP_NAME="my-sre-appjapaneast"

echo "Starting rollback procedure..."
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Perform slot swap to rollback
echo "Swapping slots..."
az webapp deployment slot swap \
  --resource-group $RESOURCE_GROUP \
  --name $WEB_APP_NAME \
  --slot staging \
  --target-slot production

echo "Swap completed. Waiting 30 seconds for warmup..."
sleep 30

# Verify health
echo "Checking health endpoint..."
HEALTH_URL="https://${WEB_APP_NAME}.azurewebsites.net/healthz"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $HEALTH_URL)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Rollback successful! Health check returned 200."
    echo "Service is healthy at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
else
    echo "✗ Warning: Health check returned $HTTP_CODE"
    echo "Manual investigation required."
    exit 1
fi
```

Make it executable:
```bash
chmod +x rollback.sh
```

Run it:
```bash
./rollback.sh
```

## Post-Incident Review

Schedule a post-incident review within 24-48 hours to:

1. Document timeline of events
2. Identify root cause
3. Document what worked well and what didn't
4. Identify action items to prevent recurrence
5. Update runbooks with lessons learned

## References

- [Azure App Service diagnostic logs](https://docs.microsoft.com/en-us/azure/app-service/troubleshoot-diagnostic-logs)
- [Application Insights availability tests](https://docs.microsoft.com/en-us/azure/azure-monitor/app/availability-overview)
- [Disaster recovery best practices](https://docs.microsoft.com/en-us/azure/app-service/overview-disaster-recovery)
