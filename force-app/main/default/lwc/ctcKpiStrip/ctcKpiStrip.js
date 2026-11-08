import { LightningElement, wire } from 'lwc';
import getKpis from '@salesforce/apex/ShipmentBoardController.getKpis';

export default class CtcKpiStrip extends LightningElement {
    kpis = [];
    error;

    @wire(getKpis)
    wiredKpis({ data, error }) {
        if (data) {
            this.kpis = data.map((k) => ({ ...k, key: k.label, valueClass: k.label === 'Delayed' || k.label === 'Open Exceptions' ? 'slds-text-heading_large slds-text-color_error' : 'slds-text-heading_large' }));
            this.error = undefined;
        } else if (error) {
            this.error = error?.body?.message || 'Unable to load KPIs.';
        }
    }
}
