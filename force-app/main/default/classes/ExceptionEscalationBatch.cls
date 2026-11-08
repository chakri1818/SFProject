/**
 * Escalates exceptions that stay Open / Pending Approval beyond the SLA window.
 * Stateful counters feed the finish() reconciliation line; records locked by an approval
 * are skipped (partial success) and picked up on the next run.
 */
public with sharing class ExceptionEscalationBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
    public static final Integer MAX_LEVEL = 3;
    public static final Integer SLA_HOURS = 4;

    private Integer escalated = 0;
    private Integer failed = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime cutoff = System.now().addHours(-SLA_HOURS);
        Integer maxLevel = MAX_LEVEL;
        return Database.getQueryLocator(
            [
                SELECT Id, Escalation_Level__c
                FROM Shipment_Exception__c
                WHERE Status__c IN ('Open', 'Pending Approval') AND Detected_At__c < :cutoff AND (Escalated_At__c = NULL OR Escalated_At__c < :cutoff) AND (Escalation_Level__c = NULL OR Escalation_Level__c < :maxLevel)
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<Shipment_Exception__c> scope) {
        for (Shipment_Exception__c ex : scope) {
            ex.Escalation_Level__c = (ex.Escalation_Level__c == null ? 0 : ex.Escalation_Level__c) + 1;
            ex.Escalated_At__c = System.now();
        }
        for (Database.SaveResult r : Database.update(scope, false)) {
            if (r.isSuccess()) {
                escalated++;
            } else {
                failed++;
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        CtcLog.info('ExceptionEscalationBatch', 'job=' + bc.getJobId() + ' escalated=' + escalated + ' failed=' + failed);
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new ExceptionEscalationBatch(), 100);
    }
}
