/**
 * Safe, structured logging. Every line carries the request id as a correlation id
 * and is redacted/truncated so PII and tokens never reach debug logs.
 */
public with sharing class CtcLog {
    private static final Integer MAX_LEN = 500;

    public static void info(String context, String message) {
        System.debug(LoggingLevel.INFO, format(context, message));
    }

    public static void error(String context, String message) {
        System.debug(LoggingLevel.ERROR, format(context, message));
    }

    public static String correlationId() {
        return Request.getCurrent().getRequestId();
    }

    @TestVisible
    private static String format(String context, String message) {
        return '[CTC][' + context + '][' + correlationId() + '] ' + redact(message);
    }

    @TestVisible
    private static String redact(String raw) {
        if (raw == null) {
            return '';
        }
        String s = raw.replaceAll('[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}', '***@***');
        s = s.replaceAll('(?i)(bearer\\s+)[A-Za-z0-9._\\-]+', '$1***');
        return s.length() > MAX_LEN ? s.substring(0, MAX_LEN) : s;
    }
}
