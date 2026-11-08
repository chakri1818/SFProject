/**
 * Handler for ShipmentTrigger. Bulk-safe, change-detecting and idempotent:
 *  - before: default the temperature band from policy when the class changes
 *  - after update: raise Delay exceptions when the revised ETA moves; the exception is
 *    upserted on a deterministic Source_Event_Id__c so re-processing never duplicates it
 */
public with sharing class ShipmentTriggerHandler {
    @TestVisible
    private static final Decimal DELAY_THRESHOLD_HOURS = 2;
    private static final Set<String> CLOSED = new Set<String>{ 'Delivered', 'Cancelled' };

    public static void beforeInsert(List<Shipment__c> news) {
        applyTemperatureDefaults(news, null);
    }

    public static void beforeUpdate(List<Shipment__c> news, Map<Id, Shipment__c> oldMap) {
        applyTemperatureDefaults(news, oldMap);
    }

    public static void afterUpdate(List<Shipment__c> news, Map<Id, Shipment__c> oldMap) {
        raiseDelayExceptions(news, oldMap);
    }

    private static void applyTemperatureDefaults(List<Shipment__c> news, Map<Id, Shipment__c> oldMap) {
        for (Shipment__c s : news) {
            Boolean classChanged = oldMap == null || s.Temperature_Class__c != oldMap.get(s.Id).Temperature_Class__c;
            Boolean missingBand = s.Min_Temp_C__c == null && s.Max_Temp_C__c == null;
            if (!classChanged && !missingBand) {
                continue;
            }
            TemperaturePolicyService.Band band = TemperaturePolicyService.forClass(s.Temperature_Class__c);
            if (band != null && (missingBand || classChanged)) {
                // Explicit values supplied on insert win over the policy default.
                if (oldMap != null || missingBand) {
                    s.Min_Temp_C__c = band.minC;
                    s.Max_Temp_C__c = band.maxC;
                }
            }
        }
    }

    private static void raiseDelayExceptions(List<Shipment__c> news, Map<Id, Shipment__c> oldMap) {
        if (!FeatureToggle.isEnabled('Delay_Exception_Creation')) {
            return;
        }
        List<Shipment_Exception__c> exceptions = new List<Shipment_Exception__c>();
        for (Shipment__c s : news) {
            Shipment__c prior = oldMap.get(s.Id);
            if (s.Revised_ETA__c == null || s.Planned_Arrival__c == null || s.Revised_ETA__c == prior.Revised_ETA__c || CLOSED.contains(s.Status__c)) {
                continue;
            }
            Decimal hours = (s.Revised_ETA__c.getTime() - s.Planned_Arrival__c.getTime()) / 3600000.0;
            if (hours < DELAY_THRESHOLD_HOURS) {
                continue;
            }
            exceptions.add(
                new Shipment_Exception__c(
                    Shipment__c = s.Id,
                    Exception_Type__c = 'Delay',
                    Severity__c = hours >= 48 ? 'Critical' : (hours >= 12 ? 'High' : 'Medium'),
                    Status__c = 'Open',
                    Detected_At__c = System.now(),
                    Details__c = String.format(Label.CTC_Msg_Delay_Exception, new List<Object>{ hours.setScale(1) }),
                    Source_Event_Id__c = 'DELAY-' + s.Id + '-' + s.Revised_ETA__c.getTime()
                )
            );
        }
        if (exceptions.isEmpty()) {
            return;
        }
        List<Database.UpsertResult> results = Database.upsert(exceptions, Shipment_Exception__c.Source_Event_Id__c, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                CtcLog.error('ShipmentTriggerHandler', 'Delay exception upsert failed: ' + results[i].getErrors()[0].getMessage());
            }
        }
    }
}
