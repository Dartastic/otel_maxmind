// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_maxmind/otel_maxmind.dart';

/// Traces Maxmind calls with OpenTelemetry.
///
/// `otel_maxmind` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Maxmind call in
/// [tracedMaxmind]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'maxmind-example');

  // Wraps a MaxMind reader lookup in an INTERNAL span (offline DB read, no network).
  final maxmindId = await tracedMaxmind<String>(
    database: 'country',
    edition: 'example',
    invoke: () async {
      // Make the Maxmind call here, then report what it returned.
      const id = 'maxmind_8f3a2c';
      return const MaxmindCallResult(
          value: id,
          result: MaxmindResult(
              matched: true,
              countryCode: 'example',
              networkCidr: '203.0.113.0/24',
              asn: 1,
              isAnonymous: true,
              isAnonymousVpn: true,
              isHostingProvider: true,
              isTorExitNode: true,
              dbBuildEpoch: 1));
    },
  );
  OTelLog.info('tracedMaxmind returned $maxmindId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutMaxmindInstrumentationAsync.
  await runWithoutMaxmindInstrumentationAsync(
    () => tracedMaxmind<String>(
      database: 'country',
      edition: 'example',
      invoke: () async {
        const id = 'maxmind_8f3a2c';
        return const MaxmindCallResult(
            value: id,
            result: MaxmindResult(
                matched: true,
                countryCode: 'example',
                networkCidr: '203.0.113.0/24',
                asn: 1,
                isAnonymous: true,
                isAnonymousVpn: true,
                isHostingProvider: true,
                isTorExitNode: true,
                dbBuildEpoch: 1));
      },
    ),
  );

  await OTel.shutdown();
}
