@IsTest
private class ExceptionEscalationBatchTest {
    @IsTest
    static void escalatesStaleOpenExceptionsOnly() {
        Account a = CtcTestDataFactory.account();
        Shipment__c s = CtcTestDataFactory.shipment(a.Id, null, 'EXT-B1', 'Ambient');
        List<Shipment_Exception__c> exs = new List<Shipment_Exception__c>();
        for (Integer i = 0; i < 5; i++) {
            exs.add(new Shipment_Exception__c(Shipment__c = s.Id, Exception_Type__c = 'Damage', Severity__c = 'Low', Status__c = 'Open', Detected_At__c = System.now().addHours(-10), Source_Event_Id__c = 'B' + i));
        }
        exs.add(new Shipment_Exception__c(Shipment__c = s.Id, Exception_Type__c = 'Damage', Severity__c = 'Low', Status__c = 'Open', Detected_At__c = System.now(), Source_Event_Id__c = 'FRESH'));
        insert exs;
        Test.startTest();
        Database.executeBatch(new ExceptionEscalationBatch(), 200);
        Test.stopTest();
        Assert.areEqual(5, [SELECT COUNT() FROM Shipment_Exception__c WHERE Escalation_Level__c = 1]);
        Assert.areEqual(0, [SELECT Escalation_Level__c FROM Shipment_Exception__c WHERE Source_Event_Id__c = 'FRESH'].Escalation_Level__c);
    }

    @IsTest
    static void schedulableIsRegistered() {
        Test.startTest();
        System.schedule('ctc-esc-test', '0 0 4 * * ?', new ExceptionEscalationBatch());
        Test.stopTest();
        Assert.areEqual(1, [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name = 'ctc-esc-test']);
    }
}
