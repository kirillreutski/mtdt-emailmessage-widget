import { LightningElement, api } from 'lwc';
import searchEmailMessages from '@salesforce/apex/EmailMessageBackupWidgetService.searchEmailMessages';
import EmailMessagePreviewModal from 'c/emailMessagePreviewModal';
import { reduceError } from 'c/emailMessageUtils';

const SUBJECT_COLUMN = {
    label: 'Subject',
    fieldName: 'subject',
    type: 'button',
    typeAttributes: {
        label: { fieldName: 'subjectDisplay' },
        name: 'preview',
        variant: 'base'
    }
};

const NO_SUBJECT_LABEL = '(no subject)';

function tokenToFieldName(token) {
    // `MessageDate` -> `messageDate`
    if (!token) {
        return '';
    }
    return token.charAt(0).toLowerCase() + token.slice(1);
}

function buildColumnsFromTokens(tokens) {
    const seen = new Set(['Subject']);
    const result = [SUBJECT_COLUMN];

    (tokens || []).forEach((token) => {
        if (!token || token === 'Subject' || seen.has(token)) {
            return;
        }
        seen.add(token);
        result.push({
            label: token,
            fieldName: tokenToFieldName(token),
            type: 'text'
        });
    });

    return result;
}

export default class EmailMessageBackupWidget extends LightningElement {
    _recordId;

    columns = [SUBJECT_COLUMN];
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

            const tokens =
                payload && payload.length && payload[0].previewTableColumns
                    ? payload[0].previewTableColumns
                    : ['Subject'];
            this.columns = buildColumnsFromTokens(tokens);

            this.rows = (payload || []).map((item) => {
                const previewFields = item.previewFields || {};
                const previewFieldUrls = item.previewFieldUrls || {};
                const subject = item.subject || previewFields.Subject || '';
                const row = {
                    id: item.id,
                    subject,
                    subjectDisplay: subject || NO_SUBJECT_LABEL,
                    previewFields,
                    previewFieldUrls,
                    // Keep for backward compatibility / modal params.
                    previewTableColumns: item.previewTableColumns || []
                };

                tokens.forEach((token) => {
                    if (!token || token === 'Subject') {
                        return;
                    }
                    const fieldName = tokenToFieldName(token);

                    const hasKey =
                        previewFields &&
                        Object.prototype.hasOwnProperty.call(previewFields, token);
                    const rawVal = hasKey ? previewFields[token] : item[fieldName];

                    row[fieldName] = rawVal !== null && rawVal !== undefined ? rawVal : '';
                });

                return row;
            });
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
}

