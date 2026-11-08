/**
 * Entry point for starting carrier syncs. Prevents duplicate concurrent jobs and doubles as
 * a Schedulable that syncs every in-transit shipment.
 */
public with sharing class CarrierSyncLauncher implements Schedulable {
    public class LauncherException extends Exception {
    }

    public static Id launch(Set<Id> shipmentIds) {
        if (shipmentIds == null || shipmentIds.isEmpty()) {
            return null;
        }
        Integer active = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'CarrierSyncQueueable' AND Status IN ('Queued', 'Preparing', 'Processing')
        ];
        if (active > 0) {
            throw new LauncherException('A carrier sync is already running. Try again when it completes.');
        }
        return System.enqueueJob(new CarrierSyncQueueable(new List<Id>(shipmentIds), 0));
    }

    public void execute(SchedulableContext sc) {
        Map<Id, Shipment__c> inTransit = new Map<Id, Shipment__c>([SELECT Id FROM Shipment__c WHERE Status__c = 'In Transit' LIMIT 500]);
        try {
            launch(inTransit.keySet());
        } catch (LauncherException e) {
            CtcLog.info('CarrierSyncLauncher', e.getMessage());
        }
    }
}
