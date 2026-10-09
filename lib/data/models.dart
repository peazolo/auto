import 'format.dart';

int? _int(dynamic v) => v == null ? null : (v as num).toInt();
double? _dbl(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

class Profile {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final bool emailReminders;
  final String distanceUnit; // km | mi
  final String currency;

  Profile.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'] ?? '',
        email = j['email'],
        phone = j['phone'],
        emailReminders = j['email_reminders'] ?? true,
        distanceUnit = j['distance_unit'] ?? 'km',
        currency = j['currency'] ?? 'USD';

  String get firstName => name.trim().isEmpty ? 'there' : name.trim().split(' ').first;
}

class Vehicle {
  final String id;
  final String? nickname;
  final String make;
  final String model;
  final int year;
  final String? trim, color, vin, plate, fuelType, photoPath;
  final int mileage;
  final DateTime mileageUpdatedAt;

  Vehicle.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        nickname = j['nickname'],
        make = j['make'],
        model = j['model'],
        year = _int(j['year'])!,
        trim = j['trim'],
        color = j['color'],
        vin = j['vin'],
        plate = j['plate'],
        fuelType = j['fuel_type'],
        photoPath = j['photo_path'],
        mileage = _int(j['mileage']) ?? 0,
        mileageUpdatedAt = parseDate(j['mileage_updated_at']) ?? DateTime.now();

  String get name => (nickname?.trim().isNotEmpty ?? false) ? nickname!.trim() : '$year $make $model';
  String get fullName => '$year $make $model';
}

enum DueStatus { overdue, dueSoon, ok, unscheduled }

class MaintenanceTask {
  final String id;
  final String vehicleId;
  final String name;
  final String category;
  final int? intervalDays, intervalMileage, lastDoneMileage, nextDueMileage;
  final DateTime? lastDoneAt, nextDueAt;
  final int remindDaysBefore, remindMileageBefore;
  final String? notes;
  final Vehicle? vehicle;

  MaintenanceTask.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        vehicleId = j['vehicle_id'],
        name = j['name'],
        category = j['category'] ?? 'General',
        intervalDays = _int(j['interval_days']),
        intervalMileage = _int(j['interval_mileage']),
        lastDoneMileage = _int(j['last_done_mileage']),
        nextDueMileage = _int(j['next_due_mileage']),
        lastDoneAt = parseDate(j['last_done_at']),
        nextDueAt = parseDate(j['next_due_at']),
        remindDaysBefore = _int(j['remind_days_before']) ?? 7,
        remindMileageBefore = _int(j['remind_mileage_before']) ?? 500,
        notes = j['notes'],
        vehicle = j['vehicle'] == null ? null : Vehicle.fromJson(j['vehicle']);

  DueStatus status(int currentMileage) {
    if (nextDueAt == null && nextDueMileage == null) return DueStatus.unscheduled;
    var overdue = false, soon = false;
    if (nextDueAt != null) {
      final d = daysUntil(nextDueAt!);
      if (d <= 0) {
        overdue = true;
      } else if (d <= remindDaysBefore) {
        soon = true;
      }
    }
    if (nextDueMileage != null) {
      if (currentMileage >= nextDueMileage!) {
        overdue = true;
      } else if (nextDueMileage! - currentMileage <= remindMileageBefore) {
        soon = true;
      }
    }
    return overdue ? DueStatus.overdue : (soon ? DueStatus.dueSoon : DueStatus.ok);
  }
}

class MaintenanceLog {
  final String id;
  final String vehicleId;
  final String title;
  final DateTime performedAt;
  final int? mileage;
  final double? cost;
  final String? shop, notes;
  final Vehicle? vehicle;

  MaintenanceLog.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        vehicleId = j['vehicle_id'],
        title = j['title'],
        performedAt = parseDate(j['performed_at'])!,
        mileage = _int(j['mileage']),
        cost = _dbl(j['cost']),
        shop = j['shop'],
        notes = j['notes'],
        vehicle = j['vehicle'] == null ? null : Vehicle.fromJson(j['vehicle']);
}

enum DocStatus { expired, expiring, valid, noExpiry }

const documentTypes = <String, String>{
  'drivers_license': "Driver's license",
  'insurance': 'Insurance',
  'registration': 'Vehicle registration / licence',
  'roadworthiness': 'Roadworthiness certificate',
  'inspection': 'Inspection / MOT',
  'emissions': 'Emissions test',
  'permit': 'Permit',
  'warranty': 'Warranty',
  'receipt': 'Receipt / invoice',
  'other': 'Other',
};

class CarDocument {
  final String id;
  final String? vehicleId;
  final String type, title;
  final String? number, issuer, filePath, fileName, fileType, notes;
  final DateTime? issuedAt, expiresAt;
  final int remindDaysBefore;
  final int? fileSize;
  final Vehicle? vehicle;

  CarDocument.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        vehicleId = j['vehicle_id'],
        type = j['type'] ?? 'other',
        title = j['title'],
        number = j['number'],
        issuer = j['issuer'],
        filePath = j['file_path'],
        fileName = j['file_name'],
        fileType = j['file_type'],
        fileSize = _int(j['file_size']),
        notes = j['notes'],
        issuedAt = parseDate(j['issued_at']),
        expiresAt = parseDate(j['expires_at']),
        remindDaysBefore = _int(j['remind_days_before']) ?? 30,
        vehicle = j['vehicle'] == null ? null : Vehicle.fromJson(j['vehicle']);

  String get typeLabel => documentTypes[type] ?? 'Document';
  bool get isImage => fileType?.startsWith('image/') ?? false;
  bool get isPdf => fileType == 'application/pdf';

  DocStatus get status {
    if (expiresAt == null) return DocStatus.noExpiry;
    final d = daysUntil(expiresAt!);
    if (d <= 0) return DocStatus.expired;
    if (d <= remindDaysBefore) return DocStatus.expiring;
    return DocStatus.valid;
  }
}

class AppNotification {
  final String id, kind, title, body;
  final String? link;
  final DateTime? readAt;
  final DateTime createdAt;

  AppNotification.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        kind = j['kind'],
        title = j['title'],
        body = j['body'],
        link = j['link'],
        readAt = parseDate(j['read_at']),
        createdAt = parseDate(j['created_at'])!;
}

class Attachment {
  final String path;
  final String kind; // image | video-frame
  final String? name;
  const Attachment(this.path, this.kind, [this.name]);
  Attachment.fromJson(Map<String, dynamic> j) : path = j['path'], kind = j['kind'] ?? 'image', name = j['name'];
  Map<String, dynamic> toJson() => {'path': path, 'kind': kind, if (name != null) 'name': name};
}

class DiagnosisChat {
  final String id, title;
  final String? vehicleId;
  final DateTime updatedAt;
  final Vehicle? vehicle;
  DiagnosisChat.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        title = j['title'],
        vehicleId = j['vehicle_id'],
        updatedAt = parseDate(j['updated_at'])!,
        vehicle = j['vehicle'] == null ? null : Vehicle.fromJson(j['vehicle']);
}

class ChatMessage {
  final String id;
  final String role;
  String content;
  final List<Attachment> attachments;
  ChatMessage({required this.id, required this.role, required this.content, this.attachments = const []});
  ChatMessage.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        role = j['role'],
        content = j['content'] ?? '',
        attachments = ((j['attachments'] as List?) ?? []).map((a) => Attachment.fromJson(Map<String, dynamic>.from(a))).toList();
}

/// Common services with sensible default intervals (km-based).
class Preset {
  final String name, category;
  final int? months, km;
  const Preset(this.name, this.category, this.months, this.km);
}

const maintenancePresets = [
  Preset('Engine oil & filter change', 'Engine', 6, 8000),
  Preset('Tire rotation', 'Tires', 6, 10000),
  Preset('Tire pressure check', 'Tires', 1, null),
  Preset('Wheel alignment', 'Tires', 12, 20000),
  Preset('Brake pads inspection', 'Brakes', 12, 20000),
  Preset('Brake fluid replacement', 'Brakes', 24, 40000),
  Preset('Air filter replacement', 'Engine', 12, 20000),
  Preset('Cabin air filter', 'Comfort', 12, 20000),
  Preset('Coolant flush', 'Cooling', 24, 50000),
  Preset('Spark plugs', 'Engine', 36, 50000),
  Preset('Transmission fluid', 'Drivetrain', 36, 60000),
  Preset('Battery check', 'Electrical', 6, null),
  Preset('Wiper blades', 'Visibility', 12, null),
  Preset('Timing belt', 'Engine', 60, 100000),
  Preset('AC service', 'Comfort', 12, null),
];

const maintenanceCategories = [
  'General', 'Engine', 'Tires', 'Brakes', 'Cooling', 'Electrical',
  'Drivetrain', 'Suspension', 'Comfort', 'Visibility', 'Body',
];
