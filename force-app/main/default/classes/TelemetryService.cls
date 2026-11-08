/**
 * Platform Event subscriber logic. Runs as the Automated Process user, hence without sharing.
 * Design points: latest-reading-wins per shipment (out-of-order safe), exceptions keyed on the
 * event uuid (duplicate safe), retryable on row-lock contention, outbound business event on excursion.
 */
public without sharing class TelemetryService {
    private static final Set<String> CLOSED = new Set<String>{ 'Delivered', 'Cancelled' };
    private static final Integer MAX_RETRIES = 3;

    public static void process(List<Telemetry_Reading__e> events) {
        if (!FeatureToggle.isEnabled('Telemetry_Subscriber')) {
            return;
        }
        Map<String, Telemetry_Reading__e> latest = new Map<String, Telemetry_Reading__e>();
        for (Telemetry_Reading__e e : events) {
            if (String.isBlank(e.Shipment_External_Id__c) || e.Temperature_C__c == null || e.Reading_Time__c == null) {
                continue;
            }
            Telemetry_Reading__e current = latest.get(e.Shipment_External_Id__c);
            if (current == null || e.Reading_Time__c > current.Reading_Time__c) {
                latest.put(e.Shipment_External_Id__c, e);
            }
        }
        if (latest.isEmpty()) {
            return;
        }

        List<Shipment__c> updates = new List<Shipment__c>();
        List<Shipment_Exception__c> exceptions = new List<Shipment_Exception__c>();
        for (Shipment__c s : [
            SELECT Id, External_Id__c, Status__c, Min_Temp_C__c, Max_Temp_C__c, Temperature_Class__c, Last_Telemetry_At__c
            FROM Shipment__c
            WHERE External_Id__c IN :latest.keySet()
        ]) {
            Telemetry_Reading__e e = latest.get(s.External_Id__c);
            if (CLOSED.contains(s.Status__c) || (s.Last_Telemetry_At__c != null && e.Reading_Time__c <= s.Last_Telemetry_At__c)) {
                continue;
            }
            updates.add(new Shipment__c(Id = s.Id, Last_Temperature_C__c = e.Temperature_C__c, Last_Telemetry_At__c = e.Reading_Time__c));
            if (TemperaturePolicyService.isExcursion(s.Min_Temp_C__c, s.Max_Temp_C__c, e.Temperature_C__c)) {
                TemperaturePolicyService.Band band = TemperaturePolicyService.forClass(s.Temperature_Class__c);
                exceptions.add(
                    new Shipment_Exception__c(
                        Shipment__c = s.Id,
                        Exception_Type__c = 'Temperature Excursion',
                        Severity__c = TemperaturePolicyService.severityFor(s.Min_Temp_C__c, s.Max_Temp_C__c, e.Temperature_C__c, band?.criticalDelta),
                        Status__c = 'Open',
                        Detected_At__c = e.Reading_Time__c,
                        Recorded_Temperature_C__c = e.Temperature_C__c,
                        Details__c = String.format(Label.CTC_Msg_Temp_Excursion, new List<Object>{ e.Temperature_C__c, s.Min_Temp_C__c, s.Max_Temp_C__c }),
                        Source_Event_Id__c = e.Event_Uuid__c
                    )
                );
            }
        }

        Boolean lockContention = false;
        for (Database.SaveResult r : Database.update(updates, false)) {
            if (!r.isSuccess()) {
                lockContention = lockContention || r.getErrors()[0].getStatusCode() == StatusCode.UNABLE_TO_LOCK_ROW;
                CtcLog.error('TelemetryService', 'Shipment update failed: ' + r.getErrors()[0].getMessage());
            }
        }
        if (lockContention && EventBus.TriggerContext.currentContext().retries < MAX_RETRIES) {
            throw new EventBus.RetryableException('Row lock contention while applying telemetry; retrying.');
        }

        List<Exception_Raised__e> outbound = new List<Exception_Raised__e>();
        if (!exceptions.isEmpty()) {
            List<Database.UpsertResult> results = Database.upsert(exceptions, Shipment_Exception__c.Source_Event_Id__c, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess() && results[i].isCreated()) {
                    outbound.add(
                        new Exception_Raised__e(
                            Shipment_Id__c = exceptions[i].Shipment__c,
                            Exception_Type__c = exceptions[i].Exception_Type__c,
                            Severity__c = exceptions[i].Severity__c,
                            Correlation_Id__c = exceptions[i].Source_Event_Id__c
                        )
                    );
                } else if (!results[i].isSuccess()) {
                    CtcLog.error('TelemetryService', 'Exception upsert failed: ' + results[i].getErrors()[0].getMessage());
                }
            }
        }
        if (!outbound.isEmpty()) {
            EventBus.publish(outbound);
        }
    }
}
