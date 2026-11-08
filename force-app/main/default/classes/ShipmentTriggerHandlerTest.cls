@IsTest
private class ShipmentTriggerHandlerTest {
    @IsTest
    static void defaultsTemperatureBandFromPolicy() {
        Account a = CtcTestDataFactory.account();
        Carrier__c c = CtcTestDataFactory.carrier();
        Shipment__c s = CtcTestDataFactory.shipment(a.Id, c.Id, 'EXT-1', 'Chilled');
        s = [SELECT Min_Temp_C__c, Max_Temp_C__c FROM Shipment__c WHERE Id = :s.Id];
        Assert.areEqual(2, s.Min_Temp_C__c, 'Chilled min should come from policy');
        Assert.areEqual(8, s.Max_Temp_C__c, 'Chilled max should come from policy');
    }

    @IsTest
    static void delayRaisesSingleExceptionAndIsIdempotent() {
        Account a = CtcTestDataFactory.account();
        Carrier__c c = CtcTestDataFactory.carrier();
        List<Shipment__c> shipments = new List<Shipment__c>();
        for (Integer i = 0; i < 20; i++) {
            shipments.add(CtcTestDataFactory.shipment(a.Id, c.Id, 'EXT-D' + i, 'Ambient'));
        }
        for (Shipment__c s : shipments) {
            s.Revised_ETA__c = s.Planned_Arrival__c.addHours(30);
        }
        Test.startTest();
        update shipments;
        update shipments; // unchanged ETA -> no second pass
        Test.stopTest();
        Assert.areEqual(20, [SELECT COUNT() FROM Shipment_Exception__c WHERE Exception_Type__c = 'Delay']);
        Assert.areEqual('High', [SELECT Severity__c FROM Shipment_Exception__c LIMIT 1].Severity__c);
    }

    @IsTest
    static void smallDelayAndKillSwitchRaiseNothing() {
        Account a = CtcTestDataFactory.account();
        Shipment__c s = CtcTestDataFactory.shipment(a.Id, null, 'EXT-S', 'Ambient');
        s.Revised_ETA__c = s.Planned_Arrival__c.addMinutes(30);
        update s;
        Assert.areEqual(0, [SELECT COUNT() FROM Shipment_Exception__c]);
        FeatureToggle.overrides.put('Delay_Exception_Creation', false);
        s.Revised_ETA__c = s.Planned_Arrival__c.addHours(40);
        update s;
        Assert.areEqual(0, [SELECT COUNT() FROM Shipment_Exception__c], 'Toggle off must suppress exceptions');
    }

    @IsTest
    static void validationBlocksReopeningDelivered() {
        Account a = CtcTestDataFactory.account();
        Carrier__c c = CtcTestDataFactory.carrier();
        Shipment__c s = CtcTestDataFactory.shipment(a.Id, c.Id, 'EXT-V', 'Ambient');
        s.Status__c = 'Delivered';
        s.Actual_Arrival__c = System.now();
        update s;
        s.Status__c = 'In Transit';
        Database.SaveResult r = Database.update(s, false);
        Assert.isFalse(r.isSuccess());
        Assert.isTrue(r.getErrors()[0].getMessage().contains('cannot be reopened'));
    }
}
