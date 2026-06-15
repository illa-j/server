"""Site-wide Python customization — loaded automatically at interpreter startup.

Applies monkey-patches required for FreeTAKServer to run with current
opentelemetry-sdk versions.
"""
import FreeTAKServer.patches.otel_span_exporter_patch
