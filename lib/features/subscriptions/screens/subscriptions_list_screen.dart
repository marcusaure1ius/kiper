// lib/features/subscriptions/screens/subscriptions_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kiper/features/subscriptions/providers/subscriptions_provider.dart';
import 'package:kiper/features/subscriptions/widgets/subscription_card.dart';
import 'package:kiper/features/subscriptions/widgets/total_header.dart';
import 'package:kiper/features/subscriptions/widgets/category_filter_chips.dart';

class SubscriptionsListScreen extends ConsumerStatefulWidget {
  const SubscriptionsListScreen({super.key});

  @override
  ConsumerState<SubscriptionsListScreen> createState() => _SubscriptionsListScreenState();
}

class _SubscriptionsListScreenState extends ConsumerState<SubscriptionsListScreen> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final subscriptionsAsync = ref.watch(watchVisibleSubscriptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Подписки'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/subscriptions/add'),
        child: const Icon(Icons.add),
      ),
      body: subscriptionsAsync.when(
        data: (allSubs) {
          final filtered = _selectedCategoryId == null
              ? allSubs
              : allSubs.where((s) => s.categoryId == _selectedCategoryId).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: TotalHeader(subscriptions: allSubs),
              ),
              SliverToBoxAdapter(
                child: CategoryFilterChips(
                  selectedCategoryId: _selectedCategoryId,
                  onCategorySelected: (id) => setState(() => _selectedCategoryId = id),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text('Нет подписок'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final sub = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SubscriptionCard(
                            subscription: sub,
                            onTap: () => context.push('/subscriptions/${sub.id}'),
                          ),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Ошибка: $error')),
      ),
    );
  }
}
