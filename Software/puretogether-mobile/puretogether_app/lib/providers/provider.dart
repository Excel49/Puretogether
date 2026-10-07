import 'package:flutter/widgets.dart';

/// Clean native Flutter provider implementation using InheritedNotifier
class ChangeNotifierProvider<T extends ChangeNotifier> extends StatefulWidget {
  final T Function(BuildContext context) create;
  final Widget child;

  const ChangeNotifierProvider({
    super.key,
    required this.create,
    required this.child,
  });

  @override
  State<ChangeNotifierProvider<T>> createState() => _ChangeNotifierProviderState<T>();
}

class _ChangeNotifierProviderState<T extends ChangeNotifier>
    extends State<ChangeNotifierProvider<T>> {
  late final T _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = widget.create(context);
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ProviderScope<T>(
      notifier: _notifier,
      child: widget.child,
    );
  }
}

class _ProviderScope<T extends ChangeNotifier> extends InheritedNotifier<T> {
  const _ProviderScope({required T notifier, required super.child})
      : super(notifier: notifier);
}

class Consumer<T extends ChangeNotifier> extends StatelessWidget {
  final Widget Function(BuildContext context, T value, Widget? child) builder;
  final Widget? child;

  const Consumer({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ProviderScope<T>>();
    if (scope == null || scope.notifier == null) {
      throw FlutterError('Consumer<$T> could not find Provider<$T>');
    }
    return builder(context, scope.notifier!, child);
  }
}

extension ReadContextExtension on BuildContext {
  T read<T extends ChangeNotifier>() {
    final scope =
        getElementForInheritedWidgetOfExactType<_ProviderScope<T>>()?.widget
            as _ProviderScope<T>?;
    if (scope == null || scope.notifier == null) {
      throw FlutterError('read<$T> could not find Provider<$T>');
    }
    return scope.notifier!;
  }

  T watch<T extends ChangeNotifier>() {
    final scope = dependOnInheritedWidgetOfExactType<_ProviderScope<T>>();
    if (scope == null || scope.notifier == null) {
      throw FlutterError('watch<$T> could not find Provider<$T>');
    }
    return scope.notifier!;
  }
}
