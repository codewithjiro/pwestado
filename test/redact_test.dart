import 'package:flutter_test/flutter_test.dart';
import 'package:pwestado/core/utils/redact.dart';

void main() {
  const fakeToken = 'pk.FAKE_TOKEN_FOR_TESTS_0123456789';

  test('strips tokens from URLs but keeps host and path', () {
    const message =
        'Failed to load https://api.mapbox.com/styles/v1/mapbox/standard'
        '?access_token=$fakeToken&sku=123: HTTP 401';
    final redacted = redactSecrets(message);

    expect(redacted, isNot(contains(fakeToken)));
    expect(redacted, isNot(contains('FAKE_TOKEN')));
    expect(redacted, contains('https://api.mapbox.com/styles/v1/mapbox'));
    expect(redacted, contains('HTTP 401'));
  });

  test('strips bare tokens and token= parameters outside URLs', () {
    expect(redactSecrets('token is $fakeToken'), isNot(contains('FAKE_TOKEN')));
    expect(redactSecrets('sk.abcdefghijklmnop leaked'), 'sk.<redacted> leaked');
    expect(redactSecrets('access_token=abc123 x'), 'access_token=<redacted> x');
  });

  test('leaves ordinary messages alone and caps the length', () {
    expect(
      redactSecrets('SocketException: Failed host lookup'),
      'SocketException: Failed host lookup',
    );
    expect(redactSecrets('x' * 500).length, 301);
  });

  test('describeError keeps the type name', () {
    expect(
      describeError(StateError('url ?access_token=$fakeToken')),
      allOf(startsWith('StateError: '), isNot(contains('FAKE_TOKEN'))),
    );
  });
}
