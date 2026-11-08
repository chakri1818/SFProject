@IsTest
private class CarrierSyncTest {
    private class Mock implements HttpCalloutMock {
        private Integer code;
        Mock(Integer code) {
            this.code = code;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setBody('{"status":"In Transit","estimatedArrival":"2030-01-01T10:00:00.000Z"}');
            return res;
        }
    }

    @IsTest
    static void queueableUpdatesEta() {
        Account a = CtcTestDataFactory.account();
        Shipment__c s = CtcTestDataFactory.shipment(a.Id, null, 'EXT-C1', 'Ambient');
        Test.setMock(HttpCalloutMock.class, new Mock(200));
        Test.startTest();
        System.enqueueJob(new CarrierSyncQueueable(new List<Id>{ s.Id }, 0));
        Test.stopTest();
        Assert.isNotNull([SELECT Revised_ETA__c FROM Shipment__c WHERE Id = :s.Id].Revised_ETA__c);
    }

    @IsTest
    static void clientRaisesOnHttpError() {
        Test.setMock(HttpCalloutMock.class, new Mock(503));
        try {
            CarrierStatusClient.fetch('X');
            Assert.fail('expected exception');
        } catch (CarrierStatusClient.CarrierException e) {
            Assert.isTrue(e.getMessage().contains('503'));
        }
    }

    @IsTest
    static void circuitBreakerSkipsCallout() {
        insert new Integration_Settings__c(SetupOwnerId = UserInfo.getOrganizationId(), Circuit_Open__c = true);
        try {
            CarrierStatusClient.fetch('X');
            Assert.fail('expected exception');
        } catch (CarrierStatusClient.CarrierException e) {
            Assert.isTrue(e.getMessage().contains('circuit'));
        }
    }

    @IsTest
    static void launcherHandlesEmptyAndSchedules() {
        Assert.isNull(CarrierSyncLauncher.launch(new Set<Id>()));
        Test.startTest();
        String jobId = System.schedule('ctc-test-sync', '0 0 3 * * ?', new CarrierSyncLauncher());
        Test.stopTest();
        Assert.isNotNull(jobId);
    }
}
