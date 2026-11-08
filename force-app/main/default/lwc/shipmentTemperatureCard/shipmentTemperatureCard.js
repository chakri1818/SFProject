import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import LAST_TEMP from '@salesforce/schema/Shipment__c.Last_Temperature_C__c';
import MIN_TEMP from '@salesforce/schema/Shipment__c.Min_Temp_C__c';
import MAX_TEMP from '@salesforce/schema/Shipment__c.Max_Temp_C__c';
import LAST_AT from '@salesforce/schema/Shipment__c.Last_Telemetry_At__c';

const FIELDS = [LAST_TEMP, MIN_TEMP, MAX_TEMP, LAST_AT];

export default class ShipmentTemperatureCard extends LightningElement {
    @api recordId;
    record;
    error;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ data, error }) {
        if (data) {
            this.record = data;
            this.error = undefined;
        } else if (error) {
            this.error = error?.body?.message || 'Unable to load temperature data.';
            this.record = undefined;
        }
    }

    get reading() {
        return getFieldValue(this.record, LAST_TEMP);
    }

    get hasReading() {
        return this.reading !== null && this.reading !== undefined;
    }

    get band() {
        const min = getFieldValue(this.record, MIN_TEMP);
        const max = getFieldValue(this.record, MAX_TEMP);
        return min === null || max === null ? 'No band configured' : `${min} to ${max} C`;
    }

    get lastAt() {
        return getFieldValue(this.record, LAST_AT);
    }

    get outOfRange() {
        const min = getFieldValue(this.record, MIN_TEMP);
        const max = getFieldValue(this.record, MAX_TEMP);
        return this.hasReading && ((max !== null && this.reading > max) || (min !== null && this.reading < min));
    }

    get valueClass() {
        return this.outOfRange ? 'slds-text-heading_large slds-text-color_error' : 'slds-text-heading_large';
    }

    get statusText() {
        return this.outOfRange ? 'Outside allowed band' : 'Within allowed band';
    }
}
