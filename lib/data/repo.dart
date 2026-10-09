import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'format.dart';
import 'models.dart';

SupabaseClient get sb => Supabase.instance.client;
String get uid => sb.auth.currentUser!.id;

/// Bumped after every write so open screens reload their data.
final dataVersion = ValueNotifier<int>(0);
void dataChanged() => dataVersion.value++;

const _vehicleJoin = '*, vehicle:vehicles(*)';

class Repo {
  // ── profile ──
  static Future<Profile> profile() async =>
      Profile.fromJson(await sb.from('profiles').select().eq('id', uid).single());

  static Future<void> updateProfile(Map<String, dynamic> values) async {
    await sb.from('profiles').update(values).eq('id', uid);
    dataChanged();
  }

  // ── vehicles ──
  static Future<List<Vehicle>> vehicles() async =>
      (await sb.from('vehicles').select().order('created_at')).map(Vehicle.fromJson).toList();

  static Future<Vehicle?> vehicle(String id) async {
    final r = await sb.from('vehicles').select().eq('id', id).maybeSingle();
    return r == null ? null : Vehicle.fromJson(r);
  }

  static Future<String> saveVehicle(String? id, Map<String, dynamic> values) async {
    if (id == null) {
      final r = await sb.from('vehicles').insert(values).select('id').single();
      dataChanged();
      return r['id'] as String;
    }
    await sb.from('vehicles').update(values).eq('id', id);
    dataChanged();
    return id;
  }

  static Future<void> updateMileage(String id, int mileage) async {
    await sb.from('vehicles').update({'mileage': mileage, 'mileage_updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
    dataChanged();
  }

  static Future<void> deleteVehicle(Vehicle v) async {
    await sb.from('vehicles').delete().eq('id', v.id);
    if (v.photoPath != null) await removeFile(v.photoPath!);
    dataChanged();
  }

  // ── maintenance ──
  static Future<List<MaintenanceTask>> tasks({String? vehicleId}) async {
    var q = sb.from('maintenance_tasks').select(_vehicleJoin);
    if (vehicleId != null) q = q.eq('vehicle_id', vehicleId);
    return (await q).map(MaintenanceTask.fromJson).toList();
  }

  static Future<MaintenanceTask?> task(String id) async {
    final r = await sb.from('maintenance_tasks').select(_vehicleJoin).eq('id', id).maybeSingle();
    return r == null ? null : MaintenanceTask.fromJson(r);
  }

  static Future<void> saveTask(String? id, Map<String, dynamic> values) async {
    if (id == null) {
      await sb.from('maintenance_tasks').insert(values);
    } else {
      await sb.from('maintenance_tasks').update(values).eq('id', id);
    }
    dataChanged();
  }

  static Future<void> deleteTask(String id) async {
    await sb.from('maintenance_tasks').delete().eq('id', id);
    dataChanged();
  }

  static Future<void> completeTask(String taskId,
      {required DateTime performedAt, int? mileage, double? cost, String? shop, String? notes}) async {
    await sb.rpc('complete_maintenance_task', params: {
      'p_task_id': taskId,
      'p_performed_at': isoDate(performedAt),
      'p_mileage': mileage,
      'p_cost': cost,
      'p_shop': shop,
      'p_notes': notes,
    });
    dataChanged();
  }

  static Future<List<MaintenanceLog>> logs({String? vehicleId, int limit = 100}) async {
    var q = sb.from('maintenance_logs').select(_vehicleJoin);
    if (vehicleId != null) q = q.eq('vehicle_id', vehicleId);
    return (await q.order('performed_at', ascending: false).limit(limit)).map(MaintenanceLog.fromJson).toList();
  }

  static Future<void> addLog(Map<String, dynamic> values, {Vehicle? vehicle}) async {
    await sb.from('maintenance_logs').insert(values);
    final m = values['mileage'] as int?;
    if (vehicle != null && m != null && m > vehicle.mileage) await updateMileage(vehicle.id, m);
    dataChanged();
  }

  static Future<void> deleteLog(String id) async {
    await sb.from('maintenance_logs').delete().eq('id', id);
    dataChanged();
  }

  // ── documents ──
  static Future<List<CarDocument>> documents({String? vehicleId}) async {
    var q = sb.from('documents').select(_vehicleJoin);
    if (vehicleId != null) q = q.eq('vehicle_id', vehicleId);
    return (await q.order('expires_at', ascending: true, nullsFirst: false)).map(CarDocument.fromJson).toList();
  }

  static Future<CarDocument?> document(String id) async {
    final r = await sb.from('documents').select(_vehicleJoin).eq('id', id).maybeSingle();
    return r == null ? null : CarDocument.fromJson(r);
  }

  static Future<String> saveDocument(String? id, Map<String, dynamic> values, {String? replacedFile}) async {
    String docId;
    if (id == null) {
      docId = (await sb.from('documents').insert(values).select('id').single())['id'] as String;
    } else {
      await sb.from('documents').update(values).eq('id', id);
      docId = id;
    }
    if (replacedFile != null) await removeFile(replacedFile);
    dataChanged();
    return docId;
  }

  static Future<void> deleteDocument(CarDocument d) async {
    await sb.from('documents').delete().eq('id', d.id);
    if (d.filePath != null) await removeFile(d.filePath!);
    dataChanged();
  }

  // ── notifications ──
  static Future<List<AppNotification>> notifications() async =>
      (await sb.from('notifications').select().order('created_at', ascending: false).limit(100))
          .map(AppNotification.fromJson)
          .toList();

  static Future<int> unreadCount() async =>
      (await sb.from('notifications').select('id').isFilter('read_at', null).count(CountOption.exact)).count;

  static Future<void> markRead(String id) async {
    await sb.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
    dataChanged();
  }

  static Future<void> markAllRead() async {
    await sb.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).isFilter('read_at', null);
    dataChanged();
  }

  static Future<void> clearRead() async {
    await sb.from('notifications').delete().not('read_at', 'is', null);
    dataChanged();
  }

  // ── AI chats ──
  static Future<List<DiagnosisChat>> chats() async =>
      (await sb.from('diagnosis_chats').select(_vehicleJoin).order('updated_at', ascending: false).limit(50))
          .map(DiagnosisChat.fromJson)
          .toList();

  static Future<DiagnosisChat?> chat(String id) async {
    final r = await sb.from('diagnosis_chats').select(_vehicleJoin).eq('id', id).maybeSingle();
    return r == null ? null : DiagnosisChat.fromJson(r);
  }

  static Future<List<ChatMessage>> messages(String chatId) async =>
      (await sb.from('diagnosis_messages').select().eq('chat_id', chatId).order('created_at'))
          .map(ChatMessage.fromJson)
          .toList();

  static Future<void> deleteChat(String id) async {
    final msgs = await messages(id);
    await sb.from('diagnosis_chats').delete().eq('id', id);
    final paths = [for (final m in msgs) for (final a in m.attachments) a.path];
    if (paths.isNotEmpty) await sb.storage.from('files').remove(paths);
    dataChanged();
  }

  // ── files ──
  static String safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return cleaned.length > 80 ? cleaned.substring(cleaned.length - 80) : cleaned;
  }

  static Future<String> uploadFile(String folder, String name, Uint8List bytes, String contentType) async {
    final path = '$uid/$folder/${DateTime.now().millisecondsSinceEpoch}-${safeName(name)}';
    await sb.storage.from('files').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType, upsert: false));
    return path;
  }

  static Future<void> removeFile(String path) async {
    try {
      await sb.storage.from('files').remove([path]);
    } catch (e) {
      debugPrint('remove file failed: $e');
    }
  }

  static final _urlCache = <String, (String, DateTime)>{};

  /// Short-lived signed URL for a private file (cached for 50 minutes).
  static Future<String> fileUrl(String path, {bool download = false}) async {
    final key = '$path|$download';
    final hit = _urlCache[key];
    if (hit != null && hit.$2.isAfter(DateTime.now())) return hit.$1;
    final url = await sb.storage.from('files').createSignedUrl(path, 3600, download: download ? DownloadBehavior.withOriginalName : null);
    _urlCache[key] = (url, DateTime.now().add(const Duration(minutes: 50)));
    return url;
  }
}
