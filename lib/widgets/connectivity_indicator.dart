import 'package:flutter/material.dart';
import 'package:hockey_stats_app/services/connectivity_service.dart';
import 'package:hockey_stats_app/services/background_sync_service.dart';

/// Widget that displays connectivity and sync status to the user
class ConnectivityIndicator extends StatefulWidget {
  final bool showDetails;
  final EdgeInsets? padding;

  const ConnectivityIndicator({
    super.key,
    this.showDetails = false,
    this.padding,
  });

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  final ConnectivityService _connectivityService = ConnectivityService();
  final BackgroundSyncService _syncService = BackgroundSyncService();
  
  bool _isOnline = true;
  SyncStatus _syncStatus = SyncStatus.idle;
  int _pendingItems = 0;

  @override
  void initState() {
    super.initState();
    _initializeStatus();
    _listenToStatusChanges();
  }

  void _initializeStatus() {
    _isOnline = _connectivityService.isOnline;
    _syncStatus = _syncService.getCurrentStatus();
    _updatePendingItemsCount();
  }

  void _listenToStatusChanges() {
    // Listen to connectivity changes
    _connectivityService.connectivityStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }
    });

    // Listen to sync status changes
    _syncService.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _syncStatus = status;
        });
        _updatePendingItemsCount();
      }
    });
  }

  void _updatePendingItemsCount() {
    _syncService.getPendingItemsCount().then((count) {
      if (mounted) {
        setState(() {
          _pendingItems = count;
        });
      }
    });
  }

  Color _getStatusColor() {
    if (!_isOnline) {
      return Colors.grey;
    } else if (_syncStatus.isError) {
      return Colors.red;
    } else if (_syncStatus.isActive) {
      return Colors.orange;
    } else if (_pendingItems > 0) {
      return Colors.yellow.shade700;
    } else {
      return Colors.green;
    }
  }

  IconData _getStatusIcon() {
    if (!_isOnline) {
      return Icons.cloud_off;
    } else if (_syncStatus.isActive) {
      return Icons.sync;
    } else if (_pendingItems > 0) {
      return Icons.cloud_upload;
    } else {
      return Icons.cloud_done;
    }
  }

  String _getStatusText() {
    if (!_isOnline) {
      return 'Offline';
    } else if (_syncStatus.isActive) {
      return 'Syncing...';
    } else if (_pendingItems > 0) {
      return '$_pendingItems pending';
    } else {
      return 'Synced';
    }
  }

  String _getDetailedStatusText() {
    if (!_isOnline) {
      return 'Working offline. Data will sync when connection is restored.';
    } else if (_syncStatus.isActive) {
      return 'Syncing data with Google Sheets...';
    } else if (_pendingItems > 0) {
      return '$_pendingItems items waiting to sync. Tap to sync now.';
    } else {
      return 'All data is synced with Google Sheets.';
    }
  }

  void _onTap() {
    if (_isOnline && _pendingItems > 0 && !_syncStatus.isActive) {
      _syncService.triggerSync();
    } else if (!_isOnline) {
      _showOfflineDialog();
    }
  }

  void _showOfflineDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.grey),
              SizedBox(width: 8),
              Text('Offline Mode'),
            ],
          ),
          content: const Text(
            'You\'re currently working offline. All changes are saved locally and will automatically sync when your internet connection is restored.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    final icon = _getStatusIcon();
    final text = _getStatusText();

    if (widget.showDetails) {
      return Container(
        padding: widget.padding ?? const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: _onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _syncStatus.isActive
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      )
                    : Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _getDetailedStatusText(),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Compact indicator
      return InkWell(
        onTap: _onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _syncStatus.isActive
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    )
                  : Icon(icon, color: color, size: 12),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}

/// A floating connectivity indicator that can be placed anywhere in the app
class FloatingConnectivityIndicator extends StatelessWidget {
  final Alignment alignment;
  final EdgeInsets margin;

  const FloatingConnectivityIndicator({
    super.key,
    this.alignment = Alignment.topRight,
    this.margin = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Container(
          margin: margin,
          child: const ConnectivityIndicator(showDetails: false),
        ),
      ),
    );
  }
}

/// A banner that shows connectivity status at the top of screens
class ConnectivityBanner extends StatelessWidget {
  final Widget child;
  final bool showWhenOnline;

  const ConnectivityBanner({
    super.key,
    required this.child,
    this.showWhenOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService().connectivityStream,
      initialData: ConnectivityService().isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        
        if (isOnline && !showWhenOnline) {
          return child;
        }

        return Column(
          children: [
            if (!isOnline)
              Container(
                width: double.infinity,
                color: Colors.grey.shade800,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: const Row(
                  children: [
                    Icon(Icons.cloud_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Working offline - changes will sync when online',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
