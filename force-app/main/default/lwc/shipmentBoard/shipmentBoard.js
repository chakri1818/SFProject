import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getBoard from '@salesforce/apex/ShipmentBoardController.getBoard';
import syncCarrier from '@salesforce/apex/ShipmentBoardController.syncCarrier';

const PAGE_SIZE = 25;
const STATUS_OPTIONS = ['All', 'Planned', 'Booked', 'In Transit', 'At Customs', 'Delayed', 'Delivered', 'Exception'].map((v) => ({ label: v, value: v }));

const COLUMNS = [
    { label: 'Shipment', fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'name' }, target: '_self' } },
    { label: 'Customer', fieldName: 'accountName' },
    { label: 'Carrier', fieldName: 'carrierName' },
    { label: 'Status', fieldName: 'status' },
    { label: 'Priority', fieldName: 'priority' },
    { label: 'Temp (C)', fieldName: 'lastTemperature', type: 'number', cellAttributes: { class: { fieldName: 'tempClass' } } },
    { label: 'Revised ETA', fieldName: 'revisedEta', type: 'date', typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
    { label: 'Delay (h)', fieldName: 'delayHours', type: 'number', typeAttributes: { maximumFractionDigits: 1 } },
    { label: 'Open Exc.', fieldName: 'openExceptions', type: 'number' },
    { type: 'action', typeAttributes: { rowActions: [{ label: 'Sync carrier', name: 'sync' }] } }
];

export default class ShipmentBoard extends NavigationMixin(LightningElement) {
    columns = COLUMNS;
    statusOptions = STATUS_OPTIONS;
    status = 'All';
    searchTerm = '';
    rows = [];
    cursorStack = [];
    afterId;
    hasMore = false;
    lastId;
    error;
    wiredResult;
    isLoading = true;
    searchTimer;

    @wire(getBoard, { status: '$status', searchTerm: '$searchTerm', pageSize: PAGE_SIZE, afterId: '$afterId' })
    wiredBoard(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.rows = data.rows.map((r) => ({
                ...r,
                recordUrl: `/lightning/r/Shipment__c/${r.id}/view`,
                tempClass: r.outOfRange ? 'slds-text-color_error slds-text-title_bold' : ''
            }));
            this.hasMore = data.hasMore;
            this.lastId = data.lastId;
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.error = error?.body?.message || 'Unable to load shipments.';
            this.rows = [];
            this.isLoading = false;
        }
    }

    get hasError() {
        return !!this.error;
    }

    get isEmpty() {
        return !this.isLoading && !this.error && this.rows.length === 0;
    }

    get disablePrev() {
        return this.cursorStack.length === 0;
    }

    get disableNext() {
        return !this.hasMore;
    }

    resetPaging() {
        this.cursorStack = [];
        this.afterId = undefined;
        this.isLoading = true;
    }

    handleStatusChange(event) {
        this.status = event.detail.value;
        this.resetPaging();
    }

    handleSearch(event) {
        const value = event.target.value;
        window.clearTimeout(this.searchTimer);
        // Debounce so typing does not fire a server call per keystroke.
        this.searchTimer = window.setTimeout(() => {
            this.searchTerm = value;
            this.resetPaging();
        }, 350);
    }

    handleNext() {
        this.cursorStack = [...this.cursorStack, this.afterId];
        this.afterId = this.lastId;
        this.isLoading = true;
    }

    handlePrev() {
        const stack = [...this.cursorStack];
        this.afterId = stack.pop();
        this.cursorStack = stack;
        this.isLoading = true;
    }

    async handleRowAction(event) {
        if (event.detail.action.name !== 'sync') {
            return;
        }
        try {
            await syncCarrier({ shipmentId: event.detail.row.id });
            this.dispatchEvent(new ShowToastEvent({ title: 'Carrier sync queued', message: 'ETAs will refresh shortly.', variant: 'success' }));
            this.dispatchEvent(new CustomEvent('syncqueued', { detail: { shipmentId: event.detail.row.id } }));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Carrier sync failed', message: e?.body?.message || 'Unexpected error.', variant: 'error' }));
        }
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredResult).finally(() => {
            this.isLoading = false;
        });
    }

    disconnectedCallback() {
        window.clearTimeout(this.searchTimer);
    }
}
