# Google Maps Configuration

HMB uses a Google Maps Platform API key for mailing route optimisation,
address validation suggestions, and opening delivery navigation in Google Maps.

## Required API

Enable these APIs for the API key used by HMB:

- **Routes API**
- **Address Validation API**
- **Places API (New)**

The mailing route optimiser calls the Routes API `computeRoutes` endpoint with
waypoint order optimisation. In the Google Cloud API Library this is listed as:

> Routes API
> Performance optimized versions of the Directions and Distance Matrix APIs

The address validation workflow calls the Address Validation API to validate and
standardise selected recipient addresses before route planning.

When Address Validation cannot produce a useful correction, HMB calls Places
Autocomplete from Places API (New) to find likely address candidates. Each
candidate is then passed back through Address Validation before it can be saved.

## Quota Expectations

The mailing **Validate** action uses the Address Validation API and persists
successful site validation with the returned latitude and longitude. Once a site
has `geocodeStatus` of `ok`, HMB treats the address as valid and does not
revalidate it unless a user edits the site address in HMB or route optimisation
later proves that the address cannot be routed.

Places API (New) is only used for invalid or route-failed addresses where HMB
needs candidate suggestions. It is not called for already validated addresses.

The mailing **Route** action uses the Routes API `computeRoutes` endpoint. HMB
submits selected recipients in chunks of up to 25 stops, so a normal 116-stop
mailing should use about five Routes API requests. Extra Routes API requests
can occur only when Google cannot compute a route for a chunk and HMB splits
that chunk to identify the failing address.

Do not enable **Route Optimization API** for this feature. That is a separate
Google API for fleet and shipment optimisation, and the current HMB mailing
route code does not call it.

## API Key Restrictions

If the API key is restricted by API, include **Routes API**, **Address
Validation API**, and **Places API (New)** in the allowed APIs. If the key is
restricted by application, use the restriction that matches the deployed HMB
platform.

Billing must be enabled in the Google Cloud project for Google Maps Platform
requests to succeed.
