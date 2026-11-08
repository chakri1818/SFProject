/**
 * Pulls revised ETAs from the carrier API. Callouts are made before any DML, work is chunked to stay
 * under callout limits, and remaining ids are chained (Developer Edition caps chain depth at 5).
 * A Transaction Finalizer records an unhandled failure.
 */
public with sharing class CarrierSyncQueueable implements Queueable, Database.AllowsCallouts {
    @TestVisible
    private static final Integer CHUNK_SIZE = 20;
    private static final Integer MAX_DEPTH = 4;

    private final List<Id> shipmentIds;
    private final Integer depth;

    public CarrierSyncQueueable(List<Id> shipmentIds, Integer depth) {
        this.shipmentIds = shipmentIds;
        this.depth = depth;
    }

    public void execute(QueueableContext ctx) {
        System.attachFinalizer(new SyncFinalizer(shipmentIds.size(), depth));

        List<Id> chunk = new List<Id>();
        List<Id> remaining = new List<Id>();
        for (Integer i = 0; i < shipmentIds.size(); i++) {
            (i < CHUNK_SIZE ? chunk : remaining).add(shipmentIds[i]);
        }

        List<Shipment__c> updates = new List<Shipment__c>();
        Integer failed = 0;
        for (Shipment__c s : [SELECT Id, External_Id__c, Revised_ETA__c FROM Shipment__c WHERE Id IN :chunk AND External_Id__c != NULL WITH USER_MODE]) {
            try {
                CarrierStatusClient.Status st = CarrierStatusClient.fetch(s.External_Id__c);
                if (st.estimatedArrival != null && st.estimatedArrival != s.Revised_ETA__c) {
                    updates.add(new Shipment__c(Id = s.Id, Revised_ETA__c = st.estimatedArrival));
                }
            } catch (Exception e) {
                failed++;
                CtcLog.error('CarrierSyncQueueable', e.getMessage());
            }
        }
        if (!updates.isEmpty()) {
            for (Database.SaveResult r : Database.update(updates, false, AccessLevel.USER_MODE)) {
                if (!r.isSuccess()) {
                    failed++;
                    CtcLog.error('CarrierSyncQueueable', 'Update failed: ' + r.getErrors()[0].getMessage());
                }
            }
        }
        CtcLog.info('CarrierSyncQueueable', 'chunk=' + chunk.size() + ' updated=' + updates.size() + ' failed=' + failed + ' remaining=' + remaining.size());

        if (!remaining.isEmpty() && depth < MAX_DEPTH && !Test.isRunningTest()) {
            System.enqueueJob(new CarrierSyncQueueable(remaining, depth + 1));
        }
    }

    public class SyncFinalizer implements Finalizer {
        private final Integer requested;
        private final Integer depth;

        public SyncFinalizer(Integer requested, Integer depth) {
            this.requested = requested;
            this.depth = depth;
        }

        public void execute(FinalizerContext fc) {
            if (fc.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
                CtcLog.error('CarrierSyncFinalizer', 'Job ' + fc.getAsyncApexJobId() + ' failed at depth ' + depth + ' for ' + requested + ' shipments: ' + fc.getException().getMessage());
            }
        }
    }
}
