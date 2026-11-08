/**
 * Outbound REST callout to the carrier tracking API through the Carrier_Tracking Named Credential.
 * Timeout and circuit breaker come from the Integration_Settings__c hierarchy setting.
 */
public with sharing class CarrierStatusClient {
    public class CarrierException extends Exception {
    }

    public class Status {
        public String status;
        public Datetime estimatedArrival;
    }

    private static final Integer DEFAULT_TIMEOUT_MS = 20000;

    public static Status fetch(String shipmentReference) {
        Integration_Settings__c cfg = Integration_Settings__c.getInstance();
        if (cfg.Circuit_Open__c == true) {
            throw new CarrierException('Carrier circuit breaker is open; skipping callout.');
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Carrier_Tracking/shipments/' + EncodingUtil.urlEncode(shipmentReference, 'UTF-8'));
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(cfg.Callout_Timeout_Ms__c == null ? DEFAULT_TIMEOUT_MS : Math.min(120000, Integer.valueOf(cfg.Callout_Timeout_Ms__c)));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new CarrierException(String.format(Label.CTC_Err_Callout_Failed, new List<Object>{ res.getStatusCode() }));
        }
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Status result = new Status();
        result.status = (String) body.get('status');
        String eta = (String) body.get('estimatedArrival');
        if (String.isNotBlank(eta)) {
            result.estimatedArrival = (Datetime) JSON.deserialize('"' + eta + '"', Datetime.class);
        }
        return result;
    }
}
