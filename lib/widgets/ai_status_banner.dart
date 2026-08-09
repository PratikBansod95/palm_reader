import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/colors.dart';
import '../services/ai_status_service.dart';

class AiStatusBanner extends ConsumerStatefulWidget {
  const AiStatusBanner({
    super.key,
    this.compact = false,
    this.showCheckButton = true,
  });

  final bool compact;
  final bool showCheckButton;

  @override
  ConsumerState<AiStatusBanner> createState() => _AiStatusBannerState();
}

class _AiStatusBannerState extends ConsumerState<AiStatusBanner> {
  late AiStatus _status;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _status = ref.read(aiStatusServiceProvider).currentConfiguredStatus();
  }

  Future<void> _runCheck() async {
    setState(() {
      _checking = true;
      _status = const AiStatus(
        state: AiConnectionState.checking,
        title: 'Checking AI…',
        detail: 'Contacting OpenRouter to verify the connection.',
      );
    });

    final result = await ref.read(aiStatusServiceProvider).checkLiveConnection();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _status = result;
    });
  }

  Color get _accent {
    switch (_status.state) {
      case AiConnectionState.live:
        return const Color(0xFF7DCEA0);
      case AiConnectionState.offlineDemo:
        return const Color(0xFFE6B84F);
      case AiConnectionState.error:
        return const Color(0xFFE07A7A);
      case AiConnectionState.checking:
      case AiConnectionState.unknown:
        return AppColors.softGold;
    }
  }

  IconData get _icon {
    switch (_status.state) {
      case AiConnectionState.live:
        return Icons.verified_rounded;
      case AiConnectionState.offlineDemo:
        return Icons.offline_bolt_rounded;
      case AiConnectionState.error:
        return Icons.error_outline_rounded;
      case AiConnectionState.checking:
        return Icons.sync_rounded;
      case AiConnectionState.unknown:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        14,
        widget.compact ? 10 : 12,
        10,
        widget.compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBase,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: _accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _status.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: widget.compact ? 16 : 18,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  _status.detail,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: widget.compact ? 12 : 13,
                        color: AppColors.textMuted,
                      ),
                ),
              ],
            ),
          ),
          if (widget.showCheckButton) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: _checking ? null : _runCheck,
              child: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Check'),
            ),
          ],
        ],
      ),
    );
  }
}

class AiSourceChip extends StatelessWidget {
  const AiSourceChip({required this.isLiveAi, super.key});

  final bool isLiveAi;

  @override
  Widget build(BuildContext context) {
    final color = isLiveAi ? const Color(0xFF7DCEA0) : const Color(0xFFE6B84F);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLiveAi ? Icons.auto_awesome : Icons.offline_bolt_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            isLiveAi ? 'Live AI reading' : 'Offline demo reading',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
          ),
        ],
      ),
    );
  }
}
