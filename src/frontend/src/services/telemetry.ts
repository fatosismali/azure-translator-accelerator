/**
 * Application Insights telemetry service for frontend
 */

import { ApplicationInsights } from '@microsoft/applicationinsights-web'

const connectionString = import.meta.env.VITE_APPINSIGHTS_CONNECTION_STRING

let appInsights: ApplicationInsights | null = null

if (connectionString) {
  appInsights = new ApplicationInsights({
    config: {
      connectionString,
      enableAutoRouteTracking: true,
      disableFetchTracking: false,
      enableRequestHeaderTracking: true,
      enableResponseHeaderTracking: true,
    },
  })
  appInsights.loadAppInsights()
  appInsights.trackPageView()
  console.log('[Telemetry] Application Insights initialized')
} else {
  console.warn('[Telemetry] Application Insights not configured')
}

export const trackEvent = (name: string, properties?: Record<string, any>) => {
  if (appInsights) {
    appInsights.trackEvent({ name }, properties)
  }
}

export const trackException = (error: Error, properties?: Record<string, any>) => {
  if (appInsights) {
    appInsights.trackException({ exception: error }, properties)
  }
}

export const trackMetric = (name: string, value: number, properties?: Record<string, any>) => {
  if (appInsights) {
    appInsights.trackMetric({ name, average: value }, properties)
  }
}

export default appInsights

