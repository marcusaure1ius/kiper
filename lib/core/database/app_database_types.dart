// Re-export Drift-generated data classes so that code generators
// (e.g. riverpod_generator) can resolve these types without
// depending on part-of files.
export 'app_database.dart'
    show
        AppDatabase,
        Category,
        CategoriesCompanion,
        Subscription,
        SubscriptionsCompanion,
        ExchangeRate,
        ExchangeRatesCompanion;
