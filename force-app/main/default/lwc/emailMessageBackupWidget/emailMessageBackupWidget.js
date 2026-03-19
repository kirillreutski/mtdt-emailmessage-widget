import { LightningElement, api } from 'lwc';
import searchEmailMessages from '@salesforce/apex/EmailMessageBackupWidgetService.searchEmailMessages';

const COLUMNS = [
    { label: 'Subject', fieldName: 'subject', type: 'text' },
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
    selectedEmailMessageId = null;

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
                status: item.status || ''
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

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows || [];
        this.selectedEmailMessageId = selectedRows.length ? selectedRows[0].id : null;
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && !this.errorMessage && !this.hasRows;
    }

    get extensionHint() {
        if (!this.selectedEmailMessageId) {
            return 'Выберите строку, чтобы в следующем шаге подключить версии и attachments.';
        }
        return `Точка расширения: selectedEmailMessageId = ${this.selectedEmailMessageId}`;
    }

    get hideCheckboxColumn() {
        // Keep checkbox visible for single-row selection.
        return false;
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
