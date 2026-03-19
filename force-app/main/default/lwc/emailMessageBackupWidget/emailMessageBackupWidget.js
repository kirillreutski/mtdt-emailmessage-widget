import { LightningElement, api } from 'lwc';
import searchEmailMessages from '@salesforce/apex/EmailMessageBackupWidgetService.searchEmailMessages';
import getEmailMessageVersions from '@salesforce/apex/EmailMessageBackupWidgetService.getEmailMessageVersions';
import getEmailMessageAttachments from '@salesforce/apex/EmailMessageBackupWidgetService.getEmailMessageAttachments';

const COLUMNS = [
    {
        label: 'Subject',
        fieldName: 'subject',
        type: 'button',
        typeAttributes: {
            label: { fieldName: 'subject' },
            name: 'preview',
            variant: 'base'
        }
    },
    { label: 'FromAddress', fieldName: 'fromAddress', type: 'text' },
    { label: 'ToAddress', fieldName: 'toAddress', type: 'text' },
    { label: 'MessageDate', fieldName: 'messageDate', type: 'text' },
    { label: 'Status', fieldName: 'status', type: 'text' }
];

export default class EmailMessageBackupWidget extends LightningElement {
    _recordId;

    columns = COLUMNS;
    rows = [];
    errorMessage = '';
    isLoading = false;
    hideCheckboxColumnValue = true;

    isModalOpen = false;
    modalErrorMessage = '';
    modalIsLoading = false;
    selectedEmailId = null;
    selectedEmailSubject = '';
    previewEntries = [];
    versionsCount = 0;
    attachments = [];

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadRows();
        }
    }

    async loadRows() {
        if (!this._recordId) {
            this.errorMessage = 'recordId is not available on this page.';
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        this.rows = [];

        try {
            const payload = await searchEmailMessages({ parentRecordId: this._recordId });
            this.rows = (payload || []).map((item) => ({
                id: item.id,
                subject: item.subject || '',
                fromAddress: item.fromAddress || '',
                toAddress: item.toAddress || '',
                messageDate: item.messageDate || '',
                status: item.status || '',
                previewFields: item.previewFields || {},
                previewFieldUrls: item.previewFieldUrls || {}
            }));
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleRefresh() {
        this.loadRows();
    }

    handleRowAction(event) {
        const actionName = event.detail.action && event.detail.action.name;
        const row = event.detail.row;
        if (!actionName || !row) {
            return;
        }
        if (actionName === 'preview') {
            this.openEmailPreviewModal(row);
        }
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.errorMessage && !this.hasRows;
    }

    get hideCheckboxColumn() {
        return this.hideCheckboxColumnValue;
    }

    openEmailPreviewModal(row) {
        this.selectedEmailId = row.id;
        this.selectedEmailSubject = row.subject || '';
        this.previewEntries = this.toPreviewEntries(row.previewFields, row.previewFieldUrls);
        this.versionsCount = 0;
        this.attachments = [];
        this.modalErrorMessage = '';
        this.isModalOpen = true;
        this.modalIsLoading = true;

        Promise.all([
            getEmailMessageVersions({ emailMessageId: this.selectedEmailId }),
            getEmailMessageAttachments({ emailMessageId: this.selectedEmailId })
        ])
            .then(([versions, attachmentsResponse]) => {
                this.versionsCount =
                    versions && Array.isArray(versions.items) ? versions.items.length : 0;
                this.attachments = this.normalizeAttachments(attachmentsResponse);
            })
            .catch((error) => {
                this.modalErrorMessage = this.reduceError(error);
            })
            .finally(() => {
                this.modalIsLoading = false;
            });
    }

    closeModal() {
        this.isModalOpen = false;
        this.modalErrorMessage = '';
        this.modalIsLoading = false;
        this.selectedEmailId = null;
        this.selectedEmailSubject = '';
        this.previewEntries = [];
        this.versionsCount = 0;
        this.attachments = [];
    }

    toPreviewEntries(previewFields, previewFieldUrls) {
        const fieldsObj = previewFields || {};
        const urlsObj = previewFieldUrls || {};
        const entries = Object.keys(fieldsObj).map((key) => ({
            key,
            value: fieldsObj[key],
            url: urlsObj[key] || '',
            hasUrl: urlsObj[key] ? true : false
        }));

        // Prefer the most important keys on top.
        const preferredOrder = ['Subject', 'FromAddress', 'ToAddress', 'MessageDate', 'Status'];
        entries.sort((a, b) => {
            const ai = preferredOrder.indexOf(a.key);
            const bi = preferredOrder.indexOf(b.key);
            const aRank = ai === -1 ? 999 : ai;
            const bRank = bi === -1 ? 999 : bi;
            if (aRank !== bRank) return aRank - bRank;
            return a.key.localeCompare(b.key);
        });

        return entries.filter((e) => e.value !== null && e.value !== undefined && e.value !== '');
    }

    normalizeAttachments(attachmentsResponse) {
        const items = attachmentsResponse && Array.isArray(attachmentsResponse.items) ? attachmentsResponse.items : [];
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
