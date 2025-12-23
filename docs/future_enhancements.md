# Future Enhancements

This project intentionally keeps the implementation minimal to match the assignment scope.
Below are reasonable next steps if this were to evolve beyond the exercise.

## Application

1. **Application Insights / OpenTelemetry instrumentation**
   - Add structured logging, request tracing, dependency tracing (OpenWeather + DB)
   - Surface exceptions and slow requests

2. **Caching**
   - Add Redis caching per-city for a short TTL to reduce external API calls

3. **Validation & resiliency**
   - Better input validation for city names
   - Rate limiting / abuse protection
   - Retries + timeouts for external calls (OpenWeather)

4. **Testing**
   - Unit tests for parsing/formatting forecast results
   - Integration tests for `/save` + `/saved`

## Infrastructure

5. **Private networking**
   - VNet integration for App Service
   - Private Endpoint for PostgreSQL + Key Vault
   - Remove public DB access

6. **CI/CD**
   - GitHub Actions: lint + test + deploy
   - `terraform plan` on PR and `apply` on main

7. **Safer deployments**
   - Deployment slots (staging/production) and swap
   - Blue/green or canary rollout

8. **Monitoring & alerting**
   - Alerts on error rate, response latency, and DB connectivity
   - Dashboards for request volume and failures
