/// Why a private key could not be imported or loaded.
sealed class SshKeyException implements Exception {
  const SshKeyException(this.message);

  final String message;

  @override
  String toString() => 'SshKeyException: $message';
}

final class KeyPassphraseRequiredException extends SshKeyException {
  const KeyPassphraseRequiredException()
    : super('The key is protected by a passphrase.');
}

final class WrongKeyPassphraseException extends SshKeyException {
  const WrongKeyPassphraseException() : super('The key passphrase is wrong.');
}

final class NotAPrivateKeyException extends SshKeyException {
  const NotAPrivateKeyException()
    : super(
        'This is a public key. Import the private key file '
        '(usually the same name without ".pub").',
      );
}

final class UnsupportedKeyException extends SshKeyException {
  const UnsupportedKeyException(super.message);
}

final class MalformedKeyException extends SshKeyException {
  const MalformedKeyException([
    super.message = 'The file is not a valid private key.',
  ]);
}
