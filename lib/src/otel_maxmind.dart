// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_maxmind_suppression.dart';

const _tracerName = 'dartastic_otel_libs_maxmind';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class MaxmindResult {
  /// Creates a result.
  const MaxmindResult({
    this.matched,
    this.countryCode,
    this.networkCidr,
    this.asn,
    this.isAnonymous,
    this.isAnonymousVpn,
    this.isHostingProvider,
    this.isTorExitNode,
    this.dbBuildEpoch,
  });

  /// Whether the IP was found in the database.
  final bool? matched;

  /// ISO 3166-1 alpha-2.
  final String? countryCode;

  /// Subnet that matched (e.g. `203.0.113.0/24`).
  final String? networkCidr;

  /// Autonomous System Number.
  final int? asn;

  final bool? isAnonymous;
  final bool? isAnonymousVpn;
  final bool? isHostingProvider;
  final bool? isTorExitNode;

  /// `build_epoch` from the .mmdb header — stale-DB detection.
  final int? dbBuildEpoch;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class MaxmindCallResult<T> {
  /// Creates a call result.
  const MaxmindCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final MaxmindResult? result;
}

/// Wraps a MaxMind reader lookup in an INTERNAL span (offline DB read,
/// no network). [database] is one of `country`, `city`, `asn`,
/// `anonymous_ip`, `connection_type`, `domain`, `enterprise`, `isp`.
Future<T> tracedMaxmind<T>({
  required String database,
  required Future<MaxmindCallResult<T>> Function() invoke,
  String? edition,
}) async {
  if (maxmindInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'db.system': 'maxmind',
    'maxmind.database': database,
  };
  if (edition != null) m['maxmind.edition'] = edition;

  final span = _tracer().startSpan(
    'maxmind lookup $database',
    kind: SpanKind.internal,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.matched != null) {
        extras.add(OTelAPI.attributeBool(
          'maxmind.matched',
          r.result!.matched!,
        ));
      }
      if (r.result!.countryCode != null) {
        extras.add(OTelAPI.attributeString(
          'maxmind.country.iso_code',
          r.result!.countryCode!,
        ));
      }
      if (r.result!.networkCidr != null) {
        extras.add(OTelAPI.attributeString(
          'maxmind.network.cidr',
          r.result!.networkCidr!,
        ));
      }
      if (r.result!.asn != null) {
        extras.add(OTelAPI.attributeInt(
          'maxmind.asn',
          r.result!.asn!,
        ));
      }
      if (r.result!.isAnonymous != null) {
        extras.add(OTelAPI.attributeBool(
          'maxmind.is_anonymous',
          r.result!.isAnonymous!,
        ));
      }
      if (r.result!.isAnonymousVpn != null) {
        extras.add(OTelAPI.attributeBool(
          'maxmind.is_anonymous_vpn',
          r.result!.isAnonymousVpn!,
        ));
      }
      if (r.result!.isHostingProvider != null) {
        extras.add(OTelAPI.attributeBool(
          'maxmind.is_hosting_provider',
          r.result!.isHostingProvider!,
        ));
      }
      if (r.result!.isTorExitNode != null) {
        extras.add(OTelAPI.attributeBool(
          'maxmind.is_tor_exit_node',
          r.result!.isTorExitNode!,
        ));
      }
      if (r.result!.dbBuildEpoch != null) {
        extras.add(OTelAPI.attributeInt(
          'maxmind.db.build_epoch',
          r.result!.dbBuildEpoch!,
        ));
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
