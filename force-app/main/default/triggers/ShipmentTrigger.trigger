trigger ShipmentTrigger on Shipment__c(before insert, before update, after update) {
    if (!FeatureToggle.isEnabled('Shipment_Trigger')) {
        return;
    }
    if (Trigger.isBefore && Trigger.isInsert) {
        ShipmentTriggerHandler.beforeInsert(Trigger.new);
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        ShipmentTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        ShipmentTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}
