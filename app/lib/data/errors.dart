/// An operation the data layer refused, with a message fit for the UI.
sealed class DataException implements Exception {
  const DataException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class InUseException extends DataException {
  InUseException(String what, String label, this.hostNames)
    : super(
        '$what "$label" is used by ${hostNames.join(', ')}. '
        'Assign something else to ${hostNames.length == 1 ? 'that host' : 'those hosts'} first.',
      );

  final List<String> hostNames;
}

final class DuplicateKeyException extends DataException {
  DuplicateKeyException(this.existingLabel)
    : super('This key is already stored as "$existingLabel".');

  final String existingLabel;
}

final class DuplicateLabelException extends DataException {
  DuplicateLabelException(String what, String label)
    : super('$what labelled "$label" already exists. Choose another label.');
}

/// Labels compare trimmed and case-insensitively, like the label validators.
bool sameLabel(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

final class ReadOnlyProfileException extends DataException {
  const ReadOnlyProfileException()
    : super('Built-in profiles are read-only. Copy it to make changes.');
}

final class NotFoundException extends DataException {
  const NotFoundException(super.message);
}
