@IsTest
private class CtcSupportTest {
    @IsTest
    static void logRedactsSensitiveContent() {
        String out = CtcLog.redact('mail bob@example.com token Bearer abc.def-123');
        Assert.isFalse(out.contains('bob@example.com'));
        Assert.isFalse(out.contains('abc.def-123'));
        Assert.areEqual('', CtcLog.redact(null));
        Assert.areEqual(500, CtcLog.redact('x'.repeat(900)).length());
        CtcLog.info('t', 'hello');
        CtcLog.error('t', 'oops');
    }

    @IsTest
    static void policyHelpers() {
        Assert.isTrue(TemperaturePolicyService.isExcursion(2, 8, 9));
        Assert.isTrue(TemperaturePolicyService.isExcursion(2, 8, 1));
        Assert.isFalse(TemperaturePolicyService.isExcursion(2, 8, 5));
        Assert.isFalse(TemperaturePolicyService.isExcursion(2, 8, null));
        Assert.areEqual('Critical', TemperaturePolicyService.severityFor(2, 8, 13, 4));
        Assert.areEqual('High', TemperaturePolicyService.severityFor(2, 8, 10, 4));
        Assert.areEqual('Medium', TemperaturePolicyService.severityFor(2, 8, 9, 4));
        Assert.isNotNull(TemperaturePolicyService.forClass('Frozen'));
        Assert.isNull(TemperaturePolicyService.forClass(null));
        Assert.isTrue(FeatureToggle.isEnabled('Does_Not_Exist'));
    }
}
