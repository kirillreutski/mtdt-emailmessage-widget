<a href="https://githubsfdeploy.herokuapp.com?owner=kirillreutski&repo=mtdt-emailmessage-widget&ref=main">
  <img alt="Deploy to Salesforce"
       src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>

# MTDT EmailMessage Widget (Salesforce Package)

This package adds an LWC widget to the Case record page and displays backup `EmailMessage` records where `ParentId = recordId`.

## Contents

- `emailMessageBackupWidget` (LWC) for `lightning__RecordPage` (Case)
- `EmailMessageBackupWidgetService` (Apex) with 3 methods:
  - `searchEmailMessages(String parentRecordId)`
  - `getEmailMessageVersions(String emailMessageId)`
  - `getEmailMessageAttachments(String emailMessageId)`
- `WidgetBackendConfig__mdt` + record `WidgetBackendConfig.Default`
- `EmailMessageWidget` Permission Set

## Installation

1. Deploy metadata:
   - `sf project deploy start --source-dir force-app --target-org <alias>`
2. Assign the permission set to users:
   - `sf org assign permset --name EmailMessageWidget --target-org <alias>`
3. Update custom metadata `WidgetBackendConfig.Default`:
   - `BaseUrl__c` = backend host (without trailing `/`)
   - `WidgetToken__c` = widget bearer token
   - `TimeoutMs__c` = callout timeout in ms (for example, `10000`)
4. Add **Email Message Backup Widget** to the Case Record Page in Lightning App Builder.

## Behavior (Stage 1)

- The LWC automatically receives the page `recordId`.
- It calls `searchEmailMessages(recordId)` in Apex.
- Apex builds the backend request body:
  - `sObject = EmailMessage`
  - `ParentId = recordId`
  - `limit = 50`
  - `offset = 0`
- The UI renders a table with:
  - `Subject`
  - `FromAddress`
  - `ToAddress`
  - `MessageDate`
  - `Status`
- Loading / empty / error states are implemented.

## Where to plug in versions and attachments (Stage 2)

- The LWC already has `selectedEmailMessageId` (row selection).
- Next step:
  - on selection, call Apex `getEmailMessageVersions(selectedEmailMessageId)` and/or `getEmailMessageAttachments(selectedEmailMessageId)`
  - render a separate tab/section under the table.
- The Apex methods are already implemented and ready to be used from the UI.

## Config and trade-off

This implementation uses `Custom Metadata` to store the base URL and token (pragmatic approach).

Pros:
- simple to deploy and maintain
- all settings in one place, without hardcoding in LWC

Cons:
- the token is not stored as a secret in a dedicated credential store

For production hardening, the next step is to switch to `Named Credential + External Credential` and store the token as a credential secret.