// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_maxmind/otel_maxmind.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_maxmind-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('anonymous_ip lookup records VPN + Tor flags', () async {
    await tracedMaxmind<String>(
      database: 'anonymous_ip',
      edition: 'GeoIP2-Anonymous-IP',
      invoke: () async => const MaxmindCallResult(
        value: 'ok',
        result: MaxmindResult(
          matched: true,
          isAnonymous: true,
          isAnonymousVpn: true,
          isTorExitNode: false,
          networkCidr: '203.0.113.0/24',
          dbBuildEpoch: 1700000000,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('maxmind lookup anonymous_ip')!);
    expect(a['maxmind.database'], 'anonymous_ip');
    expect(a['maxmind.is_anonymous_vpn'], true);
    expect(a['maxmind.is_tor_exit_node'], false);
    expect(a['maxmind.network.cidr'], '203.0.113.0/24');
    expect(a['maxmind.db.build_epoch'], 1700000000);
  });

  test('city lookup records country_iso + asn', () async {
    await tracedMaxmind<String>(
      database: 'city',
      invoke: () async => const MaxmindCallResult(
        value: 'ok',
        result: MaxmindResult(matched: true, countryCode: 'US', asn: 15169),
      ),
    );
    final a = attrsOf(spans.findSpanByName('maxmind lookup city')!);
    expect(a['maxmind.country.iso_code'], 'US');
    expect(a['maxmind.asn'], 15169);
  });

  test('suppression skips spans', () async {
    await runWithoutMaxmindInstrumentationAsync(() async {
      await tracedMaxmind<String>(
        database: 'country',
        invoke: () async => const MaxmindCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('maxmind '), isEmpty);
  });
}
