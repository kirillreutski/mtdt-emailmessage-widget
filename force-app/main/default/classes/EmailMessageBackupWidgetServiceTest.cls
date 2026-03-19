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
                '{"sObject":"EmailMessage","items":[' +
                '{"id":"00P1","fields":{"Name":"file.pdf","ContentType":"application/pdf"}},' +
                '{"id":"00P2","fields":{"Name":"image.png","ContentType":"image/png"}}' +
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
        System.assertEquals('00P1', attachments.items[0].id);
        System.assertEquals('file.pdf', attachments.items[0].fields.get('Name'));
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
}
