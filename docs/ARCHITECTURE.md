# Cold-Chain Control Tower (CTC)

Real-world scenario: a logistics provider moving temperature-sensitive goods (vaccines, insulin, seafood, produce)
that needs one place to track shipments, react to temperature excursions and delays, and sign off on critical exceptions.

Deployed to the `devorg` Developer Edition org (namespace `testdev111`). Open the **CTC Control Tower** app.

## What is built, and which topic it demonstrates

| Area | Artifacts |
|---|---|
| Data modeling | `Shipment__c` (auto-number, external ID, formulas, cross-object formula, roll-ups incl. filtered, encrypted text, dependent picklist, global value set), `Shipment_Line__c` and `Shipment_Exception__c` (master-detail), `Carrier_Account__c` (junction, Carrier <-> Account), `Facility__c` (self-lookup hierarchy, geolocation), `Carrier__c` |
| Platform events | `Telemetry_Reading__e` (inbound IoT), `Exception_Raised__e` (outbound business event), both publish-after-commit |
| Configuration | `Temperature_Policy__mdt` (deployable bands), `Feature_Toggle__mdt` (kill switches), `Integration_Settings__c` (hierarchy setting), Custom Labels, Custom Permissions |
| Validation | Conditional mandatory, `ISCHANGED`/`PRIORVALUE`, `$Permission` bypass, cross-object contact/customer check |
| Flow | Before-save record-triggered flow (`Shipment_Before_Save_Status_Stamp`), screen flow quick-action target (`Report_Shipment_Exception`, with fault screen) |
| Approvals | `Critical_Exception_Approval` (entry criteria, queue approver, recall, final actions, lock until decided) |
| Apex | Trigger + handler (bulk, change detection, idempotent upsert on external id), `TelemetryService` (event subscriber: latest-wins, duplicate-safe, retryable on row lock), Queueable with finalizer + callout, Schedulable launcher with duplicate-job guard, Batchable + Stateful escalation, safe logging, feature toggles |
| Integration | Named Credential + External Credential (`Carrier_Tracking`), callout client with timeout, circuit breaker (`Integration_Settings__c`) and mocks |
| LWC | `shipmentBoard` (wire + keyset paging + debounced search + row action), `ctcKpiStrip`, `shipmentTemperatureCard` (LDS `getRecord`) |
| Security | 4 permission sets + 1 group, `with sharing`, `WITH USER_MODE`, `Database.queryWithBinds`, custom-permission gate on `syncCarrier`, Private OWD on Shipment |
| Testing | 6 test classes, 20 tests, test data factory, `System.runAs`, event bus delivery, HTTP mocks |

## Not implemented (design topics only)

Most of the topic list is operational, org-level or product-surface material that cannot be expressed as project metadata or that this org cannot support. Not built: Hyperforce/residency, multi-org strategy, editions/licensing beyond what the org has, Enhanced Domains, multi-currency, fiscal years, Big Objects, External Objects / Salesforce Connect, Shield encryption, SSO/SAML/OIDC/OAuth app registration, Pub/Sub API subscribers, CDC, Aura/Visualforce, packaging, DevOps Center/CI-CD, duplicate/matching rules, territory management, restriction/scoping rules, Experience Cloud sharing sets, reports/dashboards, Dynamic Forms, mobile config, translations. These can be added as follow-up slices.

## Operational notes

- The Named Credential points at `https://carrier-tracking.example.com` (placeholder). Callouts will fail until a real endpoint and external-credential principal are configured; tests use mocks.
- Developer Edition limits respected: ~5 MB data storage (seed is ~110 records), queueable chain depth capped at 4, small batch sizes.
- Seed script (`scripts/apex/seed-ctc-data.apex`) is idempotent: it upserts on external ids.
- Lookup filter on `Shipment__c.Contact__c` was replaced with validation rule `Contact_Matches_Customer` because the org rejected the `$Source` filter on a standard-object field.
