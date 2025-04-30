import 'package:event_bus/event_bus.dart';

// Create a singleton event bus
EventBus eventBus = EventBus();

// Define events
class AccountRemovedEvent {
  final String accountId;
  AccountRemovedEvent(this.accountId);
}

class AccountAddedEvent {
  final String accountId;
  AccountAddedEvent(this.accountId);
}

class AccountSetDefaultEvent {
  final String accountId;
  AccountSetDefaultEvent(this.accountId);
}
