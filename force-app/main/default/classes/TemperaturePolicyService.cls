/**
 * Domain service over Temperature_Policy__mdt (deployable configuration, cached per transaction).
 */
public with sharing class TemperaturePolicyService {
    public class Band {
        public Decimal minC;
        public Decimal maxC;
        public Decimal criticalDelta;
    }

    private static Map<String, Band> bandsByClass;

    public static Band forClass(String temperatureClass) {
        if (bandsByClass == null) {
            bandsByClass = new Map<String, Band>();
            for (Temperature_Policy__mdt p : Temperature_Policy__mdt.getAll().values()) {
                Band b = new Band();
                b.minC = p.Min_Temp_C__c;
                b.maxC = p.Max_Temp_C__c;
                b.criticalDelta = p.Critical_Delta_C__c;
                bandsByClass.put(p.MasterLabel, b);
            }
        }
        return temperatureClass == null ? null : bandsByClass.get(temperatureClass);
    }

    public static Boolean isExcursion(Decimal minC, Decimal maxC, Decimal reading) {
        if (reading == null) {
            return false;
        }
        return (maxC != null && reading > maxC) || (minC != null && reading < minC);
    }

    /** Severity from how far outside the band the reading is, relative to the policy's critical delta. */
    public static String severityFor(Decimal minC, Decimal maxC, Decimal reading, Decimal criticalDelta) {
        Decimal delta = (maxC != null && reading > maxC) ? reading - maxC : minC - reading;
        Decimal critical = criticalDelta == null ? 5 : criticalDelta;
        if (delta >= critical) {
            return 'Critical';
        }
        return delta >= critical / 2 ? 'High' : 'Medium';
    }
}
