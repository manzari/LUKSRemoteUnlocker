import 'package:material_ui/material_ui.dart';

/// Static server-side advice, the same as docs/server-setup.md.
class SetupHelpScreen extends StatelessWidget {
  const SetupHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(text, style: theme.textTheme.titleMedium),
    );
    Widget code(String text) => Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        text,
        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Server setup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          heading('1. Dropbear in the initramfs'),
          const Text(
            'On Debian or Ubuntu install dropbear-initramfs, then set the '
            'options in /etc/dropbear/initramfs/dropbear.conf:',
          ),
          code(
            'DROPBEAR_OPTIONS="-p 2222 -s -j -k -I 180 -c cryptroot-unlock"',
          ),
          const Text('Rebuild the initramfs afterwards:'),
          code('update-initramfs -u'),
          heading('2. Pin the pre-boot host key'),
          const Text(
            'Print the fingerprint of the Dropbear host key on the server and '
            'paste it into the host form, or confirm it on the first connect:',
          ),
          code(
            'dropbearkey -y -f /etc/dropbear/initramfs/dropbear_ed25519_host_key',
          ),
          heading('3. A LUKS key slot for remote unlock'),
          const Text(
            'Add a dedicated passphrase in its own LUKS key slot for remote '
            'unlock, so a lost phone means removing one slot:',
          ),
          code('cryptsetup luksAddKey /dev/<disk>'),
          heading('4. One SSH key per device'),
          const Text(
            'Generate a separate SSH key on each device and add its public '
            'key to /etc/dropbear/initramfs/authorized_keys, so one device can '
            'be revoked by removing its line. Run update-initramfs -u again '
            'after changing that file.',
          ),
        ],
      ),
    );
  }
}
