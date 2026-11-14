import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/unlock_core.dart';

import '../../data/ids.dart';
import '../../providers.dart';
import '../common/messages.dart';
import '../vault/unlock.dart';

const int defaultPrebootPort = 2222;

class _EndpointRow {
  _EndpointRow(String host, int port)
    : host = TextEditingController(text: host),
      port = TextEditingController(text: '$port');

  final Key key = UniqueKey();
  final TextEditingController host;
  final TextEditingController port;

  void dispose() {
    host.dispose();
    port.dispose();
  }
}

class _DiskRow {
  _DiskRow(String disk, this.secretId)
    : disk = TextEditingController(text: disk);

  final Key key = UniqueKey();
  final TextEditingController disk;
  String? secretId;
}

/// Which form field a core validation message belongs to.
const _problemFields = {
  'name ': 'name',
  'user ': 'user',
  'post-boot port': 'postbootPort',
  'the tcp check': 'check',
  'wait timeout': 'waitTimeout',
  'boot timeout': 'bootTimeout',
};

String _sentence(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}.';

class HostFormScreen extends ConsumerStatefulWidget {
  const HostFormScreen({super.key, this.host});

  final Host? host;

  @override
  ConsumerState<HostFormScreen> createState() => _HostFormScreenState();
}

class _HostFormScreenState extends ConsumerState<HostFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _group;
  late final TextEditingController _user;
  late final TextEditingController _postbootHost;
  late final TextEditingController _postbootPort;
  late final TextEditingController _waitMinutes;
  late final TextEditingController _bootMinutes;
  final _pin = TextEditingController();
  late final List<_EndpointRow> _endpoints;
  late final List<_DiskRow> _disks;
  String? _keyId;
  String? _secretId;
  late String _profileId;
  late PostBootCheck _check;
  HostKey? _prebootKey;
  HostKey? _postbootKey;
  late bool _legacy;
  late bool _enabled;
  Map<String, String> _problems = const {};
  String? _formError;
  bool _saving = false;

  bool get _isNew => widget.host == null;

  @override
  void initState() {
    super.initState();
    final h = widget.host;
    _name = TextEditingController(text: h?.name ?? '');
    _group = TextEditingController(text: h?.group ?? '');
    _user = TextEditingController(text: h?.user ?? 'root');
    _postbootHost = TextEditingController(text: h?.postbootHost ?? '');
    _postbootPort = TextEditingController(text: '${h?.postbootPort ?? 22}');
    _waitMinutes = TextEditingController(
      text: '${h?.waitTimeout.inMinutes ?? 10}',
    );
    _bootMinutes = TextEditingController(
      text: '${h?.bootTimeout.inMinutes ?? 5}',
    );
    _endpoints = [
      for (final e in h?.preboot ?? const <Endpoint>[])
        _EndpointRow(e.host, e.port),
    ];
    if (_endpoints.isEmpty) {
      _endpoints.add(_EndpointRow('', defaultPrebootPort));
    }
    _disks = [
      for (final MapEntry(key: disk, value: id)
          in (h?.diskOverrides ?? const <String, String>{}).entries)
        _DiskRow(disk, id),
    ];
    _keyId = h?.keyId;
    _secretId = h?.secretId;
    _profileId = h?.profileId ?? UnlockProfile.debian.id;
    _check = h?.postbootCheck ?? PostBootCheck.sshHostKey;
    _prebootKey = h?.prebootKey;
    _postbootKey = h?.postbootKey;
    _legacy = h?.legacyAlgorithms ?? false;
    _enabled = h?.enabled ?? true;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _group,
      _user,
      _postbootHost,
      _postbootPort,
      _waitMinutes,
      _bootMinutes,
      _pin,
    ]) {
      c.dispose();
    }
    for (final e in _endpoints) {
      e.dispose();
    }
    for (final d in _disks) {
      d.disk.dispose();
    }
    super.dispose();
  }

  void _moveEndpoint(int from, int to) => setState(() {
    final row = _endpoints.removeAt(from);
    _endpoints.insert(to, row);
  });

  void _removeEndpoint(int index) =>
      setState(() => _endpoints.removeAt(index).dispose());

  Host _buildHost() {
    final pin = _pin.text.trim();
    return Host(
      id: widget.host?.id ?? newId(),
      name: _name.text.trim(),
      group: _group.text.trim().isEmpty ? null : _group.text.trim(),
      preboot: [
        for (final e in _endpoints)
          Endpoint(e.host.text.trim(), int.parse(e.port.text.trim())),
      ],
      user: _user.text.trim(),
      keyId: _keyId,
      secretId: _secretId,
      diskOverrides: {for (final d in _disks) d.disk.text.trim(): d.secretId!},
      profileId: _profileId,
      postbootHost: _postbootHost.text.trim().isEmpty
          ? null
          : _postbootHost.text.trim(),
      postbootPort: int.parse(_postbootPort.text.trim()),
      postbootCheck: _check,
      waitTimeout: Duration(minutes: int.parse(_waitMinutes.text.trim())),
      bootTimeout: Duration(minutes: int.parse(_bootMinutes.text.trim())),
      prebootKey: _prebootKey ?? (pin.isEmpty ? null : HostKey.parse(pin)),
      postbootKey: _postbootKey,
      legacyAlgorithms: _legacy,
      enabled: _enabled,
    );
  }

  Future<void> _save() async {
    setState(() {
      _problems = const {};
      _formError = null;
    });
    if (!_form.currentState!.validate()) return;
    final host = _buildHost();
    final problems = <String, String>{};
    final unmatched = <String>[];
    for (final p in host.validate()) {
      final field = _problemFields.entries
          .where((e) => p.startsWith(e.key))
          .map((e) => e.value)
          .firstOrNull;
      if (field == null) {
        unmatched.add(_sentence(p));
      } else {
        problems[field] = _sentence(p);
      }
    }
    if (problems.isNotEmpty || unmatched.isNotEmpty) {
      setState(() {
        _problems = problems;
        _formError = unmatched.isEmpty ? null : unmatched.join('\n');
      });
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(hostRepositoryProvider).save(host);
      if (mounted) Navigator.pop(context);
    } on Object catch (e) {
      if (mounted) setState(() => _formError = describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete host?',
      message: 'Delete "${widget.host!.name}"? Keys and passphrases stay.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(hostRepositoryProvider).delete(widget.host!.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _changePin({required bool clear}) async {
    final vault = await requireVault(
      context,
      ref,
      fresh: true,
      reason:
          'Changing a pinned host key needs the vault password or '
          'biometrics.',
    );
    if (vault == null || !mounted) return;
    if (clear) {
      setState(() => _prebootKey = null);
      return;
    }
    final key = await showDialog<HostKey>(
      context: context,
      builder: (_) => const _PinDialog(),
    );
    if (key != null && mounted) setState(() => _prebootKey = key);
  }

  String? _portError(String? v) {
    final port = int.tryParse((v ?? '').trim());
    return port == null || port < 1 || port > 65535 ? 'Port 1–65535' : null;
  }

  String? _minutesError(String? v) =>
      int.tryParse((v ?? '').trim()) == null ? 'Whole minutes' : null;

  @override
  Widget build(BuildContext context) {
    final keys = ref.watch(keysProvider).value ?? const [];
    final secrets = ref.watch(secretsProvider).value ?? const [];
    final profiles = ref.watch(profilesProvider).value ?? const [];
    final theme = Theme.of(context);
    final digits = [FilteringTextInputFormatter.digitsOnly];

    List<DropdownMenuItem<String?>> items(
      Iterable<(String, String)> options,
      String? selected, {
      required bool allowNone,
    }) {
      final known = {for (final (id, _) in options) id};
      return [
        if (allowNone)
          const DropdownMenuItem<String?>(value: null, child: Text('None')),
        for (final (id, label) in options)
          DropdownMenuItem<String?>(value: id, child: Text(label)),
        if (selected != null && !known.contains(selected))
          DropdownMenuItem<String?>(value: selected, child: const Text('…')),
      ];
    }

    final secretOptions = [for (final s in secrets) (s.id, s.label)];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New host' : 'Edit host'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Delete host',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (_formError case final e?)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  e,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            TextFormField(
              key: const ValueKey('host-name'),
              controller: _name,
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: _problems['name'],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('host-group'),
              controller: _group,
              decoration: const InputDecoration(
                labelText: 'Group (optional)',
                helperText: 'For "unlock all in group"',
              ),
            ),
            const SectionHeader(
              'Pre-boot SSH addresses',
              subtitle: 'Dropbear in the initramfs; tried in this order',
            ),
            for (final (i, row) in _endpoints.indexed)
              Padding(
                key: row.key,
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('preboot-host-$i'),
                        controller: row.host,
                        decoration: InputDecoration(
                          labelText: 'Address ${i + 1}',
                          hintText: 'Host name or IP',
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Enter a host name or IP'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 84,
                      child: TextFormField(
                        key: ValueKey('preboot-port-$i'),
                        controller: row.port,
                        keyboardType: TextInputType.number,
                        inputFormatters: digits,
                        decoration: const InputDecoration(labelText: 'Port'),
                        validator: _portError,
                      ),
                    ),
                    PopupMenuButton<String>(
                      key: ValueKey('preboot-menu-$i'),
                      tooltip: 'Address options',
                      onSelected: (action) => switch (action) {
                        'up' => _moveEndpoint(i, i - 1),
                        'down' => _moveEndpoint(i, i + 1),
                        _ => _removeEndpoint(i),
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'up',
                          enabled: i > 0,
                          child: const Text('Move up'),
                        ),
                        PopupMenuItem(
                          value: 'down',
                          enabled: i < _endpoints.length - 1,
                          child: const Text('Move down'),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          enabled: _endpoints.length > 1,
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(
                  () => _endpoints.add(_EndpointRow('', defaultPrebootPort)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add address'),
              ),
            ),
            const SectionHeader('Login'),
            TextFormField(
              key: const ValueKey('host-user'),
              controller: _user,
              decoration: InputDecoration(
                labelText: 'User',
                errorText: _problems['user'],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const ValueKey('host-key'),
              initialValue: _keyId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'SSH key',
                helperText: keys.isEmpty ? 'Add a key on the Keys tab' : null,
              ),
              items: items(
                [for (final k in keys) (k.id, '${k.label} (${k.typeLabel})')],
                _keyId,
                allowNone: true,
              ),
              onChanged: (v) => setState(() => _keyId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const ValueKey('host-secret'),
              initialValue: _secretId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Disk passphrase',
                helperText: secrets.isEmpty
                    ? 'Add one on the Passphrases tab'
                    : null,
              ),
              items: items(secretOptions, _secretId, allowNone: true),
              onChanged: (v) => setState(() => _secretId = v),
            ),
            const SectionHeader(
              'Per-disk passphrases (optional)',
              subtitle: 'Disk name as asked by the server, e.g. sda3_crypt',
            ),
            for (final (i, row) in _disks.indexed)
              Padding(
                key: row.key,
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('disk-name-$i'),
                        controller: row.disk,
                        decoration: const InputDecoration(labelText: 'Disk'),
                        validator: (v) {
                          final name = (v ?? '').trim();
                          if (name.isEmpty) return 'Enter the disk name';
                          final same = _disks
                              .where((d) => d.disk.text.trim() == name)
                              .length;
                          return same > 1 ? 'Listed twice' : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        key: ValueKey('disk-secret-$i'),
                        initialValue: row.secretId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Passphrase',
                        ),
                        items: items(
                          secretOptions,
                          row.secretId,
                          allowNone: false,
                        ),
                        validator: (v) => v == null ? 'Pick one' : null,
                        onChanged: (v) => setState(() => row.secretId = v),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove disk',
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          setState(() => _disks.removeAt(i).disk.dispose()),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _disks.add(_DiskRow('', null))),
                icon: const Icon(Icons.add),
                label: const Text('Add disk'),
              ),
            ),
            const SectionHeader('Unlock'),
            DropdownButtonFormField<String?>(
              key: const ValueKey('host-profile'),
              initialValue: _profileId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Unlock profile'),
              items: items(
                [for (final p in profiles) (p.id, p.name)],
                _profileId,
                allowNone: false,
              ),
              onChanged: (v) => setState(() => _profileId = v ?? _profileId),
            ),
            const SectionHeader(
              'After the unlock',
              subtitle: 'How the app confirms that the server booted',
            ),
            DropdownButtonFormField<PostBootCheck>(
              key: const ValueKey('host-check'),
              initialValue: _check,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Boot check',
                errorText: _problems['check'],
                errorMaxLines: 3,
              ),
              items: const [
                DropdownMenuItem(
                  value: PostBootCheck.sshHostKey,
                  child: Text('SSH host key differs from pre-boot'),
                ),
                DropdownMenuItem(
                  value: PostBootCheck.tcp,
                  child: Text('TCP port open'),
                ),
                DropdownMenuItem(
                  value: PostBootCheck.none,
                  child: Text('None'),
                ),
              ],
              onChanged: (v) => setState(() => _check = v ?? _check),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('postboot-host'),
                    controller: _postbootHost,
                    decoration: const InputDecoration(
                      labelText: 'Post-boot host',
                      hintText: 'First pre-boot address',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    key: const ValueKey('postboot-port'),
                    controller: _postbootPort,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: InputDecoration(
                      labelText: 'Port',
                      errorText:
                          _problems['postbootPort'] ??
                          (_problems.containsKey('check')
                              ? 'Same as pre-boot'
                              : null),
                      errorMaxLines: 4,
                    ),
                    validator: (v) =>
                        int.tryParse((v ?? '').trim()) == null ? 'Port' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('wait-timeout'),
                    controller: _waitMinutes,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: InputDecoration(
                      labelText: 'Wait for pre-boot (min)',
                      errorText: _problems['waitTimeout'],
                      errorMaxLines: 2,
                    ),
                    validator: _minutesError,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('boot-timeout'),
                    controller: _bootMinutes,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: InputDecoration(
                      labelText: 'Wait for boot (min)',
                      errorText: _problems['bootTimeout'],
                      errorMaxLines: 2,
                    ),
                    validator: _minutesError,
                  ),
                ),
              ],
            ),
            const SectionHeader('Host keys'),
            if (_prebootKey case final key?)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pinned pre-boot key'),
                subtitle: SelectableText(key.toString()),
                trailing: Wrap(
                  children: [
                    TextButton(
                      onPressed: () => _changePin(clear: false),
                      child: const Text('Replace'),
                    ),
                    TextButton(
                      onPressed: () => _changePin(clear: true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              )
            else
              TextFormField(
                key: const ValueKey('host-pin'),
                controller: _pin,
                decoration: const InputDecoration(
                  labelText: 'Pinned pre-boot key (optional)',
                  hintText: 'SHA256:… or ssh-ed25519 SHA256:…',
                  helperText:
                      'Leave empty to confirm the key on the first connect',
                  helperMaxLines: 2,
                ),
                validator: _pinError,
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Seen post-boot key'),
              subtitle: Text(
                _postbootKey?.toString() ??
                    'None yet; stored at the first boot check',
              ),
              trailing: _postbootKey == null
                  ? null
                  : TextButton(
                      onPressed: () => setState(() => _postbootKey = null),
                      child: const Text('Clear'),
                    ),
            ),
            const SectionHeader('Options'),
            SwitchListTile(
              key: const ValueKey('host-legacy'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Legacy algorithms'),
              subtitle: const Text(
                'ssh-rsa (SHA-1) host keys and CBC ciphers, for Dropbear '
                'older than 2020.79',
              ),
              value: _legacy,
              onChanged: (v) => setState(() => _legacy = v),
            ),
            SwitchListTile(
              key: const ValueKey('host-enabled'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Enabled'),
              subtitle: const Text(
                'Disabled hosts are skipped by "unlock all"',
              ),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ],
        ),
      ),
    );
  }
}

String? _pinError(String? v) {
  final text = (v ?? '').trim();
  if (text.isEmpty) return null;
  try {
    HostKey.parse(text);
    return null;
  } on FormatException {
    return 'Expected "SHA256:…" or "<type> SHA256:…"';
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog();

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _form = GlobalKey<FormState>();
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, HostKey.parse(_text.text));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pin a new pre-boot key'),
    content: Form(
      key: _form,
      child: TextFormField(
        key: const ValueKey('pin-dialog-field'),
        controller: _text,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'SHA256:… or ssh-ed25519 SHA256:…',
        ),
        validator: (v) =>
            (v ?? '').trim().isEmpty ? 'Paste the fingerprint' : _pinError(v),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Pin')),
    ],
  );
}
