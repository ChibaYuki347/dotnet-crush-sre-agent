# Implementation Summary: Prevent Downtime During Slot Swaps

This document summarizes the changes made to prevent the ~14 minute downtime incident that occurred on 2025-11-20 during a slot swap operation.

## Problem Statement

A recent slot swap on the Azure Web App `my-sre-appjapaneast` caused approximately 14 minutes of downtime. The root cause was identified as:
- No health checks configured
- Always On disabled (causing cold start issues)
- Application Insights not linked to the web app
- No warm-up configuration for slot swaps

## Solution Implemented

### 1. Application Changes

#### Health Check Endpoint (`/healthz`)
- **File Modified**: `Program.cs`
- **Change**: Added ASP.NET Core health checks middleware
- **Purpose**: Enables Azure App Service to validate application health before completing slot swaps
- **Testing**: Verified endpoint returns HTTP 200 with "Healthy" response

```csharp
builder.Services.AddHealthChecks();
app.MapHealthChecks("/healthz");
```

#### Application Insights Integration
- **Files Modified**: `Program.cs`, `SreAgentMemoryDemo.csproj`, `appsettings.json`
- **Change**: Added Application Insights telemetry SDK
- **Purpose**: Comprehensive observability for requests, exceptions, availability, and performance
- **Configuration**: Connection string managed via app settings (set by Bicep template)

```csharp
builder.Services.AddApplicationInsightsTelemetry();
```

### 2. Infrastructure as Code (Bicep)

Created comprehensive Azure infrastructure template implementing all SRE countermeasures:

#### Core Infrastructure (`infra/main.bicep`)

**App Service Plan**
- Linux-based plan supporting .NET 9.0
- Configurable SKU (default: B1, can scale to P1v2, etc.)

**Production Web App**
- ✅ Always On enabled (`alwaysOn: true`)
- ✅ Health check configured (`healthCheckPath: '/healthz'`)
- ✅ Preload enabled (`preloadEnabled: true`)
- ✅ Application Insights linked
- ✅ Warm-up configuration for slot swaps:
  - `WEBSITE_SWAP_WARMUP_PING_PATH: /healthz`
  - `WEBSITE_SWAP_WARMUP_PING_STATUSES: 200`
  - `WEBSITE_HEALTHCHECK_MAXPINGFAILURES: 3`

**Deployment Slot (Staging)**
- Identical configuration to production
- Error injection enabled (`INJECT_ERROR=1`) for testing
- Same health check and warm-up settings

**Application Insights**
- Dedicated component for the web app
- Linked to both production and staging slots
- Tracks availability, requests, exceptions, dependencies

**Auto-Heal Rules**
- Automatically recycles worker on repeated 5xx errors
- Trigger: 10× 5xx errors in 1 minute
- Action: Recycle worker after 1 minute minimum runtime

#### Monitoring & Alerting

**Action Group**
- Email notifications to admin@chiba-yuki.com
- Common alert schema enabled for rich notifications

**Metric Alerts**
1. **HTTP 5xx Error Alert**
   - Severity: 2 (Warning)
   - Trigger: More than 5× 5xx errors in 5 minutes
   - Evaluation: Every 1 minute

2. **Health Check Failure Alert**
   - Severity: 1 (High)
   - Trigger: Health check status < 100%
   - Evaluation: Every 1 minute

3. **Availability Alert**
   - Severity: 1 (High)
   - Trigger: Availability < 99%
   - Evaluation: Every 1 minute

**Activity Log Alert**
- Monitors all slot swap operations
- Alerts on both success and failure
- Provides immediate notification of swap events

### 3. Documentation

#### Deployment Guide (`infra/DEPLOYMENT.md`)
- Step-by-step infrastructure deployment instructions
- Application build and deployment procedures
- **Swap with Preview workflow** (recommended):
  1. Deploy to staging
  2. Start swap with preview
  3. Validate staging with production settings
  4. Complete or cancel swap based on validation
- Post-deployment validation checklist
- Monitoring and observability guidance
- Troubleshooting procedures

#### Rollback Runbook (`infra/ROLLBACK.md`)
- Multiple rollback options with expected recovery times:
  - **Option 1**: Immediate rollback via slot swap (30-60 seconds)
  - **Option 2**: Re-deploy known good version (2-5 minutes)
  - **Option 3**: Emergency restart (30-90 seconds)
  - **Option 4**: Scale out for auto-heal (2-5 minutes)
- Pre-rollback checklist
- Post-rollback diagnostic procedures
- Incident investigation guide
- Automated rollback script (`rollback.sh`)

#### Infrastructure README (`infra/README.md`)
- Overview of all resources created
- Quick start guide
- Configuration parameters
- Monitoring queries and dashboards
- Best practices
- Common troubleshooting scenarios

#### Main README Updates
- Added health check and Application Insights features
- Added quick start for local development
- Added Azure deployment instructions
- Updated file structure table
- Added monitoring examples
- Added links to infrastructure documentation

## Deployment Instructions

### Prerequisites
- Azure CLI installed
- Azure subscription: `68575d55-f60d-4d89-a32b-ad90af38faa6`
- Resource group: `my-app-service-group`

### Deploy Infrastructure

```bash
# Login and set subscription
az login
az account set --subscription "68575d55-f60d-4d89-a32b-ad90af38faa6"

# Deploy Bicep template
az deployment group create \
  --resource-group my-app-service-group \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json
```

### Deploy Application

```bash
# Build application
dotnet publish -c Release -o ./publish

# Create deployment package
cd publish && zip -r ../app.zip . && cd ..

# Deploy to staging
az webapp deployment source config-zip \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --src app.zip

# Validate health check
curl https://my-sre-appjapaneast-staging.azurewebsites.net/healthz

# Swap with preview (recommended)
az webapp deployment slot swap \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --target-slot production \
  --action preview

# After validation, complete the swap
az webapp deployment slot swap \
  --resource-group my-app-service-group \
  --name my-sre-appjapaneast \
  --slot staging \
  --target-slot production \
  --action swap
```

## Validation

### Health Check
```bash
curl https://my-sre-appjapaneast.azurewebsites.net/healthz
# Expected: "Healthy" with HTTP 200
```

### Application Insights
- Navigate to Azure Portal → Application Insights → my-sre-appjapaneast-insights
- Verify telemetry is being received
- Check availability metrics show 100%

### Alerts
- Navigate to Azure Portal → Monitor → Alerts
- Verify all alerts are enabled and configured

## Impact Assessment

### Before Implementation
- ❌ No health checks
- ❌ Always On disabled
- ❌ No Application Insights integration
- ❌ No monitoring alerts
- ❌ No warm-up during swaps
- ❌ No documented rollback procedures
- **Result**: 14 minutes downtime during slot swap

### After Implementation
- ✅ Health checks at `/healthz`
- ✅ Always On enabled
- ✅ Application Insights integrated
- ✅ Comprehensive monitoring alerts
- ✅ Automatic warm-up during swaps
- ✅ Documented rollback procedures
- ✅ Auto-heal rules for automatic recovery
- **Expected Result**: Zero downtime swaps with automatic validation

## Next Steps

1. **Deploy the infrastructure** using the Bicep template
2. **Deploy the application** to the staging slot
3. **Test the health endpoint** to ensure it's working
4. **Perform a test swap** using swap-with-preview
5. **Monitor Application Insights** for telemetry
6. **Verify alerts** are working by simulating failures (use staging slot with INJECT_ERROR=1)
7. **Document any environment-specific settings** in `main.parameters.json`
8. **Train team** on new deployment procedures and rollback runbook

## Security Summary

- ✅ CodeQL scan completed with **0 vulnerabilities**
- ✅ HTTPS enforced (httpsOnly: true)
- ✅ TLS 1.2 minimum (minTlsVersion: '1.2')
- ✅ FTPS disabled (ftpsState: 'Disabled')
- ✅ Diagnostic logging enabled
- ⚠️  IP restrictions set to "Allow all" - review if restriction needed for your use case

## Success Criteria

- [x] Health check endpoint implemented and tested
- [x] Application Insights integrated
- [x] Bicep template created with all countermeasures
- [x] Always On enabled
- [x] Deployment slot configured
- [x] Azure Monitor alerts created
- [x] Documentation completed (deployment guide, rollback runbook)
- [x] Code builds successfully
- [x] Security scan passed (0 vulnerabilities)

## References

- **Original Issue**: "App Broken When I increment numbers" (Prevent downtime during slot swaps for my-sre-app)
- **Bicep Template**: `infra/main.bicep`
- **Deployment Guide**: `infra/DEPLOYMENT.md`
- **Rollback Runbook**: `infra/ROLLBACK.md`
- **Infrastructure Docs**: `infra/README.md`

---

**Implementation Date**: 2025-11-20  
**Implemented By**: GitHub Copilot  
**Verified**: Application builds, health checks working, security scan passed
