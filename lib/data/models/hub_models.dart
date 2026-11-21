import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart' show Doc;

String _str(Object? v) => v is String ? v : '';
int _int(Object? v) => v is num ? v.toInt() : 0;
DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

/// One part or tool the team owns.
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.location,
    required this.notes,
    required this.borrowedById,
    required this.borrowedByName,
    this.borrowedAt,
  });

  final String id;
  final String name;
  final String category;
  final int quantity;
  final String location;
  final String notes;

  /// Empty while the item is in its place.
  final String borrowedById;
  final String borrowedByName;

  /// The server's clock at the moment it was taken.
  final DateTime? borrowedAt;

  bool get isOut => borrowedById.isNotEmpty;

  factory InventoryItem.fromDoc(Doc doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return InventoryItem(
      id: doc.id,
      name: _str(d['name']),
      category: _str(d['category']),
      quantity: _int(d['quantity']),
      location: _str(d['location']),
      notes: _str(d['notes']),
      borrowedById: _str(d['borrowedById']),
      borrowedByName: _str(d['borrowedByName']),
      borrowedAt: _date(d['borrowedAt']),
    );
  }
}

/// The editable part of an inventory item (the Add / Edit item form).
class InventoryDraft {
  const InventoryDraft({
    required this.name,
    required this.category,
    required this.quantity,
    required this.location,
    required this.notes,
  });

  final String name;
  final String category;
  final int quantity;
  final String location;
  final String notes;

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
    'quantity': quantity,
    'location': location,
    'notes': notes,
  };
}

const eventTypes = <(String, String)>[
  ('meeting', 'Meeting'),
  ('test', 'Test day'),
  ('deadline', 'Deadline'),
  ('other', 'Other'),
];

String eventTypeLabel(String key) => eventTypes
    .firstWhere((t) => t.$1 == key, orElse: () => eventTypes.last)
    .$2;

/// One entry in the team calendar.
class TeamEvent {
  const TeamEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.at,
    required this.location,
    required this.notes,
  });

  final String id;
  final String title;
  final String type;
  final DateTime at;
  final String location;
  final String notes;

  /// Whole days from today to the day of the event:
  /// 0 is today, 1 is tomorrow, negative means it has passed.
  int daysFrom(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    return (day.difference(today).inHours / 24).round();
  }

  factory TeamEvent.fromDoc(Doc doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return TeamEvent(
      id: doc.id,
      title: _str(d['title']),
      type: _str(d['type']),
      at: _date(d['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      location: _str(d['location']),
      notes: _str(d['notes']),
    );
  }
}

/// The editable part of a calendar entry.
class EventDraft {
  const EventDraft({
    required this.title,
    required this.type,
    required this.at,
    required this.location,
    required this.notes,
  });

  final String title;
  final String type;
  final DateTime at;
  final String location;
  final String notes;

  Map<String, dynamic> toMap() => {
    'title': title,
    'type': type,
    'at': Timestamp.fromDate(at),
    'location': location,
    'notes': notes,
  };
}
