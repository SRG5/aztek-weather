# Azure Region Choice (Decision Note)

## Selected region

**North Europe (`northeurope`)**

## Why

For a home assignment, the goal was to choose a region that:
- Supports all required Azure services (App Service, PostgreSQL Flexible Server, Key Vault, Front Door)
- Is cost-aware compared to other common EU regions
- Keeps deployment simple (single-region)

## Trade-offs / notes

- Single-region deployment means a regional outage would impact availability.
- Azure Front Door provides a stable public entry point; multi-region failover is a potential future enhancement.

## How to change

The region is controlled via Terraform variables:
- `location`
- `location_short`

See: `infra/terraform/terraform.tfvars.example`
