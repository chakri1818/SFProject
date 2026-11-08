// Cold-Chain Control Tower seed data. Idempotent: upserts on external ids, skips lines for shipments that already have them.
// Footprint is deliberately small (~150 records) because the Developer Edition org has ~5 MB of data storage.

// ---------- Carriers ----------
List<Carrier__c> carriers = new List<Carrier__c>{
    new Carrier__c(Name = 'Maersk Reefer Lines', SCAC_Code__c = 'MAEU', Service_Level__c = 'Cold Chain', Supports_Cold_Chain__c = true, On_Time_Rate__c = 92.5, Is_Active__c = true, Contact_Email__c = 'ops@maersk.example.com'),
    new Carrier__c(Name = 'FedEx Express Freight', SCAC_Code__c = 'FDXE', Service_Level__c = 'Express', Supports_Cold_Chain__c = true, On_Time_Rate__c = 96.1, Is_Active__c = true, Contact_Email__c = 'ops@fedex.example.com'),
    new Carrier__c(Name = 'DHL Global Forwarding', SCAC_Code__c = 'DHLG', Service_Level__c = 'Express', Supports_Cold_Chain__c = true, On_Time_Rate__c = 94.3, Is_Active__c = true, Contact_Email__c = 'ops@dhl.example.com'),
    new Carrier__c(Name = 'Knight Transport', SCAC_Code__c = 'KNIT', Service_Level__c = 'Freight', Supports_Cold_Chain__c = false, On_Time_Rate__c = 88.0, Is_Active__c = true, Contact_Email__c = 'ops@knight.example.com'),
    new Carrier__c(Name = 'Legacy Haulage (retired)', SCAC_Code__c = 'LGCY', Service_Level__c = 'Standard', Supports_Cold_Chain__c = false, On_Time_Rate__c = 71.2, Is_Active__c = false)
};
upsert carriers Carrier__c.SCAC_Code__c;
Map<String, Carrier__c> carrierByScac = new Map<String, Carrier__c>();
for (Carrier__c c : carriers) {
    carrierByScac.put(c.SCAC_Code__c, c);
}

// ---------- Facilities (hub -> spoke hierarchy) ----------
List<Facility__c> hubs = new List<Facility__c>{
    new Facility__c(Name = 'Rotterdam Hub', Facility_Code__c = 'NLRTM', Facility_Type__c = 'Port', City__c = 'Rotterdam', Country__c = 'Netherlands', Location__Latitude__s = 51.9244, Location__Longitude__s = 4.4777, Is_Temperature_Controlled__c = true, Capacity_Pallets__c = 12000),
    new Facility__c(Name = 'Chicago Hub', Facility_Code__c = 'USORD', Facility_Type__c = 'Airport', City__c = 'Chicago', Country__c = 'USA', Location__Latitude__s = 41.9742, Location__Longitude__s = -87.9073, Is_Temperature_Controlled__c = true, Capacity_Pallets__c = 8000),
    new Facility__c(Name = 'Singapore Hub', Facility_Code__c = 'SGSIN', Facility_Type__c = 'Port', City__c = 'Singapore', Country__c = 'Singapore', Location__Latitude__s = 1.2644, Location__Longitude__s = 103.8223, Is_Temperature_Controlled__c = true, Capacity_Pallets__c = 15000)
};
upsert hubs Facility__c.Facility_Code__c;
Map<String, Facility__c> facByCode = new Map<String, Facility__c>();
for (Facility__c f : hubs) {
    facByCode.put(f.Facility_Code__c, f);
}
List<Facility__c> spokes = new List<Facility__c>{
    new Facility__c(Name = 'Antwerp Cold Store', Facility_Code__c = 'BEANR', Facility_Type__c = 'Cold Storage', City__c = 'Antwerp', Country__c = 'Belgium', Location__Latitude__s = 51.2194, Location__Longitude__s = 4.4025, Is_Temperature_Controlled__c = true, Capacity_Pallets__c = 3000, Parent_Facility__c = facByCode.get('NLRTM').Id),
    new Facility__c(Name = 'Frankfurt Cross-Dock', Facility_Code__c = 'DEFRA', Facility_Type__c = 'Cross-Dock', City__c = 'Frankfurt', Country__c = 'Germany', Location__Latitude__s = 50.1109, Location__Longitude__s = 8.6821, Is_Temperature_Controlled__c = false, Capacity_Pallets__c = 2500, Parent_Facility__c = facByCode.get('NLRTM').Id),
    new Facility__c(Name = 'Indianapolis Warehouse', Facility_Code__c = 'USIND', Facility_Type__c = 'Warehouse', City__c = 'Indianapolis', Country__c = 'USA', Location__Latitude__s = 39.7684, Location__Longitude__s = -86.1581, Is_Temperature_Controlled__c = true, Capacity_Pallets__c = 5000, Parent_Facility__c = facByCode.get('USORD').Id),
    new Facility__c(Name = 'Memphis Customer Site', Facility_Code__c = 'USMEM', Facility_Type__c = 'Customer Site', City__c = 'Memphis', Country__c = 'USA', Location__Latitude__s = 35.1495, Location__Longitude__s = -90.0490, Is_Temperature_Controlled__c = false, Capacity_Pallets__c = 800, Parent_Facility__c = facByCode.get('USORD').Id),
    new Facility__c(Name = 'Jakarta Distribution', Facility_Code__c = 'IDJKT', Facility_Type__c = 'Warehouse', City__c = 'Jakarta', Country__c = 'Indonesia', Location__Latitude__s = -6.2088, Location__Longitude__s = 106.8456, Is_Temperature_Controlled__c = true, Capacity_Pallets__c = 4000, Parent_Facility__c = facByCode.get('SGSIN').Id)
};
upsert spokes Facility__c.Facility_Code__c;
for (Facility__c f : spokes) {
    facByCode.put(f.Facility_Code__c, f);
}

// ---------- Customers, contacts, products ----------
List<String> accountNames = new List<String>{ 'CTC - BioNova Pharma', 'CTC - FreshHarvest Foods', 'CTC - Arctic Seafood Co', 'CTC - VitaLife Labs', 'CTC - MedSupply Direct', 'CTC - Orchard Fresh Exports' };
Map<String, Account> accByName = new Map<String, Account>();
for (Account a : [SELECT Id, Name FROM Account WHERE Name IN :accountNames]) {
    accByName.put(a.Name, a);
}
List<Account> newAccounts = new List<Account>();
for (String n : accountNames) {
    if (!accByName.containsKey(n)) {
        newAccounts.add(new Account(Name = n, Industry = n.contains('Pharma') || n.contains('Labs') || n.contains('Med') ? 'Healthcare' : 'Food & Beverage', BillingCity = 'Chicago', BillingCountry = 'USA'));
    }
}
insert newAccounts;
for (Account a : newAccounts) {
    accByName.put(a.Name, a);
}
List<Account> accounts = new List<Account>();
for (String n : accountNames) {
    accounts.add(accByName.get(n));
}

Set<Id> accountsWithContacts = new Set<Id>();
for (Contact c : [SELECT AccountId FROM Contact WHERE AccountId IN :accounts]) {
    accountsWithContacts.add(c.AccountId);
}
List<Contact> newContacts = new List<Contact>();
for (Integer i = 0; i < accounts.size(); i++) {
    if (!accountsWithContacts.contains(accounts[i].Id)) {
        newContacts.add(new Contact(AccountId = accounts[i].Id, FirstName = 'Logistics', LastName = 'Manager ' + (i + 1), Email = 'logistics' + (i + 1) + '@ctc-demo.example.com', Title = 'Logistics Manager'));
    }
}
insert newContacts;
Map<Id, Id> contactByAccount = new Map<Id, Id>();
for (Contact c : [SELECT Id, AccountId FROM Contact WHERE AccountId IN :accounts]) {
    contactByAccount.put(c.AccountId, c.Id);
}

List<String> productNames = new List<String>{ 'CTC mRNA Vaccine Vials', 'CTC Insulin Pens', 'CTC Frozen Salmon Fillets', 'CTC Fresh Berries', 'CTC Blood Plasma Units' };
Map<String, Product2> prodByName = new Map<String, Product2>();
for (Product2 p : [SELECT Id, Name FROM Product2 WHERE Name IN :productNames]) {
    prodByName.put(p.Name, p);
}
List<Product2> newProducts = new List<Product2>();
for (String n : productNames) {
    if (!prodByName.containsKey(n)) {
        newProducts.add(new Product2(Name = n, IsActive = true));
    }
}
insert newProducts;
for (Product2 p : newProducts) {
    prodByName.put(p.Name, p);
}

// ---------- Carrier contracts (junction) ----------
Set<String> existingContracts = new Set<String>();
for (Carrier_Account__c ca : [SELECT Carrier__c, Account__c FROM Carrier_Account__c WHERE Account__c IN :accounts]) {
    existingContracts.add(ca.Carrier__c + '|' + ca.Account__c);
}
List<Carrier_Account__c> contracts = new List<Carrier_Account__c>();
List<String> contractScacs = new List<String>{ 'MAEU', 'FDXE', 'DHLG' };
for (Integer i = 0; i < accounts.size(); i++) {
    for (Integer j = 0; j < 2; j++) {
        String scac = contractScacs[Math.mod(i + j, 3)];
        String key = carrierByScac.get(scac).Id + '|' + accounts[i].Id;
        if (!existingContracts.contains(key)) {
            existingContracts.add(key);
            contracts.add(new Carrier_Account__c(Carrier__c = carrierByScac.get(scac).Id, Account__c = accounts[i].Id, Contract_Start__c = Date.today().addMonths(-6), Contract_End__c = Date.today().addMonths(18), Is_Preferred__c = (j == 0)));
        }
    }
}
insert contracts;

// ---------- Shipments ----------
List<String> classes = new List<String>{ 'Chilled', 'Frozen', 'Deep Frozen', 'Ambient' };
List<String> modes = new List<String>{ 'Air', 'Ocean', 'Road', 'Rail' };
Map<String, String> containerByMode = new Map<String, String>{ 'Air' => 'ULD Reefer', 'Ocean' => '40ft Reefer', 'Road' => 'Reefer Truck', 'Rail' => 'Intermodal Reefer' };
List<String> statuses = new List<String>{ 'Planned', 'Booked', 'In Transit', 'In Transit', 'In Transit', 'At Customs', 'Delivered', 'Delivered' };
List<String> priorities = new List<String>{ 'Standard', 'Expedited', 'Critical' };
List<String> originCodes = new List<String>{ 'NLRTM', 'USORD', 'SGSIN', 'BEANR', 'USIND' };
List<String> destCodes = new List<String>{ 'DEFRA', 'USMEM', 'IDJKT', 'USIND', 'BEANR' };
List<String> coldScacs = new List<String>{ 'MAEU', 'FDXE', 'DHLG' };

List<Shipment__c> shipments = new List<Shipment__c>();
for (Integer i = 0; i < 24; i++) {
    String status = statuses[Math.mod(i, statuses.size())];
    String mode = modes[Math.mod(i, 4)];
    Account acc = accounts[Math.mod(i, accounts.size())];
    Datetime departure = System.now().addDays(-3 + Math.mod(i, 6)).addHours(Math.mod(i * 5, 24));
    Datetime arrival = departure.addDays(2 + Math.mod(i, 5));
    Shipment__c s = new Shipment__c(
        External_Id__c = 'TMS-' + (1001 + i),
        Account__c = acc.Id,
        Contact__c = contactByAccount.get(acc.Id),
        Status__c = status,
        Priority__c = priorities[Math.mod(i, 3)],
        Transport_Mode__c = mode,
        Container_Type__c = containerByMode.get(mode),
        Temperature_Class__c = classes[Math.mod(i, 4)],
        Origin_Facility__c = facByCode.get(originCodes[Math.mod(i, originCodes.size())]).Id,
        Destination_Facility__c = facByCode.get(destCodes[Math.mod(i + 1, destCodes.size())]).Id,
        Planned_Departure__c = departure,
        Planned_Arrival__c = arrival,
        Declared_Value__c = 25000 + (i * 3750),
        Description__c = 'Seed shipment ' + (i + 1) + ': handle per temperature class, keep upright.'
    );
    if (status != 'Planned') {
        s.Carrier__c = carrierByScac.get(coldScacs[Math.mod(i, 3)]).Id;
    }
    if (status == 'Delivered') {
        s.Actual_Arrival__c = arrival.addHours(Math.mod(i, 5) - 2);
    }
    shipments.add(s);
}
upsert shipments Shipment__c.External_Id__c;

// Delays: revised ETA later than plan on a few in-transit shipments (trigger raises Delay exceptions idempotently)
List<Shipment__c> delayed = new List<Shipment__c>();
for (Shipment__c s : [SELECT Id, Planned_Arrival__c, Revised_ETA__c FROM Shipment__c WHERE External_Id__c IN ('TMS-1003', 'TMS-1004', 'TMS-1005', 'TMS-1011', 'TMS-1012') AND Status__c = 'In Transit']) {
    if (s.Revised_ETA__c == null) {
        delayed.add(new Shipment__c(Id = s.Id, Revised_ETA__c = s.Planned_Arrival__c.addHours(8 + (delayed.size() * 14))));
    }
}
update delayed;

// ---------- Lines (only for shipments with none yet) ----------
List<String> lotPrefix = new List<String>{ 'LOT-A', 'LOT-B', 'LOT-C' };
List<Product2> prods = prodByName.values();
List<Shipment_Line__c> lines = new List<Shipment_Line__c>();
for (Shipment__c s : [SELECT Id, External_Id__c, Line_Count__c FROM Shipment__c WHERE External_Id__c LIKE 'TMS-10%' OR External_Id__c LIKE 'TMS-11%']) {
    if (s.Line_Count__c == null || s.Line_Count__c == 0) {
        Integer seed = Integer.valueOf(s.External_Id__c.substring(4));
        for (Integer k = 0; k < 2; k++) {
            lines.add(new Shipment_Line__c(
                Shipment__c = s.Id,
                Product__c = prods[Math.mod(seed + k, prods.size())].Id,
                Quantity__c = 100 + Math.mod(seed * 7 + k * 13, 400),
                Unit_Weight_Kg__c = 0.25 + Math.mod(seed + k, 8) * 0.5,
                Lot_Number__c = lotPrefix[Math.mod(seed + k, 3)] + '-' + seed + k,
                Requires_Cold_Chain__c = true
            ));
        }
    }
}
insert lines;

// ---------- Hand-written exceptions covering each type/severity/status ----------
Map<String, Id> shipIdByExt = new Map<String, Id>();
for (Shipment__c s : [SELECT Id, External_Id__c FROM Shipment__c WHERE External_Id__c IN ('TMS-1003', 'TMS-1004', 'TMS-1006', 'TMS-1007', 'TMS-1008', 'TMS-1010')]) {
    shipIdByExt.put(s.External_Id__c, s.Id);
}
List<Shipment_Exception__c> exceptions = new List<Shipment_Exception__c>{
    new Shipment_Exception__c(Shipment__c = shipIdByExt.get('TMS-1006'), Exception_Type__c = 'Customs Hold', Severity__c = 'Medium', Status__c = 'Open', Detected_At__c = System.now().addHours(-30), Details__c = 'Held for missing commercial invoice.', Source_Event_Id__c = 'SEED-EX-1'),
    new Shipment_Exception__c(Shipment__c = shipIdByExt.get('TMS-1007'), Exception_Type__c = 'Damage', Severity__c = 'High', Status__c = 'Open', Detected_At__c = System.now().addHours(-12), Details__c = 'Crushed outer cartons on pallet 3.', Source_Event_Id__c = 'SEED-EX-2'),
    new Shipment_Exception__c(Shipment__c = shipIdByExt.get('TMS-1007'), Exception_Type__c = 'Documentation', Severity__c = 'Low', Status__c = 'Resolved', Detected_At__c = System.now().addDays(-2), Resolved_At__c = System.now().addDays(-1), Resolution_Notes__c = 'Corrected airway bill re-issued.', Details__c = 'Airway bill mismatch.', Source_Event_Id__c = 'SEED-EX-3'),
    new Shipment_Exception__c(Shipment__c = shipIdByExt.get('TMS-1010'), Exception_Type__c = 'Temperature Excursion', Severity__c = 'Critical', Status__c = 'Open', Detected_At__c = System.now().addHours(-6), Recorded_Temperature_C__c = 19.5, Details__c = 'Reefer unit failure suspected; reading 19.5C against frozen band.', Source_Event_Id__c = 'SEED-EX-4')
};
Database.UpsertResult[] exResults = Database.upsert(exceptions, Shipment_Exception__c.Source_Event_Id__c, false);
Integer exFail = 0;
for (Database.UpsertResult r : exResults) {
    if (!r.isSuccess()) {
        exFail++;
        System.debug('SEED exception failure: ' + r.getErrors()[0].getMessage());
    }
}

// ---------- Telemetry: one in-band reading, one excursion on a chilled in-transit shipment ----------
List<Shipment__c> telemetryTargets = [SELECT Id, External_Id__c, Min_Temp_C__c, Max_Temp_C__c FROM Shipment__c WHERE Status__c = 'In Transit' AND Temperature_Class__c = 'Chilled' AND Last_Telemetry_At__c = NULL AND External_Id__c LIKE 'TMS-1%' ORDER BY External_Id__c LIMIT 2];
List<Telemetry_Reading__e> events = new List<Telemetry_Reading__e>();
for (Integer i = 0; i < telemetryTargets.size(); i++) {
    Shipment__c s = telemetryTargets[i];
    events.add(new Telemetry_Reading__e(Shipment_External_Id__c = s.External_Id__c, Device_Id__c = 'SENSOR-' + (100 + i), Event_Uuid__c = 'SEED-TEL-' + s.External_Id__c, Temperature_C__c = i == 0 ? 5.0 : 13.5, Latitude__c = 50.1, Longitude__c = 8.6, Reading_Time__c = System.now()));
}
if (!events.isEmpty()) {
    EventBus.publish(events);
}

System.debug('SEED DONE carriers=' + carriers.size() + ' facilities=' + (hubs.size() + spokes.size()) + ' accounts=' + accounts.size() + ' shipments=' + shipments.size() + ' lines=' + lines.size() + ' contracts=' + contracts.size() + ' exceptions=' + exceptions.size() + ' exFail=' + exFail + ' events=' + events.size());
