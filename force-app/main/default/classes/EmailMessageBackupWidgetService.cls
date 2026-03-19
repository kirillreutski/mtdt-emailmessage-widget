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
    }

    public class SearchRequestDto {
        public String sObject;
        public String ParentId;
        public Integer limit;
        public Integer offset;
    }

    public class SearchResponseDto {
        public String sObject;
        public String data_backup_id;
        public List<BackupItemDto> items;
        public Integer limit;
        public Integer offset;
    }

    public class BackupItemDto {
        public String id;
        public String sObject;
        public Map<String, Object> fields;
        public SystemDto system;
        public VersionDto version;
    }

    public class SystemDto {
        public Boolean is_deleted;
        public Integer backup_run_id;
    }

    public class VersionDto {
        public Integer current_version_no;
    }

    public class VersionsResponseDto {
        public String sObject;
        public String data_backup_id;
        public List<BackupItemDto> items;
    }

    public class AttachmentsResponseDto {
        public String sObject;
        public String data_backup_id;
        public List<BackupItemDto> items;
    }

    @AuraEnabled(cacheable=false)
    public static List<EmailMessageRow> searchEmailMessages(String parentRecordId) {
        if (String.isBlank(parentRecordId)) {
            throw new AuraHandledException('parentRecordId is required');
        }

        SearchRequestDto requestDto = new SearchRequestDto();
        requestDto.sObject = 'EmailMessage';
        requestDto.ParentId = parentRecordId;
        requestDto.limit = DEFAULT_LIMIT;
        requestDto.offset = DEFAULT_OFFSET;

        HttpResponse response = sendRequest('POST', SEARCH_PATH, JSON.serialize(requestDto));
        SearchResponseDto payload =
            (SearchResponseDto) JSON.deserialize(response.getBody(), SearchResponseDto.class);
        return mapRows(payload);
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
        return (VersionsResponseDto) JSON.deserialize(response.getBody(), VersionsResponseDto.class);
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
        return (AttachmentsResponseDto) JSON.deserialize(response.getBody(), AttachmentsResponseDto.class);
    }

    private static List<EmailMessageRow> mapRows(SearchResponseDto payload) {
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
            row.isDeleted = item != null && item.system != null ? item.system.is_deleted : null;
            rows.add(row);
        }
        return rows;
    }

    private static String valueFromFields(BackupItemDto item, String key) {
        if (item == null || item.fields == null || !item.fields.containsKey(key) || item.fields.get(key) == null) {
            return '';
        }
        return String.valueOf(item.fields.get(key));
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
}
