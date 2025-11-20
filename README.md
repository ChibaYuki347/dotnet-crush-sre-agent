
This sample .NET app demonstrates Azure App Service deployment slots, error simulation, and integration with the Azure SRE (Site Reliability Engineering) Agent for AI-assisted troubleshooting.

## Overview

- **Simulates HTTP 500 errors** in a controlled way, using the `INJECT_ERROR` app setting.
- **Tracks button clicks** and throws an error after several clicks when error injection is enabled.
- **Works with Azure App Service deployment slots**, making it easy to test failures without affecting production.
- **Includes health checks** (`/healthz` endpoint) for reliable deployment slot swaps.
- **Application Insights integration** for comprehensive telemetry and monitoring.
- **Infrastructure as Code** with Bicep templates for best-practice Azure deployments.

## How it Works

- **Normal Mode:** The main page shows a counter and two buttons: **Increment** and **Reset Counter**.
- **Error Simulation:** If you set the `INJECT_ERROR` app setting to `1`, clicking "Increment" 6 times will trigger an HTTP 500 error.
- **Slots:** Run in parallel (e.g., staging vs. production) to test error scenarios safely.
- **Health Checks:** The `/healthz` endpoint ensures the application is healthy before slot swaps complete.

## Quick Start

### Local Development

```bash
# Build the application
dotnet build

# Run the application
dotnet run

# Access the application
# Main page: http://localhost:5000
# Health check: http://localhost:5000/healthz
```

### Azure Deployment

See [infra/README.md](./infra/README.md) for complete infrastructure deployment instructions.

Quick deployment:
```bash
# Deploy infrastructure
az deployment group create \
  --resource-group my-app-service-group \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json

# Deploy application to staging
dotnet publish -c Release -o ./publish
cd publish && zip -r ../app.zip . && cd ..
az webapp deployment source config-zip \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --src app.zip

# Swap to production (with preview)
az webapp deployment slot swap \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --target-slot production \
  --action preview
```

## Files

| File/Directory                | Description                                        |
|-------------------------------|---------------------------------------------------|
| Program.cs                    | Main app logic, web server setup, health checks   |
| appsettings.json              | App configuration (includes App Insights)         |
| appsettings.Development.json  | Development environment config                     |
| SreAgentMemoryDemo.csproj     | Project file with dependencies                     |
| SreAgentMemoryDemo.http       | HTTP request samples                               |
| infra/                        | Infrastructure as Code (Bicep templates)           |
| infra/main.bicep              | Azure resources definition                         |
| infra/main.parameters.json    | Deployment parameters                              |
| infra/DEPLOYMENT.md           | Deployment guide and best practices                |
| infra/ROLLBACK.md             | Rollback runbook for failed deployments            |
| infra/README.md               | Infrastructure documentation                       |
| LICENSE                       | License for this sample                            |
| README.md                     | Project documentation (this file)                  |

## Features

### Application Features
- **Button click counter** with persistent state (cookies)
- **Error injection** for testing failure scenarios
- **Health check endpoint** (`/healthz`) for monitoring
- **Application Insights telemetry** for observability

### Infrastructure Features (Bicep)
- **Always On enabled** - prevents cold starts
- **Health checks configured** - validates health before slot swaps
- **Application Insights linked** - comprehensive telemetry
- **Deployment slot (staging)** - safe testing environment
- **Azure Monitor alerts** - 5xx errors, availability, health checks, slot swaps
- **Auto-heal rules** - automatic recovery from failures
- **Preload enabled** - faster startup and warm-up

## Endpoints

- `/` - Main application page (button click counter)
- `/healthz` - Health check endpoint (returns "Healthy" with HTTP 200)

## Configuration

### Application Settings

| Setting | Description | Default (Production) | Default (Staging) |
|---------|-------------|---------------------|-------------------|
| `INJECT_ERROR` | Enable error simulation | `0` (disabled) | `1` (enabled) |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | App Insights connection | Set by Bicep | Set by Bicep |
| `WEBSITE_HEALTHCHECK_MAXPINGFAILURES` | Health check threshold | `3` | `3` |
| `WEBSITE_SWAP_WARMUP_PING_PATH` | Warm-up endpoint | `/healthz` | `/healthz` |

### Environment Variables

- `INJECT_ERROR=1` - Enable error simulation (errors occur on 6th button click)
- `INJECT_ERROR=0` - Disable error simulation (normal operation)

## SRE Best Practices Implemented

This application demonstrates several SRE best practices:

1. **Health Checks** - `/healthz` endpoint for liveness/readiness probes
2. **Observability** - Application Insights integration for metrics, logs, traces
3. **Deployment Safety** - Slot swaps with health validation before production
4. **Auto-Healing** - Automatic recovery from failures
5. **Monitoring & Alerting** - Proactive alerts for availability and errors
6. **Rollback Procedures** - Documented runbook for quick recovery
7. **Infrastructure as Code** - Repeatable, version-controlled infrastructure

## Monitoring

### Application Insights Queries

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

**HTTP 5xx errors**:
```kusto
requests
| where timestamp > ago(1h)
| where resultCode startswith "5"
| summarize count() by resultCode, name
```

## Troubleshooting

### Application not responding after deployment
See [infra/ROLLBACK.md](./infra/ROLLBACK.md) for rollback procedures.

### Health check failing
1. Check application logs: `az webapp log tail --name my-sre-appjapaneast --resource-group my-app-service-group`
2. Verify `/healthz` endpoint: `curl https://my-sre-appjapaneast.azurewebsites.net/healthz`
3. Review Application Insights for exceptions

### Error simulation not working
1. Verify `INJECT_ERROR=1` is set
2. Clear browser cookies (counter is cookie-based)
3. Click "Increment" button 6 times

## Documentation

- [Infrastructure Documentation](./infra/README.md) - Infrastructure overview and setup
- [Deployment Guide](./infra/DEPLOYMENT.md) - Step-by-step deployment instructions
- [Rollback Runbook](./infra/ROLLBACK.md) - Recovery procedures for failed deployments

## References

- [Azure App Service deployment best practices](https://docs.microsoft.com/en-us/azure/app-service/deploy-best-practices)
- [Deployment slots overview](https://docs.microsoft.com/en-us/azure/app-service/deploy-staging-slots)
- [Application Insights for ASP.NET Core](https://docs.microsoft.com/en-us/azure/azure-monitor/app/asp-net-core)
- [Health checks in Azure App Service](https://docs.microsoft.com/en-us/azure/app-service/monitor-instances-health-check)

