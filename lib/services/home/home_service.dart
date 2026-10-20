import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/home.dart';
import '../storage/storage_adapter.dart';
import '../storage/storage_adapter_factory.dart';

/// Abstract interface for multi-home domain operations in Lumivo.
abstract interface class HomeService {
  factory HomeService({
    List<Home>? initialHomes,
    StorageAdapter? storage,
  }) = DefaultHomeService;

  /// Returns the current list of homes.
  List<Home> getHomes();

  /// Returns the currently active home.
  Home getCurrentHome();

  /// Switches the active home to [homeId].
  void switchHome(String homeId);

  /// Creates a new home domain with the given parameters and adds it to the list.
  Future<Home> createHome(
    String name, {
    String address = '104 Lumivo Way',
    double tariffRate = 0.16,
    String currency = 'USD',
  });

  /// Updates an existing home domain.
  Future<void> updateHome(Home home);

  /// Deletes a home domain by [homeId].
  ///
  /// If the deleted home was the current home, automatically falls back
  /// to the default home or the first available home.
  Future<void> deleteHome(String homeId);

  /// Stream emitting the active [Home] whenever it changes.
  Stream<Home> get currentHomeStream;

  /// Stream emitting the updated list of homes whenever modified.
  Stream<List<Home>> get homesStream;

  /// Disposes internal streams and resources.
  void dispose();
}

/// Concrete implementation of [HomeService].
class DefaultHomeService implements HomeService {
  DefaultHomeService({
    List<Home>? initialHomes,
    StorageAdapter? storage,
  }) : _storage = storage {
    if (initialHomes != null && initialHomes.isNotEmpty) {
      _homes.addAll(initialHomes);
    } else {
      _homes.addAll(defaultInitialHomes);
    }

    // Ensure exactly one home is marked as current
    _ensureCurrentHomeSelection();
  }

  static const String storageKey = 'lumivo_multi_homes';

  static const Home defaultHome = Home(
    id: 'home-default',
    name: 'Lumivo Smart Villa',
    address: '104 Lumivo Way',
    role: 'Owner',
    isCurrent: true,
    tariffRate: 0.16,
    currency: 'USD',
  );

  static const Home defaultVacationHome = Home(
    id: 'home-vacation',
    name: 'Seaside Retreat',
    address: '42 Ocean Breeze Blvd',
    role: 'Owner',
    isCurrent: false,
    tariffRate: 0.22,
    currency: 'USD',
  );

  static List<Home> get defaultInitialHomes => [
        defaultHome,
        defaultVacationHome,
      ];

  final StorageAdapter? _storage;
  final List<Home> _homes = [];

  final StreamController<Home> _currentHomeController =
      StreamController<Home>.broadcast();
  final StreamController<List<Home>> _homesController =
      StreamController<List<Home>>.broadcast();

  @override
  Stream<Home> get currentHomeStream => _currentHomeController.stream;

  @override
  Stream<List<Home>> get homesStream => _homesController.stream;

  @override
  List<Home> getHomes() => List.unmodifiable(_homes);

  @override
  Home getCurrentHome() {
    _ensureCurrentHomeSelection();
    return _homes.firstWhere(
      (h) => h.isCurrent,
      orElse: () => _homes.first,
    );
  }

  @override
  void switchHome(String homeId) {
    final targetIndex = _homes.indexWhere((h) => h.id == homeId);
    if (targetIndex < 0) {
      throw ArgumentError('Home with id "$homeId" not found.');
    }

    final targetHome = _homes[targetIndex];
    if (targetHome.isCurrent) {
      return; // Already current
    }

    for (int i = 0; i < _homes.length; i++) {
      if (i == targetIndex) {
        _homes[i] = _homes[i].copyWith(isCurrent: true);
      } else if (_homes[i].isCurrent) {
        _homes[i] = _homes[i].copyWith(isCurrent: false);
      }
    }

    final updatedActive = _homes[targetIndex];
    _emitCurrentHome(updatedActive);
    _emitHomes();
    _saveToStorage();
  }

  @override
  Future<Home> createHome(
    String name, {
    String address = '104 Lumivo Way',
    double tariffRate = 0.16,
    String currency = 'USD',
  }) async {
    final id =
        'home-${DateTime.now().millisecondsSinceEpoch}-${_homes.length + 1}';
    final shouldBeCurrent = _homes.isEmpty;

    final newHome = Home(
      id: id,
      name: name,
      address: address,
      role: 'Owner',
      isCurrent: shouldBeCurrent,
      tariffRate: tariffRate,
      currency: currency,
      createdAt: DateTime.now(),
    );

    _homes.add(newHome);
    if (shouldBeCurrent) {
      _emitCurrentHome(newHome);
    }
    _emitHomes();
    await _saveToStorage();
    return newHome;
  }

  @override
  Future<void> updateHome(Home home) async {
    final index = _homes.indexWhere((h) => h.id == home.id);
    if (index < 0) {
      throw ArgumentError('Cannot update non-existent home id: ${home.id}');
    }

    final wasCurrent = _homes[index].isCurrent;
    _homes[index] = home;

    if (home.isCurrent) {
      for (int i = 0; i < _homes.length; i++) {
        if (i != index && _homes[i].isCurrent) {
          _homes[i] = _homes[i].copyWith(isCurrent: false);
        }
      }
      _emitCurrentHome(home);
    } else if (wasCurrent) {
      // If the current home was explicitly updated to isCurrent = false, fallback
      _ensureCurrentHomeSelection();
      _emitCurrentHome(getCurrentHome());
    }

    _emitHomes();
    await _saveToStorage();
  }

  @override
  Future<void> deleteHome(String homeId) async {
    final index = _homes.indexWhere((h) => h.id == homeId);
    if (index < 0) {
      return;
    }

    final wasCurrent = _homes[index].isCurrent;
    _homes.removeAt(index);

    if (wasCurrent) {
      // Automatically fallback to default home or first available home
      Home fallback;
      if (_homes.isEmpty) {
        fallback = defaultHome.copyWith(isCurrent: true);
        _homes.add(fallback);
      } else {
        final defaultIndex = _homes.indexWhere((h) => h.id == defaultHome.id);
        final targetIndex = defaultIndex >= 0 ? defaultIndex : 0;
        _homes[targetIndex] = _homes[targetIndex].copyWith(isCurrent: true);
        fallback = _homes[targetIndex];
      }
      _emitCurrentHome(fallback);
    }

    _emitHomes();
    await _saveToStorage();
  }

  void _ensureCurrentHomeSelection() {
    if (_homes.isEmpty) {
      _homes.add(defaultHome.copyWith(isCurrent: true));
      return;
    }

    final currentIndex = _homes.indexWhere((h) => h.isCurrent);
    if (currentIndex < 0) {
      _homes[0] = _homes[0].copyWith(isCurrent: true);
    } else {
      // Ensure only one home is marked current
      for (int i = 0; i < _homes.length; i++) {
        if (i != currentIndex && _homes[i].isCurrent) {
          _homes[i] = _homes[i].copyWith(isCurrent: false);
        }
      }
    }
  }

  void _emitCurrentHome(Home home) {
    if (!_currentHomeController.isClosed) {
      _currentHomeController.add(home);
    }
  }

  void _emitHomes() {
    if (!_homesController.isClosed) {
      _homesController.add(List.unmodifiable(_homes));
    }
  }

  Future<void> _saveToStorage() async {
    if (_storage == null) return;
    try {
      final jsonList = _homes.map((h) => h.toJson()).toList();
      await _storage.setString(storageKey, jsonEncode(jsonList));
    } catch (_) {}
  }

  @override
  void dispose() {
    _currentHomeController.close();
    _homesController.close();
  }
}

/// Riverpod provider for [HomeService].
final homeServiceProvider = Provider<HomeService>((ref) {
  final service = DefaultHomeService(
    storage: StorageAdapterFactory.create(),
  );
  ref.onDispose(() => service.dispose());
  return service;
});

/// Riverpod stream provider for current active [Home].
final currentHomeStreamProvider = StreamProvider<Home>((ref) {
  final service = ref.watch(homeServiceProvider);
  return Stream.value(service.getCurrentHome())
      .concatWith(service.currentHomeStream);
});

/// Riverpod stream provider for the list of homes.
final homesListStreamProvider = StreamProvider<List<Home>>((ref) {
  final service = ref.watch(homeServiceProvider);
  return Stream.value(service.getHomes()).concatWith(service.homesStream);
});

extension _StreamConcat<T> on Stream<T> {
  Stream<T> concatWith(Stream<T> other) async* {
    yield* this;
    yield* other;
  }
}
