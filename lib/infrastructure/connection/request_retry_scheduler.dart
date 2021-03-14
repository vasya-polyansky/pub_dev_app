import 'dart:async';

import 'package:pub_dev_app/domain/connection/connection_status.dart';
import 'package:pub_dev_app/domain/connection/i_connection_repository.dart';
import 'package:pub_dev_app/domain/connection/i_request_retry_scheduler.dart';

class RequestRetryScheduler implements IRequestRetryScheduler {
  final IConnectionRepository _connectionRepository;

  const RequestRetryScheduler(this._connectionRepository);

  @override
  Future<T> scheduleRequestRetry<T>(Future<T> Function() retryRequest) {
    late final StreamSubscription subscription;
    final responseCompleter = Completer<T>();

    subscription = _connectionRepository.onConnectionStatusChanged.listen((status) {
      if (status == ConnectionStatus.connected) {
        responseCompleter.complete(retryRequest());
        subscription.cancel();
      }
    });

    return responseCompleter.future;
  }
}