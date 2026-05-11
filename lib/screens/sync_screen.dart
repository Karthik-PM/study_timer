import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/sessions_provider.dart';
import '../providers/tags_provider.dart';
import '../services/sync_service.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  String? _localIp;
  bool _hosting = false;
  bool _syncing = false;
  String? _statusMessage;
  bool _statusOk = true;
  final _ipCtrl = TextEditingController();
  SyncServer? _server;
  SyncMode _syncMode = SyncMode.merge;

  @override
  void initState() {
    super.initState();
    _getLocalIp();
  }

  @override
  void dispose() {
    _server?.stop();
    _ipCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      // Prefer known WiFi interface names (wlan0 on Android, en0 on iOS/macOS)
      const wifiNames = {'wlan0', 'en0', 'en1', 'wlan1'};
      for (final iface in interfaces) {
        if (wifiNames.contains(iface.name.toLowerCase()) &&
            iface.addresses.isNotEmpty) {
          if (mounted) setState(() => _localIp = iface.addresses.first.address);
          return;
        }
      }

      // Fallback: first address that looks like a private LAN IP
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              ip.startsWith('172.')) {
            if (mounted) setState(() => _localIp = ip);
            return;
          }
        }
      }

      // Last resort: first available
      for (final iface in interfaces) {
        if (iface.addresses.isNotEmpty) {
          if (mounted) setState(() => _localIp = iface.addresses.first.address);
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _startServer() async {
    try {
      final server = SyncServer();
      await server.start();
      setState(() {
        _server = server;
        _hosting = true;
        _statusMessage = 'Waiting for connection…';
        _statusOk = true;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Could not start server: $e';
        _statusOk = false;
      });
    }
  }

  void _stopServer() {
    _server?.stop();
    _server = null;
    if (mounted) setState(() => _hosting = false);
  }

  Future<void> _syncAsClient() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) return;
    setState(() {
      _syncing = true;
      _statusMessage = 'Connecting…';
      _statusOk = true;
    });
    try {
      final result = await syncWithHost(ip, _syncMode);
      if (!mounted) return;
      ref.read(sessionsProvider.notifier).reload();
      ref.read(tagsProvider.notifier).load();
      setState(() {
        _syncing = false;
        _statusMessage = _successMessage(result);
        _statusOk = true;
      });
    } catch (e) {
      setState(() {
        _syncing = false;
        _statusMessage = e.toString().replaceAll('Exception: ', '');
        _statusOk = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sync')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoBanner(),
            const SizedBox(height: 24),

            // HOST section
            Text('This device as Host',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Start a server here, then connect from your other device.',
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 12),

            if (!_hosting)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _startServer,
                  icon: const Icon(Icons.wifi_tethering_rounded),
                  label: const Text('Start Sync Server',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              )
            else
              _HostPanel(
                ip: _localIp,
                onStop: _stopServer,
              ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),

            // CLIENT section
            Text('Connect to another device',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Enter the IP shown on the host device.',
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 12),

            // Sync mode selector
            _SyncModeSelector(
              selected: _syncMode,
              onChanged: (m) => setState(() => _syncMode = m),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Host IP (e.g. 192.168.1.5)',
                      prefixIcon: Icon(Icons.router_rounded),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _syncing ? null : _syncAsClient,
                  child: _syncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Sync'),
                ),
              ],
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (_statusOk ? Colors.green : Colors.red)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_statusOk ? Colors.green : Colors.red)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusOk
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      color: _statusOk ? Colors.green : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_statusMessage!,
                          style: TextStyle(
                              color: _statusOk ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                              fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _successMessage(SyncResult result) {
  switch (result.mode) {
    case SyncMode.merge:
      return 'Merged! +${result.sessionsAdded} sessions, +${result.tagsAdded} tags added.';
    case SyncMode.getFromHost:
      return 'Overwritten with host data: ${result.sessionsAdded} sessions, ${result.tagsAdded} tags.';
    case SyncMode.sendToHost:
      return 'Your data pushed to host successfully.';
  }
}

class _SyncModeSelector extends StatelessWidget {
  final SyncMode selected;
  final ValueChanged<SyncMode> onChanged;

  const _SyncModeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sync mode',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 8),
        _ModeOption(
          icon: Icons.merge_rounded,
          label: 'Merge',
          description: 'Both devices get all sessions from each other',
          selected: selected == SyncMode.merge,
          onTap: () => onChanged(SyncMode.merge),
        ),
        const SizedBox(height: 6),
        _ModeOption(
          icon: Icons.download_rounded,
          label: 'Get from host',
          description: 'Replace your data with the host\'s data',
          selected: selected == SyncMode.getFromHost,
          onTap: () => onChanged(SyncMode.getFromHost),
          warning: true,
        ),
        const SizedBox(height: 6),
        _ModeOption(
          icon: Icons.upload_rounded,
          label: 'Send to host',
          description: 'Replace the host\'s data with your data',
          selected: selected == SyncMode.sendToHost,
          onTap: () => onChanged(SyncMode.sendToHost),
          warning: true,
        ),
      ],
    );
  }
}

class _ModeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final bool warning;
  final VoidCallback onTap;

  const _ModeOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = warning ? Colors.orange : colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.1)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.6)
                : colorScheme.outline.withValues(alpha: 0.2),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? accent : colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? accent : colorScheme.onSurface)),
                  Text(description,
                      style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
            if (warning && selected)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.warning_amber_rounded,
                    size: 15, color: Colors.orange.withValues(alpha: 0.7)),
              ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? accent : colorScheme.outline.withValues(alpha: 0.4),
                    width: 2),
                color: selected ? accent : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _HostPanel extends StatelessWidget {
  final String? ip;
  final VoidCallback onStop;

  const _HostPanel({this.ip, required this.onStop});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const _PulsingDot(color: Colors.green),
              const SizedBox(width: 8),
              Text('Server running',
                  style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ],
          ),
          if (ip != null) ...[
            const SizedBox(height: 16),
            Text('Your IP address',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: ip!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('IP copied to clipboard'),
                      behavior: SnackBarBehavior.floating),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ip!,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            letterSpacing: 1)),
                    const SizedBox(width: 8),
                    Icon(Icons.copy_rounded,
                        size: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.4)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: ip!,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(8),
            ),
            const SizedBox(height: 8),
            Text('Scan from the other device or type the IP above',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.4)),
                textAlign: TextAlign.center),
          ] else ...[
            const SizedBox(height: 12),
            Text('Could not detect IP — check WiFi connection',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange.withValues(alpha: 0.8))),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop_rounded, color: Colors.red),
            label: const Text('Stop Server',
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_rounded, color: colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Both devices must be on the same WiFi network. No internet needed.',
              style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
