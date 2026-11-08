/**
 * Read model for the Control Tower LWCs. All queries run in user mode (FLS + sharing),
 * dynamic SOQL uses bind variables only, and paging is keyset on Id.
 */
public with sharing class ShipmentBoardController {
    public class ShipmentRow {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String accountName;
        @AuraEnabled
        public String carrierName;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String priority;
        @AuraEnabled
        public String temperatureClass;
        @AuraEnabled
        public Decimal lastTemperature;
        @AuraEnabled
        public Datetime revisedEta;
        @AuraEnabled
        public Decimal delayHours;
        @AuraEnabled
        public Decimal openExceptions;
        @AuraEnabled
        public Boolean isDelayed;
        @AuraEnabled
        public Boolean outOfRange;
    }

    public class BoardPage {
        @AuraEnabled
        public List<ShipmentRow> rows = new List<ShipmentRow>();
        @AuraEnabled
        public Boolean hasMore = false;
        @AuraEnabled
        public Id lastId;
    }

    public class Kpi {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public Integer count;
        public Kpi(String label, Integer count) {
            this.label = label;
            this.count = count;
        }
    }

    @AuraEnabled(cacheable=true)
    public static BoardPage getBoard(String status, String searchTerm, Integer pageSize, Id afterId) {
        Integer size = (pageSize == null || pageSize < 1) ? 25 : Math.min(pageSize, 100);
        List<String> clauses = new List<String>();
        Map<String, Object> binds = new Map<String, Object>{ 'lim' => size + 1 };
        if (status == 'Delayed') {
            clauses.add('Is_Delayed__c = true');
        } else if (String.isNotBlank(status) && status != 'All') {
            clauses.add('Status__c = :status');
            binds.put('status', status);
        }
        if (String.isNotBlank(searchTerm)) {
            clauses.add('(Name LIKE :term OR Account__r.Name LIKE :term)');
            binds.put('term', '%' + searchTerm.trim() + '%');
        }
        if (afterId != null) {
            clauses.add('Id > :afterId');
            binds.put('afterId', afterId);
        }
        String soql =
            'SELECT Id, Name, Account__r.Name, Carrier__r.Name, Status__c, Priority__c, Temperature_Class__c, Last_Temperature_C__c, ' +
            'Min_Temp_C__c, Max_Temp_C__c, Revised_ETA__c, Delay_Hours__c, Open_Exception_Count__c, Is_Delayed__c FROM Shipment__c' +
            (clauses.isEmpty() ? '' : ' WHERE ' + String.join(clauses, ' AND ')) +
            ' ORDER BY Id LIMIT :lim';
        List<Shipment__c> found = Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);

        BoardPage page = new BoardPage();
        page.hasMore = found.size() > size;
        for (Integer i = 0; i < Math.min(found.size(), size); i++) {
            Shipment__c s = found[i];
            ShipmentRow row = new ShipmentRow();
            row.id = s.Id;
            row.name = s.Name;
            row.accountName = s.Account__r?.Name;
            row.carrierName = s.Carrier__r?.Name;
            row.status = s.Status__c;
            row.priority = s.Priority__c;
            row.temperatureClass = s.Temperature_Class__c;
            row.lastTemperature = s.Last_Temperature_C__c;
            row.revisedEta = s.Revised_ETA__c;
            row.delayHours = s.Delay_Hours__c;
            row.openExceptions = s.Open_Exception_Count__c;
            row.isDelayed = s.Is_Delayed__c;
            row.outOfRange = TemperaturePolicyService.isExcursion(s.Min_Temp_C__c, s.Max_Temp_C__c, s.Last_Temperature_C__c);
            page.rows.add(row);
            page.lastId = s.Id;
        }
        return page;
    }

    @AuraEnabled(cacheable=true)
    public static List<Kpi> getKpis() {
        Map<String, Integer> byStatus = new Map<String, Integer>();
        for (AggregateResult ar : [SELECT Status__c s, COUNT(Id) c FROM Shipment__c WITH USER_MODE GROUP BY Status__c]) {
            byStatus.put((String) ar.get('s'), (Integer) ar.get('c'));
        }
        Integer delayed = [SELECT COUNT() FROM Shipment__c WHERE Is_Delayed__c = TRUE WITH USER_MODE];
        Integer openExceptions = [SELECT COUNT() FROM Shipment_Exception__c WHERE Status__c != 'Resolved' WITH USER_MODE];
        return new List<Kpi>{
            new Kpi('In Transit', byStatus.get('In Transit') == null ? 0 : byStatus.get('In Transit')),
            new Kpi('At Customs', byStatus.get('At Customs') == null ? 0 : byStatus.get('At Customs')),
            new Kpi('Delayed', delayed),
            new Kpi('Open Exceptions', openExceptions)
        };
    }

    @AuraEnabled
    public static void syncCarrier(Id shipmentId) {
        if (!FeatureManagement.checkPermission('Manage_Carrier_Integration')) {
            throw new AuraHandledException('You do not have permission to run carrier sync.');
        }
        try {
            CarrierSyncLauncher.launch(new Set<Id>{ shipmentId });
        } catch (CarrierSyncLauncher.LauncherException e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
