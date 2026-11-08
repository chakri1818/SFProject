/**
 * Reads Feature_Toggle__mdt kill switches. Missing records default to enabled so a
 * fresh environment behaves normally; operations can disable a feature per environment.
 */
public with sharing class FeatureToggle {
    @TestVisible
    private static Map<String, Boolean> overrides = new Map<String, Boolean>();

    public static Boolean isEnabled(String developerName) {
        if (overrides.containsKey(developerName)) {
            return overrides.get(developerName);
        }
        Feature_Toggle__mdt toggle = Feature_Toggle__mdt.getInstance(developerName);
        return toggle == null ? true : toggle.Is_Enabled__c;
    }
}
