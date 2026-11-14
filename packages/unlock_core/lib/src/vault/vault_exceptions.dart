/// Base of all vault errors. Messages never contain secret bytes.
sealed class VaultException implements Exception {
  const VaultException(this.message);

  final String message;

  @override
  String toString() => 'VaultException: $message';
}

final class VaultLockedException extends VaultException {
  const VaultLockedException() : super('vault is locked');
}

final class VaultNotInitializedException extends VaultException {
  const VaultNotInitializedException() : super('no vault in this store');
}

final class VaultAlreadyExistsException extends VaultException {
  const VaultAlreadyExistsException() : super('store already holds vault data');
}

final class VaultRecordNotFoundException extends VaultException {
  VaultRecordNotFoundException(this.id) : super('record $id not found');

  final String id;
}

/// A required slot is missing, or an operation would leave the vault without one.
final class VaultNoSlotException extends VaultException {
  const VaultNoSlotException(super.message);
}

final class VaultUnsupportedVersionException extends VaultException {
  VaultUnsupportedVersionException(this.version)
    : super('unsupported vault format version $version');

  final int version;
}

/// Stored data failed authentication or is malformed.
class VaultCorruptException extends VaultException {
  const VaultCorruptException(super.message);
}

/// The password slot did not open: wrong password or a damaged slot (indistinguishable).
final class VaultWrongPasswordException extends VaultCorruptException {
  const VaultWrongPasswordException()
    : super('wrong password or damaged password slot');
}

/// The biometric slot is gone (new enrollment, wiped or foreign key); use the recovery password.
final class VaultKeyInvalidatedException extends VaultException {
  const VaultKeyInvalidatedException([
    super.message = 'biometric slot invalidated',
  ]);
}

enum VaultKeyUnavailableReason { userCancelled, lockedOut, unavailable }

final class VaultKeyUnavailableException extends VaultException {
  VaultKeyUnavailableException(this.reason)
    : super('biometric slot unavailable: ${reason.name}');

  final VaultKeyUnavailableReason reason;
}
