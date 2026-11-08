@IsTest
public class CtcTestDataFactory {
    public static Account account() {
        Account a = new Account(Name = 'CTC Test Customer');
        insert a;
        return a;
    }

    public static Carrier__c carrier() {
        Carrier__c c = new Carrier__c(Name = 'Test Carrier', SCAC_Code__c = 'TSTC', Is_Active__c = true);
        insert c;
        return c;
    }

    private static Id cachedCarrierId;

    private static Id defaultCarrierId() {
        if (cachedCarrierId == null) {
            cachedCarrierId = carrier().Id;
        }
        return cachedCarrierId;
    }

    public static Shipment__c shipment(Id accountId, Id carrierId, String externalId, String tempClass) {
        Id resolvedCarrier = carrierId != null ? carrierId : defaultCarrierId();
        Shipment__c s = new Shipment__c(
            Account__c = accountId,
            Carrier__c = resolvedCarrier,
            External_Id__c = externalId,
            Status__c = 'In Transit',
            Temperature_Class__c = tempClass,
            Planned_Departure__c = System.now().addDays(-1),
            Planned_Arrival__c = System.now().addDays(1)
        );
        insert s;
        return s;
    }

    public static User userWithPermSets(String alias, List<String> permSetNames) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = alias,
            Email = alias + '@ctc.example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = alias,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = alias + System.currentTimeMillis() + '@ctc.example.com'
        );
        insert u;
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (PermissionSet ps : [SELECT Id FROM PermissionSet WHERE Name IN :permSetNames]) {
            assignments.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id));
        }
        insert assignments;
        return u;
    }
}
