public with sharing class EmailMessageBackupWidgetService {
    private static final String SEARCH_PATH = '/sf-widget/record-backups/search';
    private static final Integer DEFAULT_LIMIT = 50;
    private static final Integer DEFAULT_OFFSET = 0;

    public class EmailMessageRow {
        @AuraEnabled public String id;
        @AuraEnabled public String subject;
        @AuraEnabled public String fromAddress;
        @AuraEnabled public String toAddress;
        @AuraEnabled public String messageDate;
        @AuraEnabled public String status;
        @AuraEnabled public Integer currentVersionNo;
        @AuraEnabled public Boolean isDeleted;
        // Used by the LWC modal to show a full preview of the backend EmailMessage fields.
        @AuraEnabled public Map<String, String> previewFields;
        // For specific reference fields (e.g., ParentId), provide URL like `/<id>` for the LWC.
        @AuraEnabled public Map<String, String> previewFieldUrls;
        // Configured list of keys to show in the main table (LWC list view).
        // `Subject` is always included.
        @AuraEnabled public List<String> previewTableColumns;
    }

    public class SearchResponseDto {
        // NOTE: Field names intentionally avoid Apex reserved words.
        // Response JSON is normalized before deserialization.
        public String sObjectType;
        public String data_backup_id;
        public List<BackupItemDto> items;
        public Integer limitValue;
        public Integer offsetValue;
    }

    public class SearchRequestDto {
        public String sObject;
        public String ParentId;
        public Integer x_limit;
        public Integer offset;
        public Boolean include_deleted;

        public String getString() {
            Map<String, Object> jsonMap = new Map<String, Object>();
            jsonMap.put('sObject', this.sObject);
            jsonMap.put('ParentId', this.ParentId);
            jsonMap.put('limit', this.x_limit);
            jsonMap.put('offset', this.offset);
            jsonMap.put('include_deleted', this.include_deleted);
            return JSON.serialize(jsonMap);
        }
    }

    public class BackupItemDto {
        @AuraEnabled public String id;
        @AuraEnabled public String sObjectType;
        @AuraEnabled public Map<String, String> fields;
        @AuraEnabled public SystemDto systemDto;
        @AuraEnabled public VersionDto version;
    }

    public class SystemDto {
        @AuraEnabled public Boolean is_deleted;
        @AuraEnabled public Integer backup_run_id;
    }

    public class VersionDto {
        @AuraEnabled public Integer current_version_no;
    }

    public class VersionsResponseDto {
        @AuraEnabled public String sObjectType;
        @AuraEnabled public String data_backup_id;
        @AuraEnabled public List<BackupItemDto> items;
    }

    public class AttachmentsResponseDto {
        @AuraEnabled public String sObjectType;
        @AuraEnabled public String data_backup_id;
        @AuraEnabled public List<BackupItemDto> items;
    }

    @AuraEnabled(cacheable=false)
    public static List<EmailMessageRow> searchEmailMessages(String parentRecordId) {
        if (String.isBlank(parentRecordId)) {
            throw new AuraHandledException('parentRecordId is required');
        }

        SearchRequestDto requestDto = new SearchRequestDto();
        requestDto.sObject = 'EmailMessage';
        requestDto.ParentId = parentRecordId;
        requestDto.x_limit = DEFAULT_LIMIT;
        requestDto.offset = DEFAULT_OFFSET;
        requestDto.include_deleted = true;

        String requestBody = requestDto.getString();

        HttpResponse response = sendRequest('POST', SEARCH_PATH, requestBody);
        SearchResponseDto payload = (SearchResponseDto) JSON.deserialize(
            normalizeResponseJson(response.getBody()),
            SearchResponseDto.class
        );
        List<String> previewTableColumns = getConfiguredPreviewTableColumns();
        return mapRows(payload, previewTableColumns);
    }

    @AuraEnabled(cacheable=false)
    public static VersionsResponseDto getEmailMessageVersions(String emailMessageId) {
        if (String.isBlank(emailMessageId)) {
            throw new AuraHandledException('emailMessageId is required');
        }

        String path =
            '/sf-widget/record-backups/EmailMessage/' + EncodingUtil.urlEncode(emailMessageId, 'UTF-8') +
            '/versions';
        HttpResponse response = sendRequest('GET', path, null);
        return (VersionsResponseDto) JSON.deserialize(
            normalizeResponseJson(response.getBody()),
            VersionsResponseDto.class
        );
    }

    @AuraEnabled(cacheable=false)
    public static AttachmentsResponseDto getEmailMessageAttachments(String emailMessageId) {
        if (String.isBlank(emailMessageId)) {
            throw new AuraHandledException('emailMessageId is required');
        }

        String path =
            '/sf-widget/record-backups/EmailMessage/' + EncodingUtil.urlEncode(emailMessageId, 'UTF-8') +
            '/extensions/attachments';
        HttpResponse response = sendRequest('GET', path, null);
        return (AttachmentsResponseDto) JSON.deserialize(
            normalizeResponseJson(response.getBody()),
            AttachmentsResponseDto.class
        );
    }

    private static List<EmailMessageRow> mapRows(SearchResponseDto payload, List<String> previewTableColumns) {
        List<EmailMessageRow> rows = new List<EmailMessageRow>();
        if (payload == null || payload.items == null) {
            return rows;
        }

        for (BackupItemDto item : payload.items) {
            EmailMessageRow row = new EmailMessageRow();
            row.id = item != null ? item.id : null;
            row.subject = valueFromFields(item, 'Subject');
            row.fromAddress = valueFromFields(item, 'FromAddress');
            row.toAddress = valueFromFields(item, 'ToAddress');
            row.messageDate = valueFromFields(item, 'MessageDate');
            row.status = valueFromFields(item, 'Status');
            row.currentVersionNo =
                item != null && item.version != null ? item.version.current_version_no : null;
            row.isDeleted =
                item != null && item.systemDto != null ? item.systemDto.is_deleted : null;
            row.previewFields =
                item != null && item.fields != null ? item.fields : new Map<String, String>();
            row.previewFieldUrls = new Map<String, String>();
            enrichPreviewReferenceFields(row.previewFields, row.previewFieldUrls);
            row.previewTableColumns =
                previewTableColumns != null ? previewTableColumns : new List<String>();
            rows.add(row);
        }
        return rows;
    }

    private static String valueFromFields(BackupItemDto item, String key) {
        if (item == null || item.fields == null || !item.fields.containsKey(key) || item.fields.get(key) == null) {
            return '';
        }
        return item.fields.get(key);
    }

    private static List<String> getConfiguredPreviewTableColumns() {
        // Field is optional; fall back to Subject-only.
        WidgetBackendConfig__mdt config = WidgetBackendConfig__mdt.getInstance('Default');
        String raw = config != null ? config.EmailPreviewTableColumns__c : null;
        return parsePreviewTableColumns(raw);
    }

    private static List<String> parsePreviewTableColumns(String raw) {
        // Subject is always present regardless of configuration.
        List<String> result = new List<String>();
        Set<String> seen = new Set<String>();
        addColumn(result, seen, 'Subject');

        if (String.isBlank(raw)) {
            return result;
        }

        // Delimiters: whitespace, comma, dot, semicolon.
        // Using a regex split handles newlines as well.
        for (String token : raw.split('[\\s,.;]+')) {
            if (token == null) {
                continue;
            }
            String cleaned = token.trim();
            if (String.isBlank(cleaned)) {
                continue;
            }
            addColumn(result, seen, cleaned);
        }

        return result;
    }

    private static void addColumn(List<String> columns, Set<String> seen, String columnKey) {
        if (String.isBlank(columnKey)) {
            return;
        }
        if (seen.contains(columnKey)) {
            return;
        }
        columns.add(columnKey);
        seen.add(columnKey);
    }

    private static void enrichPreviewReferenceFields(
        Map<String, String> previewFields,
        Map<String, String> previewFieldUrls
    ) {
        if (previewFields == null || previewFields.isEmpty()) {
            return;
        }

        // These keys come from backend `items[].fields` and can store Salesforce reference IDs.
        enrichReferenceId(previewFields, previewFieldUrls, 'ActivityId');
        enrichReferenceId(previewFields, previewFieldUrls, 'CreatedById');
        enrichReferenceId(previewFields, previewFieldUrls, 'LastModifiedById');
        enrichReferenceId(previewFields, previewFieldUrls, 'ParentId');
        enrichReferenceId(previewFields, previewFieldUrls, 'RelatedToId');
    }

    private static void enrichReferenceId(
        Map<String, String> previewFields,
        Map<String, String> previewFieldUrls,
        String fieldKey
    ) {
        if (!previewFields.containsKey(fieldKey)) {
            return;
        }

        String refId = previewFields.get(fieldKey);
        if (String.isBlank(refId)) {
            return;
        }

        SObject sobj = getSObjectById(refId);
        if (sobj == null) {
            return;
        }

        String nameValue;
        try {
            nameValue = (String) sobj.get('Name');
        } catch (Exception e) {
            nameValue = null;
        }
        if (String.isBlank(nameValue)) {
            nameValue = refId;
        }

        // Replace the raw Id with the Name for better UX.
        previewFields.put(fieldKey, nameValue);
        // LWC will render a link with `/<id>` which Salesforce will open in a new tab.
        previewFieldUrls.put(fieldKey, '/' + refId);
    }

    // Helper: return the SObject by Id (or null if invalid/unqueryable).
    private static SObject getSObjectById(String recordId) {
        if (String.isBlank(recordId)) {
            return null;
        }

        Id recordIdTyped;
        try {
            recordIdTyped = (Id) recordId;
        } catch (Exception e) {
            return null;
        }

        Schema.SObjectType sType = recordIdTyped.getSObjectType();
        Schema.DescribeSObjectResult describe = sType.getDescribe();
        Boolean hasName = describe.fields.getMap().containsKey('Name');

        String sObjectName = describe.getName();
        String soql = hasName
            ? 'SELECT Name FROM ' + sObjectName + ' WHERE Id = :recordIdTyped LIMIT 1'
            : 'SELECT Id FROM ' + sObjectName + ' WHERE Id = :recordIdTyped LIMIT 1';

        try {
            List<SObject> results = Database.query(soql);
            return results.isEmpty() ? null : results[0];
        } catch (Exception e) {
            return null;
        }
    }

    private static HttpResponse sendRequest(String method, String path, String body) {
        WidgetBackendConfig__mdt config = WidgetBackendConfig__mdt.getInstance('Default');
        if (config == null || String.isBlank(config.BaseUrl__c) || String.isBlank(config.WidgetToken__c)) {
            throw new AuraHandledException(
                'Widget backend config is missing. Configure WidgetBackendConfig.Default custom metadata.'
            );
        }

        HttpRequest request = new HttpRequest();
        request.setMethod(method);
        request.setEndpoint(buildUrl(config.BaseUrl__c, path));
        request.setHeader('Authorization', 'Bearer ' + config.WidgetToken__c);
        // User context headers for backend auditing/authorization.
        request.setHeader('x-user-id', getCurrentUserId());
        request.setHeader('x-profile-id', getCurrentProfileId());
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');
        Integer timeoutMs = config.TimeoutMs__c == null ? 10000 : Integer.valueOf(config.TimeoutMs__c);
        request.setTimeout(timeoutMs);

        if (body != null) {
            request.setBody(body);
        }

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new AuraHandledException(
                'Widget backend request failed: ' + response.getStatusCode() + ' ' + response.getStatus()
            );
        }
        return response;
    }

    private static String buildUrl(String baseUrl, String path) {
        String normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        String normalizedPath = path.startsWith('/') ? path : '/' + path;
        return normalizedBase + normalizedPath;
    }

    // Replace JSON keys that conflict with Apex reserved identifiers.
    private static String normalizeResponseJson(String json) {
        if (json == null) {
            return null;
        }
        // Use exact key replacements to avoid altering values.
        String normalized = json;
        normalized = normalized.replace('"sObject"', '"sObjectType"');
        normalized = normalized.replace('"system"', '"systemDto"');
        normalized = normalized.replace('"limit"', '"limitValue"');
        normalized = normalized.replace('"offset"', '"offsetValue"');
        return normalized;
    }

    private static String getCurrentUserId() {
        return String.valueOf(UserInfo.getUserId());
    }

    private static String getCurrentProfileId() {
        try {
            User u = [
                SELECT ProfileId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            return u.ProfileId != null ? String.valueOf(u.ProfileId) : '';
        } catch (Exception e) {
            // Fail soft: still attempt the callout even if profile id lookup fails.
            return '';
        }
    }
}
