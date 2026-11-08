trigger TelemetryReadingTrigger on Telemetry_Reading__e(after insert) {
    TelemetryService.process(Trigger.new);
}
