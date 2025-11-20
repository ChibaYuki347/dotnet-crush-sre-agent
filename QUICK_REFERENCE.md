# Quick Reference Card: Slot Swap Best Practices

## ✅ Pre-Swap Checklist

Before performing a slot swap:

- [ ] Deploy to staging slot
- [ ] Verify health check passes: `curl https://<staging-url>/healthz`
- [ ] Test application functionality in staging
- [ ] Review Application Insights for any errors
- [ ] Ensure no active incidents or alerts

## 🔄 Recommended Swap Procedure: Swap with Preview

This is the safest method to swap slots.

### Step 1: Start Swap with Preview
```bash
az webapp deployment slot swap \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --target-slot production \
  --action preview
```

### Step 2: Validate (Auto + Manual)
Azure automatically:
- Warms up staging with production settings
- Runs health checks on `/healthz`
- Validates warm-up succeeded

You should manually:
```bash
# Test staging with production config
curl https://<staging-url>/healthz
curl https://<staging-url>/
```

### Step 3: Complete or Cancel

**If validation passes:**
```bash
az webapp deployment slot swap \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --target-slot production \
  --action swap
```

**If validation fails:**
```bash
az webapp deployment slot swap \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --target-slot production \
  --action reset
```

## 🚨 Emergency Rollback (30-60 seconds)

If production is broken after swap:

```bash
# Immediate rollback
az webapp deployment slot swap \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --target-slot production

# Wait 30 seconds for warmup
sleep 30

# Verify recovery
curl https://my-sre-appjapaneast.azurewebsites.net/healthz
```

**Expected**: HTTP 200 with "Healthy" response

See [infra/ROLLBACK.md](./infra/ROLLBACK.md) for additional options.

## 📊 Post-Swap Validation

After any swap:

```bash
# 1. Check health
curl https://my-sre-appjapaneast.azurewebsites.net/healthz

# 2. Test application
curl https://my-sre-appjapaneast.azurewebsites.net/

# 3. Check metrics (wait 2-5 minutes for data)
az monitor metrics list \
  --resource "/subscriptions/68575d55-f60d-4d89-a32b-ad90af38faa6/resourceGroups/my-app-service-group/providers/Microsoft.Web/sites/my-sre-appjapaneast" \
  --metric "HealthCheckStatus"

# 4. Monitor Application Insights
# Navigate to Azure Portal → Application Insights → my-sre-appjapaneast-insights
# Check for exceptions and availability
```

## 📈 Key Metrics to Monitor

| Metric | Healthy State | Alert Threshold |
|--------|--------------|-----------------|
| Health Check Status | 100% | < 100% |
| Availability | 100% | < 99% |
| HTTP 5xx Errors | 0 | > 5 in 5 min |
| Response Time | < 1s | Monitor trends |

## 🔍 Application Insights Queries

Quick access in Azure Portal → Application Insights → Logs:

**Recent Exceptions**:
```kusto
exceptions
| where timestamp > ago(1h)
| summarize count() by type, outerMessage
| order by count_ desc
```

**Availability**:
```kusto
availabilityResults
| where timestamp > ago(1h)
| summarize Availability = avg(success) * 100 by bin(timestamp, 5m)
```

**5xx Errors**:
```kusto
requests
| where timestamp > ago(1h)
| where resultCode startswith "5"
| summarize count() by resultCode, name
```

## 📞 Emergency Contacts

- **Primary SRE**: admin@chiba-yuki.com
- **Azure Support**: [Azure Portal Support](https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade)

## 📚 Documentation

- **Deployment Guide**: [infra/DEPLOYMENT.md](./infra/DEPLOYMENT.md)
- **Rollback Runbook**: [infra/ROLLBACK.md](./infra/ROLLBACK.md)
- **Infrastructure Docs**: [infra/README.md](./infra/README.md)
- **Implementation Summary**: [IMPLEMENTATION_SUMMARY.md](./IMPLEMENTATION_SUMMARY.md)

## ⚙️ Configuration Reference

### Key App Settings

| Setting | Production | Staging | Purpose |
|---------|-----------|---------|---------|
| `INJECT_ERROR` | `0` | `1` | Error simulation for testing |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Auto-set | Auto-set | App Insights telemetry |
| `WEBSITE_HEALTHCHECK_MAXPINGFAILURES` | `3` | `3` | Health check tolerance |
| `WEBSITE_SWAP_WARMUP_PING_PATH` | `/healthz` | `/healthz` | Warm-up endpoint |

### Health Endpoints

- **Production**: `https://my-sre-appjapaneast.azurewebsites.net/healthz`
- **Staging**: `https://my-sre-appjapaneast-staging.azurewebsites.net/healthz`

## 🛡️ SRE Principles Applied

1. **Eliminate Toil**: Automated health checks and warm-up
2. **Monitoring & Alerting**: Proactive alerts before user impact
3. **Reliable Releases**: Swap-with-preview validates before production
4. **Quick Rollback**: 30-60 second recovery with documented runbook
5. **Observability**: Application Insights for full visibility
6. **Auto-Healing**: Automatic recovery from failures

---

**Keep this card handy for all deployment operations!**
