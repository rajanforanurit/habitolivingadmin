import 'package:flutter/foundation.dart';

import '../models/json.dart';
import '../services/api_client.dart';

/// The four states a screen's data can be in.
enum LoadState { idle, loading, loaded, error }

/// A generic async data holder for a screen or a list.
///
/// Every screen in the app shows one of four things: a skeleton while loading,
/// content when loaded, an empty state when there is nothing, and an error with
/// a retry when the call failed. [AsyncView] centralises that so no screen
/// reimplements it.
///
/// Subclass it for a specific screen (`class NoticesView extends AsyncView<List<Notice>>`)
/// or use it directly with [load].
class AsyncView<T> extends ChangeNotifier {
  AsyncView();

  late T _data;
  LoadState _state = LoadState.idle;
  String? _error;
  Future<T> Function()? _task;

  /// Called to fetch the data. Set by [load] and re-invoked on [refresh].
  set task(Future<T> Function() value) => _task = value;

  T get data => _data;
  LoadState get state => _state;
  String? get error => _error;
  bool get isLoading => _state == LoadState.loading;
  bool get isLoaded => _state == LoadState.loaded;
  bool get hasError => _state == LoadState.error;
  bool get isEmpty => _state == LoadState.loaded && _isEmpty(_data);

  /// Runs [task] and updates the state. Errors from the API are unwrapped into
  /// their user-facing message.
  Future<void> load([Future<T> Function()? task]) async {
    final t = task ?? _task;
    if (t == null) return;
    _task = t;
    _state = LoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _data = await t();
      _state = LoadState.loaded;
    } catch (e, st) {
      _state = LoadState.error;
      _error = _message(e);
      debugPrint('AsyncView failed: $e\n$st');
    }
    notifyListeners();
  }

  /// Re-runs the last task. Used by pull-to-refresh and retry buttons.
  Future<void> refresh() => load();

  /// Updates the data in place after a mutation (create, update, delete)
  /// without re-fetching.
  void update(T value) {
    _data = value;
    if (_state == LoadState.error) {
      _state = LoadState.loaded;
      _error = null;
    }
    notifyListeners();
  }

  /// Sets a local error without changing the loaded data, for a failed action
  /// on a screen that still has content.
  void setError(String message) {
    _error = message;
    _state = LoadState.error;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    if (_state == LoadState.error) _state = LoadState.loaded;
    notifyListeners();
  }

  static String _message(Object error) {
    if (error is ApiException) return error.message;
    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('TimeoutException')) {
      return 'Cannot reach the server. Check that the backend is running and '
          'that the port is forwarded (adb reverse tcp:4000 tcp:4000).';
    }
    return text.replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), '');
  }

  static bool _isEmpty(dynamic data) {
    if (data == null) return true;
    if (data is List) return data.isEmpty;
    if (data is String) return data.isEmpty;
    if (data is PageResult) return data.items.isEmpty;
    return false;
  }
}

/// A paged list view with load-more.
///
/// Wraps [AsyncView] for the common case of a paginated backend list: first page
/// on load, next page on demand, and a guard against double-fetching.
class PagedView<T> extends AsyncView<PageResult<T>> {
  PagedView({this.pageSize = 20});

  final int pageSize;
  bool _loadingMore = false;
  bool get isLoadingMore => _loadingMore;

  /// Loads the first page, replacing what is there.
  Future<void> loadFirst(
    Future<PageResult<T>> Function(int page, int limit) fetch,
  ) {
    task = () => fetch(1, pageSize);
    return load();
  }

  /// Appends the next page. Returns false when there is nothing more.
  Future<bool> loadMore(
    Future<PageResult<T>> Function(int page, int limit) fetch,
  ) async {
    if (_loadingMore) return false;
    final current = data;
    final next = current.nextPage;
    if (next == null) return false;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await fetch(next, pageSize);
      update(
        PageResult<T>(
          items: [...current.items, ...page.items],
          page: page.page,
          limit: page.limit,
          total: page.total,
          totalPages: page.totalPages,
        ),
      );
      return true;
    } catch (e) {
      setError(AsyncView._message(e));
      return false;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }
}
