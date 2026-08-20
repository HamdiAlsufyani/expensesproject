import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A shared invalidation counter. Repositories increment it after successful
/// mutations; dependent providers watch its state and refresh their SQL queries.
class DataChangeNotifier extends Notifier<int> {
  @override
  int build() => 0;

  int get revision => state;

  void notifyDataChanged() {
    state++;
  }
}
