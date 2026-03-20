@IsTest
private class EmailMessageBackupWidgetServiceTest {
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');

            if (req.getEndpoint().endsWith('/search')) {
                res.setBody(
                    '{"sObject":"EmailMessage","items":[{"id":"02s123","fields":{"Subject":"Subj","FromAddress":"a@b.com","ToAddress":"c@d.com","MessageDate":"2026-01-01T00:00:00Z","Status":"New"},"system":{"is_deleted":false,"backup_run_id":123},"version":{"current_version_no":5}}]}'
                );
            } else {
                res.setBody('{"sObject":"EmailMessage","items":[]}');
            }
            return res;
        }
    }

    private class EmptyItemsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('{"sObject":"EmailMessage","items":[]}');
            return res;
        }
    }

    private class NullItemsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('{"sObject":"EmailMessage"}');
            return res;
        }
    }

    private class MultipleFieldsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody(
                '{"sObject":"EmailMessage","limit":50,"offset":0,"items":[' +
                '{"id":"02s1","fields":{"Subject":"First","FromAddress":"a@a.com"},"system":{"is_deleted":true},"version":{"current_version_no":1}},' +
                '{"id":"02s2","fields":{"Subject":"Second","ToAddress":"b@b.com"},"system":{},"version":{}},' +
                '{"id":"02s3","fields":{},"system":null,"version":null}' +
                ']}'
            );
            return res;
        }
    }

    private class VersionsWithItemsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody(
                '{"sObject":"EmailMessage","items":[' +
                '{"id":"02sv1","fields":{"Subject":"Version 1"}},' +
                '{"id":"02sv2","fields":{"Subject":"Version 2"}}' +
                ']}'
            );
            return res;
        }
    }

    private class AttachmentsWithItemsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody(
                '{"items":[' +
                '{"id":42,"fileName":"test-file.txt","title":"test-file","fileExtension":"txt","contentType":"TEXT","contentSize":16,"systemModstamp":"2026-03-20T16:36:22.000Z","isDeleted":false,"downloadPath":"/sf-widget/record-backups/EmailMessage/02s123/extensions/attachments/42/download"},' +
                '{"id":43,"fileName":"report.pdf","title":"report","fileExtension":"pdf","contentType":"APPLICATION_PDF","contentSize":1024,"systemModstamp":"2026-03-20T17:00:00.000Z","isDeleted":false,"downloadPath":"/sf-widget/record-backups/EmailMessage/02s123/extensions/attachments/43/download"}' +
                ']}'
            );
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('{"error":"boom"}');
            return res;
        }
    }

    private class ConfigMissingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // This mock should never be called - config check happens first.
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            return res;
        }
    }

    @IsTest
    static void searchEmailMessages_mapsFieldsAndHandlesResponse() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        List<EmailMessageBackupWidgetService.EmailMessageRow> rows =
            EmailMessageBackupWidgetService.searchEmailMessages('500xx0000000001');
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assertEquals('02s123', rows[0].id);
        System.assertEquals('Subj', rows[0].subject);
        System.assertEquals('a@b.com', rows[0].fromAddress);
        System.assertEquals('c@d.com', rows[0].toAddress);
        System.assertEquals('New', rows[0].status);
        System.assertEquals(5, rows[0].currentVersionNo);
        System.assertEquals(false, rows[0].isDeleted);
        System.assertEquals('Subj', rows[0].previewFields.get('Subject'));
    }

    @IsTest
    static void searchEmailMessages_throwsWhenIdMissing() {
        try {
            EmailMessageBackupWidgetService.searchEmailMessages(null);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('parentRecordId is required'));
        }
    }

    @IsTest
    static void searchEmailMessages_throwsWhenIdBlank() {
        try {
            EmailMessageBackupWidgetService.searchEmailMessages('   ');
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('parentRecordId is required'));
        }
    }

    @IsTest
    static void searchEmailMessages_emptyItemsReturnsEmptyList() {
        Test.setMock(HttpCalloutMock.class, new EmptyItemsMock());

        Test.startTest();
        List<EmailMessageBackupWidgetService.EmailMessageRow> rows =
            EmailMessageBackupWidgetService.searchEmailMessages('500xx0000000001');
        Test.stopTest();

        System.assertEquals(0, rows.size());
    }

    @IsTest
    static void searchEmailMessages_nullItemsReturnsEmptyList() {
        Test.setMock(HttpCalloutMock.class, new NullItemsMock());

        Test.startTest();
        List<EmailMessageBackupWidgetService.EmailMessageRow> rows =
            EmailMessageBackupWidgetService.searchEmailMessages('500xx0000000001');
        Test.stopTest();

        System.assertEquals(0, rows.size());
    }

    @IsTest
    static void searchEmailMessages_multipleItemsWithPartialData() {
        Test.setMock(HttpCalloutMock.class, new MultipleFieldsMock());

        Test.startTest();
        List<EmailMessageBackupWidgetService.EmailMessageRow> rows =
            EmailMessageBackupWidgetService.searchEmailMessages('500xx0000000001');
        Test.stopTest();

        System.assertEquals(3, rows.size());

        // First item with all data
        System.assertEquals('02s1', rows[0].id);
        System.assertEquals('First', rows[0].subject);
        System.assertEquals('a@a.com', rows[0].fromAddress);
        System.assertEquals(1, rows[0].currentVersionNo);
        System.assertEquals(true, rows[0].isDeleted);

        // Second item with partial data
        System.assertEquals('02s2', rows[1].id);
        System.assertEquals('Second', rows[1].subject);
        System.assertEquals('', rows[1].fromAddress);
        System.assertEquals(null, rows[1].currentVersionNo);
        System.assertEquals(null, rows[1].isDeleted);

        // Third item with empty fields
        System.assertEquals('02s3', rows[2].id);
        System.assertEquals('', rows[2].subject);
        System.assertEquals('', rows[2].fromAddress);
    }

    @IsTest
    static void versionsAndAttachments_workWithTypedDto() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        EmailMessageBackupWidgetService.VersionsResponseDto versions =
            EmailMessageBackupWidgetService.getEmailMessageVersions('02s123');
        EmailMessageBackupWidgetService.AttachmentsResponseDto attachments =
            EmailMessageBackupWidgetService.getEmailMessageAttachments('02s123');
        Test.stopTest();

        System.assertNotEquals(null, versions);
        System.assertNotEquals(null, attachments);
    }

    @IsTest
    static void versions_returnsItemsFromBackend() {
        Test.setMock(HttpCalloutMock.class, new VersionsWithItemsMock());

        Test.startTest();
        EmailMessageBackupWidgetService.VersionsResponseDto versions =
            EmailMessageBackupWidgetService.getEmailMessageVersions('02s123');
        Test.stopTest();

        System.assertNotEquals(null, versions);
        System.assertEquals(2, versions.items.size());
        System.assertEquals('02sv1', versions.items[0].id);
        System.assertEquals('Version 1', versions.items[0].fields.get('Subject'));
    }

    @IsTest
    static void attachments_returnsItemsFromBackend() {
        Test.setMock(HttpCalloutMock.class, new AttachmentsWithItemsMock());

        Test.startTest();
        EmailMessageBackupWidgetService.AttachmentsResponseDto attachments =
            EmailMessageBackupWidgetService.getEmailMessageAttachments('02s123');
        Test.stopTest();

        System.assertNotEquals(null, attachments);
        System.assertEquals(2, attachments.items.size());
        System.assertEquals(42, attachments.items[0].id);
        System.assertEquals('test-file.txt', attachments.items[0].fileName);
        System.assertEquals('txt', attachments.items[0].fileExtension);
        System.assertEquals('TEXT', attachments.items[0].contentType);
        System.assertEquals(16, attachments.items[0].contentSize);
        System.assertEquals('/sf-widget/record-backups/EmailMessage/02s123/extensions/attachments/42/download', attachments.items[0].downloadPath);
    }

    @IsTest
    static void versions_throwsWhenIdMissing() {
        try {
            EmailMessageBackupWidgetService.getEmailMessageVersions(null);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('emailMessageId is required'));
        }
    }

    @IsTest
    static void attachments_throwsWhenIdMissing() {
        try {
            EmailMessageBackupWidgetService.getEmailMessageAttachments('');
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('emailMessageId is required'));
        }
    }

    @IsTest
    static void calloutErrors_areSurfaced() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        try {
            EmailMessageBackupWidgetService.searchEmailMessages('500xx0000000001');
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Widget backend request failed'));
        }
    }

    @IsTest
    static void callout_includesUserContextHeaders() {
        UserContextVerifyMock verifyMock = new UserContextVerifyMock();
        Test.setMock(HttpCalloutMock.class, verifyMock);

        Test.startTest();
        EmailMessageBackupWidgetService.searchEmailMessages('500xx0000000001');
        Test.stopTest();

        System.assertNotEquals(null, verifyMock.receivedRequest);
        System.assertNotEquals(null, verifyMock.receivedRequest.getHeader('x-user-id'));
        System.assertNotEquals(null, verifyMock.receivedRequest.getHeader('x-profile-id'));
    }

    @IsTest
    static void searchEmailMessages_previewTableColumnsIncludesSubject() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        List<EmailMessageBackupWidgetService.EmailMessageRow> rows =
            EmailMessageBackupWidgetService.searchEmailMessages('500xx0000000001');
        Test.stopTest();

        System.assertEquals(1, rows.size());
        System.assert(rows[0].previewTableColumns.contains('Subject'));
    }

    @IsTest
    static void searchRequestDto_getString_returnsCorrectJson() {
        EmailMessageBackupWidgetService.SearchRequestDto dto =
            new EmailMessageBackupWidgetService.SearchRequestDto();
        dto.sObjectType = 'EmailMessage';
        dto.ParentId = '500xx0000000001';
        dto.x_limit = 50;
        dto.offset = 0;
        dto.include_deleted = true;

        Test.startTest();
        String json = dto.getString();
        Test.stopTest();

        System.assert(json.contains('"sObject":"EmailMessage"'));
        System.assert(json.contains('"ParentId":"500xx0000000001"'));
        System.assert(json.contains('"limit":50'));
        System.assert(json.contains('"offset":0'));
        System.assert(json.contains('"include_deleted":true'));
        // Ensure no Apex-internal field names leak into JSON
        System.assert(!json.contains('x_limit'));
        System.assert(!json.contains('sObjectType'));
    }

    @IsTest
    static void searchEmailMessages_sendsCorrectRequestBody() {
        RequestBodyVerifyMock verifyMock = new RequestBodyVerifyMock();
        Test.setMock(HttpCalloutMock.class, verifyMock);

        Test.startTest();
        EmailMessageBackupWidgetService.searchEmailMessages('500xx0000000001');
        Test.stopTest();

        System.assertNotEquals(null, verifyMock.receivedBody);
        System.assert(verifyMock.receivedBody.contains('"sObject":"EmailMessage"'));
        System.assert(verifyMock.receivedBody.contains('"ParentId":"500xx0000000001"'));
        System.assert(verifyMock.receivedBody.contains('"limit":'));
        System.assert(verifyMock.receivedBody.contains('"offset":'));
        System.assert(verifyMock.receivedBody.contains('"include_deleted":'));
    }

    @IsTest
    static void getAttachmentDownloadUrl_returnsSignedUrl() {
        Test.setMock(HttpCalloutMock.class, new DownloadUrlMock());

        Test.startTest();
        String url = EmailMessageBackupWidgetService.getAttachmentDownloadUrl('/sf-widget/record-backups/EmailMessage/02s123/extensions/attachments/42/download');
        Test.stopTest();

        System.assertEquals('https://storage.example.com/signed-download-url', url);
    }

    @IsTest
    static void getAttachmentDownloadUrl_throwsWhenPathMissing() {
        try {
            EmailMessageBackupWidgetService.getAttachmentDownloadUrl(null);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('downloadPath is required'));
        }
    }

    @IsTest
    static void getAttachmentDownloadUrl_throwsWhenPathBlank() {
        try {
            EmailMessageBackupWidgetService.getAttachmentDownloadUrl('   ');
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('downloadPath is required'));
        }
    }

    private class DownloadUrlMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('{"url":"https://storage.example.com/signed-download-url"}');
            return res;
        }
    }

    private class UserContextVerifyMock implements HttpCalloutMock {
        HttpRequest receivedRequest;

        public HttpResponse respond(HttpRequest req) {
            receivedRequest = req;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('{"sObject":"EmailMessage","items":[]}');
            return res;
        }
    }

    private class RequestBodyVerifyMock implements HttpCalloutMock {
        String receivedBody;

        public HttpResponse respond(HttpRequest req) {
            receivedBody = req.getBody();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('{"sObject":"EmailMessage","items":[]}');
            return res;
        }
    }
}
