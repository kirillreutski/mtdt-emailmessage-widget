import { LightningElement, api } from 'lwc';
import searchEmailMessages from '@salesforce/apex/EmailMessageBackupWidgetService.searchEmailMessages';
import EmailMessagePreviewModal from 'c/emailMessagePreviewModal';

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
            this.openEmailPreview(row);
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

    async openEmailPreview(row) {
        await EmailMessagePreviewModal.open({
            size: 'large',
            emailMessageId: row.id,
            emailMessageSubject: row.subject || '',
            previewFields: row.previewFields,
            previewFieldUrls: row.previewFieldUrls
        });
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
