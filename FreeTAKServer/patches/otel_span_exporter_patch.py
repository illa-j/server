"""Monkey-patch opentelemetry BatchSpanProcessor so digitalpy can set span_exporter via setattr.

In opentelemetry-sdk >=1.24.0, BatchSpanProcessor.span_exporter became a read-only
property. digitalpy's ObjectFactory tries setattr(instance, 'span_exporter', value)
which raises AttributeError. This patch adds a setter so the property is writable.
"""
from opentelemetry.sdk.trace.export import BatchSpanProcessor

_prop = BatchSpanProcessor.span_exporter
if isinstance(_prop, property) and _prop.fset is None:
    BatchSpanProcessor.span_exporter = property(
        _prop.fget,
        lambda self, value: setattr(self, '_span_exporter', value),
        _prop.fdel if _prop.fdel else None,
        _prop.__doc__,
    )
