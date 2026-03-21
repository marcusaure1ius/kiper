import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kiper/features/home/models/payment_event.dart';
import 'package:kiper/features/home/widgets/payment_operation_tile.dart';

class PaymentsSheet extends ConsumerStatefulWidget {
  final List<PaymentEvent> pastPayments;
  final List<PaymentEvent> futurePayments;

  const PaymentsSheet({
    super.key,
    required this.pastPayments,
    required this.futurePayments,
  });

  @override
  ConsumerState<PaymentsSheet> createState() => _PaymentsSheetState();
}

class _PaymentsSheetState extends ConsumerState<PaymentsSheet> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  bool _isExpanded = false;
  bool _showFuture = false;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetSizeChanged);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetSizeChanged);
    _sheetController.dispose();
    super.dispose();
  }

  void _onSheetSizeChanged() {
    final expanded = _sheetController.size > 0.5;
    if (expanded != _isExpanded) {
      setState(() {
        _isExpanded = expanded;
      });
    }
  }

  void _expandSheet() {
    _sheetController.animateTo(
      0.92,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  String _dayHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);

    if (day == today) return 'Сегодня';
    if (day == today.subtract(const Duration(days: 1))) return 'Вчера';
    if (day == today.add(const Duration(days: 1))) return 'Завтра';
    return DateFormat('d MMMM', 'ru').format(date);
  }

  Map<DateTime, List<PaymentEvent>> _groupByDay(List<PaymentEvent> payments) {
    final map = <DateTime, List<PaymentEvent>>{};
    for (final event in payments) {
      final day = DateTime(event.date.year, event.date.month, event.date.day);
      map.putIfAbsent(day, () => []).add(event);
    }
    return map;
  }

  List<Widget> _buildGroupedItems(List<PaymentEvent> payments, {required bool isPast}) {
    final grouped = _groupByDay(payments);
    final sortedDays = grouped.keys.toList()
      ..sort(isPast ? (a, b) => b.compareTo(a) : (a, b) => a.compareTo(b));

    final items = <Widget>[];
    for (final day in sortedDays) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(
            top: 16,
            bottom: 8,
            left: 20,
            right: 20,
          ),
          child: Text(
            _dayHeader(day),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
          ),
        ),
      );
      for (final event in grouped[day]!) {
        items.add(
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
            child: PaymentOperationTile(event: event),
          ),
        );
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      controller: _sheetController,
      minChildSize: 0.52,
      maxChildSize: 0.92,
      initialChildSize: 0.52,
      snap: true,
      snapSizes: const [0.52, 0.92],
      builder: (context, scrollController) {
        final payments =
            _isExpanded && _showFuture
                ? widget.futurePayments
                : widget.pastPayments;

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Платежи',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: _expandSheet,
                      child: Text(
                        'Посмотреть все',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Segmented button (expanded only)
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Прошлые')),
                      ButtonSegment(value: true, label: Text('Будущие')),
                    ],
                    selected: {_showFuture},
                    onSelectionChanged: (selected) {
                      setState(() {
                        _showFuture = selected.first;
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.white.withValues(alpha: 0.15);
                            }
                            return Colors.transparent;
                          }),
                      foregroundColor:
                          WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.white;
                            }
                            return Colors.white54;
                          }),
                      side: const WidgetStatePropertyAll(
                        BorderSide(color: Colors.white24),
                      ),
                    ),
                    showSelectedIcon: false,
                  ),
                ),
              ],

              // Grouped payment items
              ..._buildGroupedItems(payments, isPast: !_showFuture),
            ],
          ),
        );
      },
    );
  }
}
