
This sample .NET app demonstrates Azure App Service deployment slots, error simulation, and integration with the Azure SRE (Site Reliability Engineering) Agent for AI-assisted troubleshooting.

## Overview

- **Simulates HTTP 500 errors** in a controlled way, using the `INJECT_ERROR` app setting.
- **Tracks button clicks** and throws an error after several clicks when error injection is enabled.
- **Works with Azure App Service deployment slots**, making it easy to test failures without affecting production.

## How it Works

- **Normal Mode:** The main page shows a counter and two buttons: **Refresh** and **Reset Counter**.
- **Error Simulation:** If you set the `INJECT_ERROR` app setting to `1`, clicking "Refresh" 6 times will trigger an HTTP 500 error.
- **Slots:** Run in parallel (e.g., staging vs. production) to test error scenarios safely.

## Files

| File                          | Description                            |
|-------------------------------|----------------------------------------|
| Program.cs                    | Main app logic and web server setup    |
| appsettings.json              | App configuration (default)            |
| appsettings.Development.json  | Development environment config         |
| SreAgentMemoryDemo.csproj     | Project file                           |
| SreAgentMemoryDemo.http       | HTTP request samples                   |
| LICENSE                       | License for this sample                |
| README.md                     | Project documentation (this file)      |
