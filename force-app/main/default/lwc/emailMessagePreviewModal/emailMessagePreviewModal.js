import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import getEmailMessageVersions from '@salesforce/apex/EmailMessageBackupWidgetService.getEmailMessageVersions';
import getEmailMessageAttachments from '@salesforce/apex/EmailMessageBackupWidgetService.getEmailMessageAttachments';
import getAttachmentDownloadUrl from '@salesforce/apex/EmailMessageBackupWidgetService.getAttachmentDownloadUrl';
import { reduceError } from 'c/emailMessageUtils';

const CONTENT_TYPE_ICONS = {
    PDF: 'doctype:pdf',
    TEXT: 'doctype:txt',
    IMAGE: 'doctype:image',
    WORD: 'doctype:word',
    EXCEL: 'doctype:excel',
    POWER_POINT: 'doctype:ppt',
    CSV: 'doctype:csv',
    XML: 'doctype:xml',
    HTML: 'doctype:html',
    ZIP: 'doctype:zip',
    DEFAULT: 'doctype:attachment'
};

export default class EmailMessagePreviewModal extends LightningModal {
    @api emailMessageId;
    @api emailMessageSubject;
    @api previewFields;
    @api previewFieldUrls;

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
            'Subject',
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
        this.previewEntries = this.toPreviewEntries(this.previewFields, this.previewFieldUrls, excludeKeys);
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
            this.modalErrorMessage = reduceError(error);
        } finally {
            this.modalIsLoading = false;
        }
    }

    handleClose() {
        this.close();
    }

    async handleDownload(event) {
        const downloadPath = event.currentTarget.dataset.path;
        if (!downloadPath) {
            return;
        }

        try {
            const downloadUrl = await getAttachmentDownloadUrl({ downloadPath });
            if (downloadUrl) {
                window.open(downloadUrl, '_blank');
            }
        } catch (error) {
            this.modalErrorMessage = reduceError(error);
        }
    }

    toPreviewEntries(previewFields, previewFieldUrls, excludeKeys) {
        const fieldsObj = previewFields || {};
        const urlsObj = previewFieldUrls || {};
        const exclude = excludeKeys || new Set();
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
            .filter((e) => e.value !== null && e.value !== undefined && e.value !== '');
    }

    normalizeAttachments(attachmentsResponse) {
        const items =
            attachmentsResponse && Array.isArray(attachmentsResponse.items) ? attachmentsResponse.items : [];
        return items.map((item) => ({
            id: item.id,
            fileName: item.fileName || 'Unknown',
            title: item.title || item.fileName || 'Unknown',
            fileExtension: item.fileExtension || '',
            contentType: item.contentType || '',
            contentSize: this.formatFileSize(item.contentSize),
            systemModstamp: item.systemModstamp || '',
            isDeleted: item.isDeleted || false,
            downloadPath: item.downloadPath || '',
            icon: this.getAttachmentIcon(item.contentType, item.fileExtension)
        }));
    }

    formatFileSize(bytes) {
        if (!bytes || bytes <= 0) return '0 B';
        const units = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(1024));
        const size = (bytes / Math.pow(1024, i)).toFixed(i > 0 ? 1 : 0);
        return `${size} ${units[i]}`;
    }

    getAttachmentIcon(contentType, fileExtension) {
        const ct = (contentType || '').toUpperCase();
        const ext = (fileExtension || '').toLowerCase();

        if (ct.includes('PDF') || ext === 'pdf') return CONTENT_TYPE_ICONS.PDF;
        if (ct.includes('IMAGE') || ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'svg'].includes(ext)) {
            return CONTENT_TYPE_ICONS.IMAGE;
        }
        if (ct.includes('WORD') || ['doc', 'docx'].includes(ext)) return CONTENT_TYPE_ICONS.WORD;
        if (ct.includes('EXCEL') || ['xls', 'xlsx'].includes(ext)) return CONTENT_TYPE_ICONS.EXCEL;
        if (ct.includes('POWERPOINT') || ['ppt', 'pptx'].includes(ext)) return CONTENT_TYPE_ICONS.POWER_POINT;
        if (ct.includes('CSV') || ext === 'csv') return CONTENT_TYPE_ICONS.CSV;
        if (ct.includes('XML') || ext === 'xml') return CONTENT_TYPE_ICONS.XML;
        if (ct.includes('HTML') || ext === 'html' || ext === 'htm') return CONTENT_TYPE_ICONS.HTML;
        if (ct.includes('ZIP') || ['zip', 'rar', '7z', 'tar', 'gz'].includes(ext)) return CONTENT_TYPE_ICONS.ZIP;
        if (ct.includes('TEXT') || ext === 'txt') return CONTENT_TYPE_ICONS.TEXT;

        return CONTENT_TYPE_ICONS.DEFAULT;
    }

    get hasAttachments() {
        return Array.isArray(this.attachments) && this.attachments.length > 0;
    }

    get subjectDisplay() {
        return this.emailMessageSubject || '(no subject)';
    }
}

