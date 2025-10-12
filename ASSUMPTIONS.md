# Assumptions

This document lists all assumptions made during the creation of this solution accelerator where specific requirements were not explicitly provided.

## Infrastructure & Deployment

### Azure Region
- **Assumption**: Primary deployment region is `westeurope`
- **Rationale**: Good balance of service availability, compliance (GDPR), and latency for European users
- **Override**: Set `location` parameter in bicep parameter files for different regions

### Resource Naming
- **Assumption**: Resources follow pattern `<prefix>-<env>-<service>-<random>`
- **Example**: `translator-dev-api-abc123`
- **Rationale**: Provides clear identification while ensuring global uniqueness

### Environment Tiers
- **Assumption**: Two environments: `dev` (development) and `prod` (production)
- **Override**: Extend infra/bicep/parameters/ for additional environments (staging, qa, etc.)

### Azure Translator SKU
- **Assumption**: 
  - Dev environment: `F0` (Free tier, 2M chars/month)
  - Prod environment: `S1` (Standard, pay-as-you-go)
- **Rationale**: Free tier sufficient for development and testing; S1 provides production SLAs

### App Service Plan
- **Assumption**:
  - Dev: `F1` (Free tier)
  - Prod: `P1v3` (Premium v3, 2 vCPU, 8 GB RAM)
- **Rationale**: Minimize dev costs; production tier supports autoscaling and VNet integration

### Storage Account
- **Assumption**: 
  - Dev: LRS (Locally Redundant Storage)
  - Prod: GRS (Geo-Redundant Storage)
- **Rationale**: Cost optimization for dev; production resilience

## Security & Authentication

### Managed Identity
- **Assumption**: System-assigned managed identity used for Azure resource access
- **Rationale**: Eliminates need for credential management, follows Azure best practices

### Key Vault Access
- **Assumption**: App Service uses Key Vault references for secrets (not SDK calls at runtime)
- **Rationale**: Simplifies code, automatic secret rotation, no additional API calls

### Local Development Authentication
- **Assumption**: Direct use of Translator API keys stored in `.env` file
- **Rationale**: Simpler developer onboarding; Managed Identity requires Azure authentication

### JWT Authentication
- **Assumption**: Optional JWT authentication is **not** implemented by default
- **Rationale**: Reduces complexity for accelerator demo; can be added via Azure AD B2C or Entra ID
- **Override**: Implement using `fastapi-azure-auth` or similar library

### CORS Policy
- **Assumption**: Development allows all origins; production restricts to frontend domain
- **Rationale**: Dev convenience; production security

## Application Design

### Translation Caching
- **Assumption**: No built-in caching of translation results
- **Rationale**: Demonstrates direct API integration; caching can be added with Redis
- **Future Enhancement**: Add Azure Cache for Redis for frequently translated content

### Batch Size
- **Assumption**: Maximum 100 texts per batch translation request
- **Rationale**: Azure Translator API limit (exact limit varies, documented at ~100 elements)

### Character Limits
- **Assumption**: Single text translation limited to 50,000 characters
- **Rationale**: Azure Translator documented limit per API call

### Supported Languages
- **Assumption**: All 100+ languages supported by Azure Translator are available
- **Source**: [Language Support Documentation](https://learn.microsoft.com/azure/ai-services/translator/language-support)

### Transliteration Support
- **Assumption**: Implemented for supported language pairs (e.g., Arabic, Chinese, Japanese, etc.)
- **Rationale**: Core Translator API feature, adds value to accelerator

### Document Translation
- **Assumption**: **Not implemented** in this accelerator
- **Rationale**: Requires separate Azure Translator Document Translation API, different architecture
- **Future Enhancement**: Can be added as separate feature set

## Data & Storage

### Sample Data
- **Assumption**: Sample texts in English, Spanish, French, German, Chinese, Arabic
- **Rationale**: Covers major languages and different scripts (Latin, CJK, RTL)

### Data Retention
- **Assumption**: Translation history stored for 30 days in Storage Table
- **Rationale**: Provides audit trail without excessive costs

### PII Handling
- **Assumption**: No special PII detection or masking
- **Rationale**: Accelerator demonstrates API capabilities; PII handling should be implemented per compliance requirements
- **Recommendation**: Integrate Azure Cognitive Services for PII detection in production

## Monitoring & Observability

### Application Insights Sampling
- **Assumption**: 
  - Dev: 100% sampling (all telemetry captured)
  - Prod: 20% sampling (cost optimization)
- **Override**: Adjust in app configuration

### Log Retention
- **Assumption**: 90 days in Log Analytics
- **Rationale**: Balance between compliance and cost

### Alerting
- **Assumption**: Basic alerts for error rate and availability only
- **Rationale**: Demonstrates pattern; extend for specific SLOs

## Testing

### Test Coverage Target
- **Assumption**: Minimum 70% code coverage for backend
- **Rationale**: Balance between quality and development speed for accelerator

### End-to-End Testing
- **Assumption**: Jupyter notebooks used for E2E testing (not Playwright/Selenium)
- **Rationale**: Easier to demonstrate and modify API workflows

### Load Testing
- **Assumption**: Not included in accelerator
- **Future Enhancement**: Add Azure Load Testing service integration

## Compliance & Governance

### Data Residency
- **Assumption**: All data processed within selected Azure region
- **Caveat**: Azure Translator may process data across regions for model improvements (per Azure terms)

### Audit Logging
- **Assumption**: Basic application logging to Application Insights
- **Enhancement**: Add Azure Activity Log and Diagnostic Settings for full audit trail

### Cost Controls
- **Assumption**: No automatic budget alerts configured
- **Override**: Set up Azure Cost Management budgets post-deployment

## Frontend & UX

### Browser Support
- **Assumption**: Modern evergreen browsers (Chrome, Firefox, Safari, Edge - last 2 versions)
- **Rationale**: Focuses on modern web standards, reduces polyfill overhead

### Mobile Responsiveness
- **Assumption**: Basic responsive design, optimized for desktop and tablet
- **Enhancement**: Full mobile-first design with PWA capabilities

### Accessibility
- **Assumption**: WCAG 2.1 Level AA target
- **Status**: Semantic HTML, ARIA labels, keyboard navigation implemented
- **Testing**: Manual testing recommended; automated tools (axe, Lighthouse) integrated

### Internationalization
- **Assumption**: UI available in English and Spanish
- **Rationale**: Demonstrates i18n pattern; easily extensible to more languages

## Development Tools

### Python Version
- **Assumption**: Python 3.11 or 3.12
- **Rationale**: Modern features, performance improvements, active support

### Node.js Version
- **Assumption**: Node.js 20 LTS
- **Rationale**: Long-term support, stable, modern JavaScript features

### Package Management
- **Assumption**: 
  - Backend: pip with requirements.txt
  - Frontend: npm with package-lock.json
- **Alternative**: Can use Poetry, pnpm, or yarn

### IDE/Editor
- **Assumption**: VS Code with dev container support
- **Rationale**: Broad adoption, excellent Azure tooling support

## CI/CD

### GitHub Actions
- **Assumption**: GitHub Actions used for CI/CD
- **Alternative**: Azure DevOps Pipelines (templates can be adapted)

### Deployment Strategy
- **Assumption**: 
  - Dev: Direct deployment on push to main
  - Prod: Gated deployment on release tag
- **Enhancement**: Add blue/green or canary deployment strategies

### Container Registry
- **Assumption**: Docker Hub for public images; Azure Container Registry for private
- **Override**: Configure in workflow files

## API Versioning

### Version Strategy
- **Assumption**: URL path versioning (`/api/v1/...`)
- **Rationale**: Clear, explicit, easy to document and maintain

### Backward Compatibility
- **Assumption**: This accelerator demonstrates current API version only
- **Production Guidance**: Maintain backward compatibility for at least one major version

## Rate Limiting & Quotas

### Application-Level Rate Limiting
- **Assumption**: Not implemented at application level
- **Rationale**: Azure Translator enforces rate limits; app can implement caching/queueing as needed

### Quota Monitoring
- **Assumption**: Tracked via Application Insights custom metrics
- **Alert**: Manual alert configuration recommended based on subscription limits

---

## Validation

These assumptions have been validated against:
- [x] Azure Translator REST API v3.0 documentation
- [x] Azure Well-Architected Framework
- [x] Azure Security Baseline for Cognitive Services
- [x] Microsoft Azure Landing Zones best practices

## Updating Assumptions

If any assumption is incorrect for your use case:

1. Review relevant bicep parameter files in `infra/bicep/parameters/`
2. Update environment variables in `.env` or Key Vault
3. Adjust application configuration in `src/backend/app/config.py`
4. Redeploy affected components

For questions or clarifications, please open an issue with label `assumptions`.

