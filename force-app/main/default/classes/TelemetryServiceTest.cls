@IsTest
private class TelemetryServiceTest {
    private static Telemetry_Reading__e reading(String ext, Decimal temp, Datetime at, String uuid) {
        return new Telemetry_Reading__e(Shipment_External_Id__c = ext, Temperature_C__c = temp, Reading_Time__c = at, Event_Uuid__c = uuid, Device_Id__c = 'DEV1');
    }

    @IsTest
    static void excursionCreatesExceptionOnce() {
        Account a = CtcTestDataFactory.account();
        Shipment__c s = CtcTestDataFactory.shipment(a.Id, null, 'EXT-T1', 'Chilled');
        Datetime now = System.now();
        Test.startTest();
        EventBus.publish(new List<Telemetry_Reading__e>{ reading('EXT-T1', 14, now, 'uuid-1') });
        Test.getEventBus().deliver();
        EventBus.publish(new List<Telemetry_Reading__e>{ reading('EXT-T1', 14, now, 'uuid-1') }); // duplicate delivery
        Test.getEventBus().deliver();
        Test.stopTest();
        Assert.areEqual(1, [SELECT COUNT() FROM Shipment_Exception__c WHERE Exception_Type__c = 'Temperature Excursion']);
        Assert.areEqual('Critical', [SELECT Severity__c FROM Shipment_Exception__c LIMIT 1].Severity__c);
        Assert.areEqual(14, [SELECT Last_Temperature_C__c FROM Shipment__c WHERE Id = :s.Id].Last_Temperature_C__c);
    }

    @IsTest
    static void staleReadingDoesNotOverwriteAndInRangeRaisesNothing() {
        Account a = CtcTestDataFactory.account();
        Shipment__c s = CtcTestDataFactory.shipment(a.Id, null, 'EXT-T2', 'Chilled');
        Datetime now = System.now();
        Test.startTest();
        EventBus.publish(new List<Telemetry_Reading__e>{ reading('EXT-T2', 5, now, 'u-a') });
        Test.getEventBus().deliver();
        EventBus.publish(new List<Telemetry_Reading__e>{ reading('EXT-T2', 30, now.addMinutes(-10), 'u-b') });
        Test.getEventBus().deliver();
        Test.stopTest();
        Assert.areEqual(5, [SELECT Last_Temperature_C__c FROM Shipment__c WHERE Id = :s.Id].Last_Temperature_C__c, 'Stale reading must not overwrite');
        Assert.areEqual(0, [SELECT COUNT() FROM Shipment_Exception__c]);
    }

    @IsTest
    static void invalidAndDisabledEventsAreIgnored() {
        TelemetryService.process(new List<Telemetry_Reading__e>{ new Telemetry_Reading__e(Temperature_C__c = 3) });
        FeatureToggle.overrides.put('Telemetry_Subscriber', false);
        TelemetryService.process(new List<Telemetry_Reading__e>{ reading('X', 1, System.now(), 'u') });
        Assert.areEqual(0, [SELECT COUNT() FROM Shipment_Exception__c]);
    }
}
