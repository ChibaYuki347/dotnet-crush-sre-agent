# Deployment Guide

This guide provides instructions for deploying the SRE Agent application to Azure App Service using the Bicep infrastructure template.

## Prerequisites

- Azure CLI installed (`az` command)
- Azure subscription with appropriate permissions
- .NET 9.0 SDK installed

## Infrastructure Deployment

### 1. Login to Azure

```bash
az login
```

### 2. Set the subscription

```bash
az account set --subscription "68575d55-f60d-4d89-a32b-ad90af38faa6"
```

### 3. Create Resource Group (if it doesn't exist)

```bash
az group create \
  --name my-app-service-group \
  --location japaneast
```

### 4. Deploy the Bicep template

```bash
az deployment group create \
  --resource-group my-app-service-group \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json
```

This will create:
- App Service Plan
- Application Insights component
- Web App with health checks enabled and Always On
- Deployment slot (staging) with the same configuration
- Action Group for alert notifications
- Azure Monitor alerts for 5xx errors, health checks, availability, and slot swaps

## Application Deployment

### Build the application

```bash
dotnet publish -c Release -o ./publish
```

### Deploy to Staging Slot

```bash
# Create a zip file
cd publish
zip -r ../app.zip .
cd ..

# Deploy to staging slot
az webapp deployment source config-zip \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --src app.zip
```

### Validate Staging Deployment

1. Get the staging slot URL:
```bash
az webapp show \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --query defaultHostName -o tsv
```

2. Test the health endpoint:
```bash
curl https://<staging-url>/healthz
```
Expected response: `Healthy` with HTTP 200

3. Test the main page:
```bash
curl https://<staging-url>/
```

### Perform Slot Swap with Preview (Recommended)

This is the safest way to swap slots, allowing validation before completion.

#### Step 1: Start swap with preview

```bash
az webapp deployment slot swap \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --target-slot production \
  --action preview
```

#### Step 2: Validate the swap preview

During the preview phase:
- The staging slot is warmed up with production settings
- Health checks are performed automatically
- You can validate the staging slot is ready

Check health status:
```bash
curl https://<staging-url>/healthz
```

#### Step 3: Complete or cancel the swap

If validation passes, complete the swap:
```bash
az webapp deployment slot swap \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --target-slot production \
  --action swap
```

If validation fails, cancel the swap:
```bash
az webapp deployment slot swap \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --target-slot production \
  --action reset
```

### Simple Slot Swap (Less Safe)

If you need to perform a direct swap without preview:

```bash
az webapp deployment slot swap \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --target-slot production
```

**Note**: This is not recommended as it doesn't allow pre-swap validation.

## Post-Deployment Validation

1. Verify production health:
```bash
curl https://my-sre-appjapaneast.azurewebsites.net/healthz
```

2. Test the application:
```bash
curl https://my-sre-appjapaneast.azurewebsites.net/
```

3. Check Application Insights for telemetry:
```bash
az monitor app-insights component show \
  --app my-sre-appjapaneast-insights \
  --resource-group my-app-service-group
```

4. Monitor alerts in the Azure Portal:
   - Navigate to Azure Monitor > Alerts
   - Verify alerts are active and configured correctly

## Monitoring and Observability

### View Application Logs

```bash
az webapp log tail \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast
```

### View Slot Logs

```bash
az webapp log tail \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging
```

### Application Insights Queries

Access Application Insights in the Azure Portal to run queries:

**Check availability**:
```kusto
availabilityResults
| where timestamp > ago(1h)
| summarize AvailabilityPercentage = avg(success) * 100 by bin(timestamp, 5m)
```

**Check for errors**:
```kusto
exceptions
| where timestamp > ago(1h)
| summarize count() by type, outerMessage
```

**Check HTTP 5xx errors**:
```kusto
requests
| where timestamp > ago(1h)
| where resultCode startswith "5"
| summarize count() by resultCode, name
```

## Configuration Management

### Update Application Settings

To update app settings (e.g., enable/disable error injection):

```bash
az webapp config appsettings set \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --settings INJECT_ERROR=0
```

### Update Slot Settings

```bash
az webapp config appsettings set \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --settings INJECT_ERROR=1
```

## Troubleshooting

### Swap fails or causes downtime

1. Check health check status:
```bash
az webapp show \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --query siteConfig.healthCheckPath
```

2. Review Activity Log:
```bash
az monitor activity-log list \
  --resource-group my-app-service-group \
  --offset 1h
```

3. Check for alerts:
```bash
az monitor metrics alert list \
  --resource-group my-app-service-group
```

### Application not responding after swap

See [ROLLBACK.md](./ROLLBACK.md) for rollback procedures.

## Best Practices

1. **Always use swap with preview** for production deployments
2. **Monitor Application Insights** during and after swaps
3. **Test health endpoint** before completing swap
4. **Keep staging and production configurations in sync** (except for slot-specific settings like INJECT_ERROR)
5. **Set up alert notifications** to catch issues quickly
6. **Document any configuration changes** in version control
7. **Review IP restrictions** periodically to ensure appropriate access control

## References

- [Azure App Service deployment best practices](https://docs.microsoft.com/en-us/azure/app-service/deploy-best-practices)
- [Deployment slots overview](https://docs.microsoft.com/en-us/azure/app-service/deploy-staging-slots)
- [Application Insights for ASP.NET Core](https://docs.microsoft.com/en-us/azure/azure-monitor/app/asp-net-core)
- [Health checks in Azure App Service](https://docs.microsoft.com/en-us/azure/app-service/monitor-instances-health-check)
