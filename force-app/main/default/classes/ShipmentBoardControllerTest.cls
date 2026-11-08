@IsTest
private class ShipmentBoardControllerTest {
    @TestSetup
    static void setup() {
        Account a = CtcTestDataFactory.account();
        Carrier__c c = CtcTestDataFactory.carrier();
        List<Shipment__c> shipments = new List<Shipment__c>();
        for (Integer i = 0; i < 30; i++) {
            shipments.add(new Shipment__c(Account__c = a.Id, Carrier__c = c.Id, Status__c = 'In Transit', Temperature_Class__c = 'Ambient', External_Id__c = 'BRD-' + i));
        }
        insert shipments;
    }

    @IsTest
    static void keysetPagingWalksAllRows() {
        ShipmentBoardController.BoardPage p1 = ShipmentBoardController.getBoard('In Transit', null, 25, null);
        Assert.areEqual(25, p1.rows.size());
        Assert.isTrue(p1.hasMore);
        ShipmentBoardController.BoardPage p2 = ShipmentBoardController.getBoard('In Transit', null, 25, p1.lastId);
        Assert.areEqual(5, p2.rows.size());
        Assert.isFalse(p2.hasMore);
    }

    @IsTest
    static void searchAndKpis() {
        Assert.areEqual(30, ShipmentBoardController.getBoard('All', 'CTC Test', 100, null).rows.size());
        Assert.areEqual(0, ShipmentBoardController.getBoard('Delayed', null, 10, null).rows.size());
        Assert.areEqual(4, ShipmentBoardController.getKpis().size());
    }

    @IsTest
    static void syncRequiresCustomPermission() {
        User u = CtcTestDataFactory.userWithPermSets('noperm', new List<String>{ 'CTC_Analyst' });
        Id shipmentId = [SELECT Id FROM Shipment__c LIMIT 1].Id;
        Boolean denied = false;
        System.runAs(u) {
            try {
                ShipmentBoardController.syncCarrier(shipmentId);
            } catch (AuraHandledException e) {
                denied = true;
            }
        }
        Assert.isTrue(denied);
    }

    @IsTest
    static void analystSeesAllButCannotEdit() {
        User u = CtcTestDataFactory.userWithPermSets('analyst', new List<String>{ 'CTC_Analyst' });
        System.runAs(u) {
            Assert.areEqual(30, ShipmentBoardController.getBoard('All', null, 100, null).rows.size());
            Assert.isFalse(Schema.sObjectType.Shipment__c.isUpdateable());
        }
    }
}
