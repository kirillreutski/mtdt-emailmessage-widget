import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import getEmailMessageVersions from '@salesforce/apex/EmailMessageBackupWidgetService.getEmailMessageVersions';
import getEmailMessageAttachments from '@salesforce/apex/EmailMessageBackupWidgetService.getEmailMessageAttachments';

export default class EmailMessagePreviewModal extends LightningModal {
    @api emailMessageId;
    @api emailMessageSubject;
    @api previewFields;
    @api previewFieldUrls;
    @api previewTableColumns;

    modalIsLoading = true;
    modalErrorMessage = '';

    versionsCount = 0;
    attachments = [];
    previewEntries = [];

    fromAddress = '';
    toAddress = '';
    ccAddress = '';
    bccAddress = '';
    htmlBody = '';
    textBody = '';

    connectedCallback() {
        this.buildPreviewModel();
        this.loadDetails();
    }

    buildPreviewModel() {
        const fieldsObj = this.previewFields || {};

        this.fromAddress = this.getFirstField(fieldsObj, ['FromAddress']);
        this.toAddress = this.getFirstField(fieldsObj, ['ToAddress']);
        this.ccAddress = this.getFirstField(fieldsObj, ['CcAddress', 'CCAddress']);
        this.bccAddress = this.getFirstField(fieldsObj, ['BccAddress', 'BCCAddress']);

        this.htmlBody = this.getFirstField(fieldsObj, ['HtmlBody', 'HTMLBody']);
        this.textBody = this.getFirstField(fieldsObj, ['TextBody', 'TextBodyPlain', 'PlainTextBody']);

        const excludeKeys = new Set([
            'FromAddress',
            'ToAddress',
            'CcAddress',
            'BccAddress',
            'CCAddress',
            'BCCAddress',
            'HtmlBody',
            'HTMLBody',
            'TextBody',
            'TextBodyPlain',
            'PlainTextBody'
        ]);
        const allowedColumns = new Set(this.previewTableColumns || []);
        allowedColumns.add('Subject'); // Subject is always displayed in the table
        this.previewEntries = this.toPreviewEntries(
            this.previewFields,
            this.previewFieldUrls,
            excludeKeys,
            allowedColumns
        );
    }

    getFirstField(fieldsObj, keys) {
        for (const key of keys) {
            const v = fieldsObj ? fieldsObj[key] : null;
            if (v !== null && v !== undefined && v !== '') {
                return String(v);
            }
        }
        return '';
    }

    async loadDetails() {
        this.modalIsLoading = true;
        this.modalErrorMessage = '';
        this.versionsCount = 0;
        this.attachments = [];

        if (!this.emailMessageId) {
            this.modalIsLoading = false;
            this.modalErrorMessage = 'emailMessageId is required.';
            return;
        }

        try {
            const [versions, attachmentsResponse] = await Promise.all([
                getEmailMessageVersions({ emailMessageId: this.emailMessageId }),
                getEmailMessageAttachments({ emailMessageId: this.emailMessageId })
            ]);

            this.versionsCount =
                versions && Array.isArray(versions.items) ? versions.items.length : 0;
            this.attachments = this.normalizeAttachments(attachmentsResponse);
        } catch (error) {
            this.modalErrorMessage = this.reduceError(error);
        } finally {
            this.modalIsLoading = false;
        }
    }

    handleClose() {
        this.close();
    }

    toPreviewEntries(previewFields, previewFieldUrls, excludeKeys, allowedColumns) {
        const fieldsObj = previewFields || {};
        const urlsObj = previewFieldUrls || {};
        const exclude = excludeKeys || new Set();
        const allowed = allowedColumns || new Set();
        const entries = Object.keys(fieldsObj).map((key) => ({
            key,
            value: fieldsObj[key],
            url: urlsObj[key] || '',
            hasUrl: urlsObj[key] ? true : false,
            excluded: exclude.has(key)
        }));

        const preferredOrder = ['Subject', 'FromAddress', 'ToAddress', 'MessageDate', 'Status'];
        entries.sort((a, b) => {
            const ai = preferredOrder.indexOf(a.key);
            const bi = preferredOrder.indexOf(b.key);
            const aRank = ai === -1 ? 999 : ai;
            const bRank = bi === -1 ? 999 : bi;
            if (aRank !== bRank) return aRank - bRank;
            return a.key.localeCompare(b.key);
        });

        return entries
            .filter((e) => !e.excluded)
            .filter((e) => allowed.has(e.key))
            .filter((e) => e.value !== null && e.value !== undefined && e.value !== '');
    }

    normalizeAttachments(attachmentsResponse) {
        const items =
            attachmentsResponse && Array.isArray(attachmentsResponse.items) ? attachmentsResponse.items : [];
        return items.map((item) => {
            const fields = item.fields || {};
            return {
                id: item.id,
                fields,
                fieldsEntries: this.toFieldsEntries(fields)
            };
        });
    }

    toFieldsEntries(fieldsObj) {
        const obj = fieldsObj || {};
        return Object.keys(obj)
            .map((key) => ({ key, value: obj[key] }))
            .filter((e) => e.value !== null && e.value !== undefined && e.value !== '');
    }

    get hasAttachments() {
        return Array.isArray(this.attachments) && this.attachments.length > 0;
    }

    reduceError(error) {
        if (!error) {
            return 'Unknown error';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((entry) => entry.message).join(', ');
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        return error.message || 'Unknown error';
    }
}

