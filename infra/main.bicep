// Azure Web App with Deployment Slot - SRE Best Practices
// This Bicep template implements countermeasures to prevent downtime during slot swaps

@description('The name of the web app')
param webAppName string = 'my-sre-appjapaneast'

@description('Location for all resources')
param location string = 'japaneast'

@description('The name of the App Service Plan')
param appServicePlanName string = 'my-app-service-plan'

@description('The pricing tier for the App Service Plan')
@allowed([
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1v2'
  'P2v2'
  'P3v2'
])
param sku string = 'B1'

@description('Name of the deployment slot')
param slotName string = 'staging'

@description('Email address for alert notifications')
param alertEmail string = 'admin@chiba-yuki.com'

// Variables
var appInsightsName = '${webAppName}-insights'
var actionGroupName = '${webAppName}-alerts'
var healthCheckPath = '/healthz'

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: sku
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Production Web App
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|9.0'
      alwaysOn: true  // Prevent cold starts
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      healthCheckPath: healthCheckPath
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'INJECT_ERROR'
          value: '0'  // Disabled in production
        }
        {
          name: 'WEBSITE_HEALTHCHECK_MAXPINGFAILURES'
          value: '3'
        }
        {
          name: 'WEBSITE_SWAP_WARMUP_PING_PATH'
          value: healthCheckPath
        }
        {
          name: 'WEBSITE_SWAP_WARMUP_PING_STATUSES'
          value: '200'
        }
      ]
    }
  }
}

// Web App Configuration (separate resource for better control)
resource webAppConfig 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: webApp
  name: 'web'
  properties: {
    numberOfWorkers: 1
    defaultDocuments: []
    netFrameworkVersion: 'v9.0'
    requestTracingEnabled: true
    requestTracingExpirationTime: '9999-12-31T23:59:59Z'
    httpLoggingEnabled: true
    logsDirectorySizeLimit: 35
    detailedErrorLoggingEnabled: true
    publishingUsername: '$${webAppName}'
    scmType: 'None'
    use32BitWorkerProcess: false
    webSocketsEnabled: false
    managedPipelineMode: 'Integrated'
    virtualApplications: [
      {
        virtualPath: '/'
        physicalPath: 'site\\wwwroot'
        preloadEnabled: true  // Enable preload for faster startups
      }
    ]
    loadBalancing: 'LeastRequests'
    autoHealEnabled: true
    autoHealRules: {
      triggers: {
        statusCodes: [
          {
            status: 500
            subStatus: 0
            count: 10
            timeInterval: '00:01:00'
          }
        ]
      }
      actions: {
        actionType: 'Recycle'
        minProcessExecutionTime: '00:01:00'
      }
    }
    cors: {
      allowedOrigins: [
        '*'
      ]
    }
    localMySqlEnabled: false
    ipSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 1
        name: 'Allow all'
        description: 'Public access - review if restriction needed'
      }
    ]
    scmIpSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 1
        name: 'Allow all'
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
    http20Enabled: true
    minTlsVersion: '1.2'
    ftpsState: 'Disabled'
    preWarmedInstanceCount: 1
  }
}

// Deployment Slot (Staging)
resource deploymentSlot 'Microsoft.Web/sites/slots@2023-12-01' = {
  parent: webApp
  name: slotName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNETCORE|9.0'
      alwaysOn: true  // Prevent cold starts in staging too
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      healthCheckPath: healthCheckPath
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'INJECT_ERROR'
          value: '1'  // Enabled in staging for testing
        }
        {
          name: 'WEBSITE_HEALTHCHECK_MAXPINGFAILURES'
          value: '3'
        }
        {
          name: 'WEBSITE_SWAP_WARMUP_PING_PATH'
          value: healthCheckPath
        }
        {
          name: 'WEBSITE_SWAP_WARMUP_PING_STATUSES'
          value: '200'
        }
      ]
    }
  }
}

// Slot Configuration (separate resource for better control)
resource slotConfig 'Microsoft.Web/sites/slots/config@2023-12-01' = {
  parent: deploymentSlot
  name: 'web'
  properties: {
    numberOfWorkers: 1
    defaultDocuments: []
    netFrameworkVersion: 'v9.0'
    requestTracingEnabled: true
    requestTracingExpirationTime: '9999-12-31T23:59:59Z'
    httpLoggingEnabled: true
    logsDirectorySizeLimit: 35
    detailedErrorLoggingEnabled: true
    use32BitWorkerProcess: false
    webSocketsEnabled: false
    managedPipelineMode: 'Integrated'
    virtualApplications: [
      {
        virtualPath: '/'
        physicalPath: 'site\\wwwroot'
        preloadEnabled: true  // Enable preload for faster startups
      }
    ]
    loadBalancing: 'LeastRequests'
    autoHealEnabled: true
    autoHealRules: {
      triggers: {
        statusCodes: [
          {
            status: 500
            subStatus: 0
            count: 10
            timeInterval: '00:01:00'
          }
        ]
      }
      actions: {
        actionType: 'Recycle'
        minProcessExecutionTime: '00:01:00'
      }
    }
    cors: {
      allowedOrigins: [
        '*'
      ]
    }
    localMySqlEnabled: false
    ipSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 1
        name: 'Allow all'
        description: 'Public access - review if restriction needed'
      }
    ]
    scmIpSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 1
        name: 'Allow all'
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
    http20Enabled: true
    minTlsVersion: '1.2'
    ftpsState: 'Disabled'
    preWarmedInstanceCount: 1
  }
}

// Action Group for Alerts
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'global'
  properties: {
    groupShortName: 'SREAlerts'
    enabled: true
    emailReceivers: [
      {
        name: 'EmailAdmin'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

// Alert: HTTP 5xx Errors
resource alert5xx 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${webAppName}-5xx-alert'
  location: 'global'
  properties: {
    description: 'Alert when HTTP 5xx error rate is high'
    severity: 2
    enabled: true
    scopes: [
      webApp.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Http5xxCriteria'
          metricName: 'Http5xx'
          metricNamespace: 'Microsoft.Web/sites'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Total'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// Alert: Health Check Failures
resource alertHealthCheck 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${webAppName}-healthcheck-alert'
  location: 'global'
  properties: {
    description: 'Alert when health check fails'
    severity: 1
    enabled: true
    scopes: [
      webApp.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HealthCheckStatusCriteria'
          metricName: 'HealthCheckStatus'
          metricNamespace: 'Microsoft.Web/sites'
          operator: 'LessThan'
          threshold: 100
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// Alert: Availability
resource alertAvailability 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${webAppName}-availability-alert'
  location: 'global'
  properties: {
    description: 'Alert when availability drops below 99%'
    severity: 1
    enabled: true
    scopes: [
      appInsights.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'AvailabilityCriteria'
          metricName: 'availabilityResults/availabilityPercentage'
          metricNamespace: 'Microsoft.Insights/components'
          operator: 'LessThan'
          threshold: 99
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// Activity Log Alert for Slot Swap Failures
resource activityLogAlertSlotSwap 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: '${webAppName}-slot-swap-alert'
  location: 'global'
  properties: {
    description: 'Alert on slot swap operations and failures'
    enabled: true
    scopes: [
      resourceGroup().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Administrative'
        }
        {
          field: 'operationName'
          equals: 'Microsoft.Web/sites/slots/slotsswap/action'
        }
        {
          field: 'resourceId'
          equals: webApp.id
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroup.id
        }
      ]
    }
  }
}

// Outputs
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output slotUrl string = 'https://${deploymentSlot.properties.defaultHostName}'
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output healthCheckPath string = healthCheckPath
