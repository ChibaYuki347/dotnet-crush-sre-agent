# Infrastructure as Code for SRE Agent Demo

This directory contains Azure Bicep templates and documentation for deploying the SRE Agent Demo application to Azure App Service with best practices for reliability and observability.

## Overview

The infrastructure implements countermeasures to prevent downtime during slot swaps, including:

- ✅ Health checks with `/healthz` endpoint
- ✅ Always On enabled to prevent cold starts
- ✅ Application Insights integration for telemetry
- ✅ Preload on startup for faster warm-up
- ✅ Deployment slot with identical configuration
- ✅ Azure Monitor alerts for 5xx errors, availability, and health checks
- ✅ Activity log alerts for slot swap operations
- ✅ Auto-healing rules for automatic recovery
- ✅ Detailed logging and diagnostics

## Files

| File | Description |
|------|-------------|
| `main.bicep` | Main Bicep template defining all Azure resources |
| `main.parameters.json` | Parameters file with default values |
| `DEPLOYMENT.md` | Comprehensive deployment guide |
| `ROLLBACK.md` | Rollback runbook for failed deployments |
| `README.md` | This file |

## Quick Start

### Prerequisites

- Azure CLI (`az` command)
- Azure subscription
- Appropriate permissions to create resources

### Deploy Infrastructure

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "68575d55-f60d-4d89-a32b-ad90af38faa6"

# Create resource group (if needed)
az group create --name my-app-service-group --location japaneast

# Deploy Bicep template
az deployment group create \
  --resource-group my-app-service-group \
  --template-file main.bicep \
  --parameters main.parameters.json
```

### Deploy Application

See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed instructions.

## Resources Created

The Bicep template creates the following Azure resources:

### Core Resources
- **App Service Plan** (`my-app-service-plan`)
  - Linux-based plan
  - Configurable SKU (default: B1)
  
- **Web App** (`my-sre-appjapaneast`)
  - .NET 9.0 runtime
  - Health check enabled at `/healthz`
  - Always On enabled
  - Preload enabled
  - Auto-heal rules configured
  
- **Deployment Slot** (`staging`)
  - Same configuration as production
  - Error injection enabled for testing
  
- **Application Insights** (`my-sre-appjapaneast-insights`)
  - Linked to both production and staging
  - Tracks requests, exceptions, availability

### Monitoring & Alerts
- **Action Group** (`my-sre-appjapaneast-alerts`)
  - Email notifications to admin
  
- **Metric Alerts**
  - HTTP 5xx error rate alert
  - Health check failure alert
  - Availability below 99% alert
  
- **Activity Log Alert**
  - Slot swap operation monitoring

## Key Features

### Health Checks
- Health check path: `/healthz`
- Automatically validates health before completing swaps
- Configurable ping failures threshold (3 failures)
- Warm-up pings during slot swap

### Always On
- Prevents worker process idle timeout
- Reduces cold start issues
- Keeps the application warm and responsive

### Application Insights
- Automatic request tracking
- Exception monitoring
- Availability monitoring
- Custom metrics and events

### Auto-Heal
- Automatically recycles worker on repeated 5xx errors
- Minimum process execution time before recycle
- Prevents cascading failures

### Deployment Slots
- Safe testing environment (staging)
- Swap with preview capability
- Identical configuration to production
- Error injection for testing failures

## Configuration

### Parameters

You can customize the deployment by modifying `main.parameters.json`:

```json
{
  "webAppName": "your-app-name",
  "location": "your-region",
  "appServicePlanName": "your-plan-name",
  "sku": "B1",  // or B2, S1, P1v2, etc.
  "slotName": "staging",  // or blue, green, etc.
  "alertEmail": "your-email@example.com"
}
```

### Application Settings

Key application settings configured:

- `APPLICATIONINSIGHTS_CONNECTION_STRING`: App Insights connection
- `INJECT_ERROR`: Error injection flag (0 in prod, 1 in staging)
- `WEBSITE_HEALTHCHECK_MAXPINGFAILURES`: Health check threshold
- `WEBSITE_SWAP_WARMUP_PING_PATH`: Warm-up endpoint for swaps
- `WEBSITE_SWAP_WARMUP_PING_STATUSES`: Expected status codes

### Sticky Settings

Ensure slot-specific settings don't swap:

```bash
az webapp config appsettings set \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot-settings INJECT_ERROR
```

## Monitoring

### View Metrics

```bash
# Health check status
az monitor metrics list \
  --resource "/subscriptions/68575d55-f60d-4d89-a32b-ad90af38faa6/resourceGroups/my-app-service-group/providers/Microsoft.Web/sites/my-sre-appjapaneast" \
  --metric "HealthCheckStatus"

# HTTP 5xx errors
az monitor metrics list \
  --resource "/subscriptions/68575d55-f60d-4d89-a32b-ad90af38faa6/resourceGroups/my-app-service-group/providers/Microsoft.Web/sites/my-sre-appjapaneast" \
  --metric "Http5xx"
```

### View Alerts

```bash
az monitor metrics alert list \
  --resource-group my-app-service-group
```

### Application Insights Queries

Access in Azure Portal > Application Insights > Logs:

**Availability over time**:
```kusto
availabilityResults
| where timestamp > ago(24h)
| summarize Availability = avg(success) * 100 by bin(timestamp, 5m)
| render timechart
```

**Error rate**:
```kusto
requests
| where timestamp > ago(24h)
| summarize ErrorRate = countif(success == false) * 100.0 / count() by bin(timestamp, 5m)
| render timechart
```

## Best Practices

### Deployment
1. Always deploy to staging slot first
2. Use swap with preview for validation
3. Monitor health checks during swap
4. Keep rollback plan ready (see ROLLBACK.md)

### Configuration
1. Keep production and staging configuration in sync
2. Use slot settings for environment-specific values
3. Review IP restrictions regularly
4. Enable diagnostic logging

### Monitoring
1. Review Application Insights daily
2. Set up dashboards for key metrics
3. Test alerts to ensure they fire correctly
4. Monitor costs and optimize as needed

### Security
1. Use HTTPS only (enforced in template)
2. Keep TLS at 1.2 or higher
3. Review IP restrictions for your use case
4. Rotate secrets regularly
5. Use managed identities where possible

## Troubleshooting

### Common Issues

**Deployment fails**
- Check Azure CLI version is current
- Verify subscription has quota for resources
- Review deployment error messages in Activity Log

**Health checks failing**
- Verify application is listening on correct port
- Check `/healthz` endpoint returns 200 OK
- Review application logs for startup errors

**Swap fails**
- Ensure health checks pass before swapping
- Use swap with preview to validate
- Check for configuration differences

**High 5xx error rate**
- Review Application Insights exceptions
- Check application logs
- Verify dependencies are accessible
- Consider rollback (see ROLLBACK.md)

For detailed troubleshooting, see [DEPLOYMENT.md](./DEPLOYMENT.md#troubleshooting).

## Cleanup

To remove all resources:

```bash
az group delete --name my-app-service-group --yes --no-wait
```

**Warning**: This permanently deletes all resources and data.

## References

- [DEPLOYMENT.md](./DEPLOYMENT.md) - Deployment procedures
- [ROLLBACK.md](./ROLLBACK.md) - Rollback runbook
- [Azure App Service Documentation](https://docs.microsoft.com/en-us/azure/app-service/)
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Application Insights Documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/app/)

## Support

For issues or questions:
- Create an issue in the repository
- Contact: admin@chiba-yuki.com
- Azure Support: https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade
