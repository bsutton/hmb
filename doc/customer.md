# Customer Domain Model

## Purpose
Define customer-related entities and relationships so we can model:
- Property owners
- Tenants
- Property managers (real estate agents)
- Owners corporations (body corporate)

without relying on job-specific hardcoded fields.

## Current Constraints
The current model stores tenant as `job.tenant_contact_id`, which is too narrow:
- It binds tenant to a contact instead of a customer/party.
- It cannot represent multiple concurrent relationships (e.g. tenant + manager + owners corporation).
- It does not handle relationship history or per-site scope well.

## Proposed Core Entities

### Customer
Represents any external party.

`customer_type` should be expanded to include:
- `owner`
- `tenant`
- `propertyManager` (display: Real Estate Agent)
- `ownersCorporation` (display alias in AU/NZ: Body Corporate)
- existing types remain for backward compatibility

Notes:
- A single customer may hold multiple roles in real life. If needed later, move to role table.
- For now, keep one primary `customer_type` and add relationship semantics in a join table.

### Contact
Unchanged. Contacts remain person records linked to one or more customers.

### Site
Unchanged. Physical property/location.

## New Relationship Entity

### CustomerRelationship
A generic relationship table between customers.

Suggested fields:
- `id`
- `from_customer_id` (FK customer)
- `to_customer_id` (FK customer)
- `relationship_type` (enum)
- `site_id` nullable (FK site)
- `is_primary` boolean
- `start_date` nullable
- `end_date` nullable
- `notes` nullable
- `created_date`
- `modified_date`

Suggested relationship types:
- `tenantOf`
- `managedBy`
- `managedFor`
- `representedBy`
- `ownerOfSite`
- `memberOfOwnersCorporation`
- `coveredByOwnersCorporation`

Direction convention:
- Use explicit, directional labels.
- Example: tenant -> owner uses `tenantOf`.

## Key Scenarios

### 1. Tenant with known owner and manager
- Tenant customer linked to owner via `tenantOf` (optionally scoped to `site_id`).
- Tenant or owner linked to property manager via `managedBy` / `managedFor`.

### 2. Tenant known, owner unknown
- Create tenant customer now.
- Create job against tenant (temporary business truth).
- Add owner relationship later when discovered.

### 3. Owners corporation involved
- Site linked to owners corporation via `coveredByOwnersCorporation`.
- Tenant and/or owner linked to owners corporation where relevant.

## Job Model Direction
- Stop using tenant-specific job fields as the primary model.
- Keep existing fields temporarily for compatibility/migration.
- Resolve tenant/owner/manager from `customer_relationship` + `site_id` when needed.

## UI Direction

### Job Creator Wizard
- Remove tenant as a contact selector in Contact step.
- Treat extracted tenant as a customer candidate when owner is unknown.
- Allow optional linking to referrer/owner/owners corporation after customer is selected/created.

### Customer UI
Add a "Related Parties" section:
- Link customer to another customer with relationship type.
- Optional site scoping.
- Ability to reassign/move tenant between owner/manager links.

## Migration Strategy
1. Add new `CustomerType` enum values.
2. Add `customer_relationship` table + DAO/entity.
3. Introduce UI to create/manage relationships.
4. Migrate read-paths to relationship-based resolution.
5. Deprecate `job.tenant_contact_id` after compatibility window.

## Open Decisions
- Should `Customer` support multiple simultaneous roles (role join table) now or later?
- Exact minimal `relationship_type` enum for v1.
- Whether relationship uniqueness is enforced by `(from, to, type, site, end_date is null)`.
- Regional display labels for `ownersCorporation` / `bodyCorporate`.
