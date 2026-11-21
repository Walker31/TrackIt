import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../services/app_mode_service.dart';
import '../services/sync_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_snackbar.dart';

/// Where this device's data stands with the server.
enum SyncState { localOnly, offline, syncing, waiting, synced }

/// Live sync status: offline, uploading, changes waiting, or synced (and
/// when). Tapping it syncs now. [expanded] shows a label beside the icon
/// (the desktop side rail); otherwise it is an icon with a tooltip.
class SyncStatusIndicator extends StatefulWidget {
  final bool expanded;

  const SyncStatusIndicator({super.key, this.expanded = false});

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  final _sync = SyncService();
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _tick;
  Timer? _debounce;

  bool _offline = false;
  int _pending = 0;
  DateTime? _lastSynced;

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_sync.onActivity.listen((_) => _scheduleRefresh()))
      ..add(
        Connectivity().onConnectivityChanged.listen((results) {
          _offline = results.every((r) => r == ConnectivityResult.none);
          _scheduleRefresh();
        }),
      );
    // Keeps "2 min ago" current.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    Connectivity().checkConnectivity().then((results) {
      _offline = results.every((r) => r == ConnectivityResult.none);
      _refresh();
    });
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _tick?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  /// A burst of writes asks once.
  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _refresh);
  }

  Future<void> _refresh() async {
    if (!AppModeService.isServer) {
      if (mounted) setState(() {});
      return;
    }
    final (last, pending) = await (
      SyncService.lastSyncedAt(),
      SyncService.pendingChanges(),
    ).wait;
    if (!mounted) return;
    setState(() {
      _lastSynced = last;
      _pending = pending;
    });
  }

  SyncState get _state {
    if (!AppModeService.isServer) return SyncState.localOnly;
    if (_offline) return SyncState.offline;
    if (_sync.isSyncing) return SyncState.syncing;
    if (_pending > 0) return SyncState.waiting;
    return SyncState.synced;
  }

  Future<void> _syncNow() async {
    if (!AppModeService.isServer) return;
    if (_pending > 0) {
      await _showPending();
      return;
    }
    if (_offline) {
      AppSnackbar.info(
        context,
        'You are offline. Changes upload when you reconnect.',
      );
      return;
    }
    await _sync.performSync(forcePull: true);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final (icon, color, label) = switch (state) {
      SyncState.localOnly => (
        Icons.phone_android_outlined,
        AppColors.textTertiary,
        'Saved on this device',
      ),
      SyncState.offline => (
        Icons.cloud_off_outlined,
        AppColors.accent,
        _pending > 0 ? 'Offline · ${_count(_pending)} waiting' : 'Offline',
      ),
      SyncState.syncing => (
        Icons.cloud_sync_outlined,
        AppColors.primary,
        'Syncing…',
      ),
      SyncState.waiting => (
        Icons.cloud_upload_outlined,
        AppColors.accent,
        '${_count(_pending)} waiting to upload',
      ),
      SyncState.synced => (
        Icons.cloud_done_outlined,
        AppColors.income,
        _lastSynced == null ? 'Synced' : 'Synced ${_ago(_lastSynced!)}',
      ),
    };
    final tooltip = switch (state) {
      SyncState.localOnly =>
        'Your data stays on this device. Sign in from Settings to sync.',
      SyncState.offline => 'Changes upload when you reconnect.',
      SyncState.waiting => '$label. Click to see what.',
      _ => '$label. Click to sync now.',
    };

    final iconWidget = Icon(icon, size: 20, color: color);
    if (!widget.expanded) {
      // Phone headers are tight: local-only use has nothing to report.
      if (state == SyncState.localOnly) return const SizedBox.shrink();
      return IconButton(
        tooltip: tooltip,
        onPressed: _syncNow,
        icon: iconWidget,
      );
    }
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: _syncNow,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              iconWidget,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Lists what hasn't uploaded yet, with a button to try now.
  Future<void> _showPending() async {
    final byKind = await SyncService.pendingByKind();
    if (!mounted) return;
    final retry = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Waiting to upload', style: AppTextStyles.h3),
              const SizedBox(height: 4),
              Text(
                _offline
                    ? 'You are offline. These upload when you reconnect.'
                    : 'Saved on this device. They upload on the next sync.',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              for (final e in byKind.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(e.key, style: AppTextStyles.bodyMd)),
                      Text(
                        '${e.value}',
                        style: AppTextStyles.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_lastSynced != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Last synced ${_ago(_lastSynced!)}',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (!_offline)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Sync now'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (retry == true) {
      await _sync.performSync(forcePull: true);
      await _refresh();
    }
  }

  static String _count(int n) => '$n change${n == 1 ? '' : 's'}';

  static String _ago(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }
}
