"""Site-wide Python customization — loaded automatically at interpreter startup.

Applies monkey-patches required for FreeTAKServer to run with current
opentelemetry-sdk versions.

digitalpy's ObjectFactory calls setattr(instance, 'span_exporter', value) on
BatchSpanProcessor instances. In opentelemetry-sdk >=1.24.0, span_exporter became
a read-only property (getter only, no setter), causing AttributeError at runtime.
This patch adds a setter to make the property writable again.
"""
try:
    from opentelemetry.sdk.trace.export import BatchSpanProcessor

    _prop = BatchSpanProcessor.span_exporter
    if isinstance(_prop, property) and _prop.fset is None:
        BatchSpanProcessor.span_exporter = property(
            _prop.fget,
            lambda self, value: setattr(self, '_span_exporter', value),
            _prop.fdel if _prop.fdel else None,
            _prop.__doc__,
        )
except ImportError:
    pass
