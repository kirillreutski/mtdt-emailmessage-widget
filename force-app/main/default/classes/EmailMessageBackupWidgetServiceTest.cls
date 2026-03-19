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

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('{"error":"boom"}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        insert new WidgetBackendConfig__mdt(
            DeveloperName = 'Default',
            MasterLabel = 'Default',
            BaseUrl__c = 'https://example.org',
            WidgetToken__c = 'token-123',
            TimeoutMs__c = 10000
        );
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
    static void calloutErrors_areSurfaced() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        try {
            EmailMessageBackupWidgetService.searchEmailMessages('500xx0000000001');
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Widget backend request failed'));
        }
    }
}
