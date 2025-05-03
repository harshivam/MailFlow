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

// Add this new event class
class UnifiedInboxToggleEvent {
  final bool isEnabled;
  UnifiedInboxToggleEvent(this.isEnabled);
}

// Add the UnsubscribeCompletedEvent to the existing event_bus.dart file

class UnsubscribeCompletedEvent {
  final String emailId;
  final bool success;

  UnsubscribeCompletedEvent(this.emailId, this.success);
}

// Add this class

class UnsubscribeStartedEvent {
  final String emailId;

  UnsubscribeStartedEvent(this.emailId);
}

// Add this new event class

class ShowToastEvent {
  final String message;

  ShowToastEvent(this.message);
}

// Add these event classes

// For tracking unsubscribe progress
class BatchProgressEvent {
  final double progress;
  final int completed;
  final int total;

  BatchProgressEvent(this.progress, this.completed, this.total);
}

// For notifying when a batch is complete
class BatchCompletedEvent {
  final int total;
  final int succeeded;

  BatchCompletedEvent(this.total, this.succeeded);
}
