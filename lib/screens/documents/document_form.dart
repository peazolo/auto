import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../maintenance/task_widgets.dart';

const _remindOptions = [3, 7, 14, 30, 45, 60, 90];
const _maxBytes = 25 * 1024 * 1024;
const _allowedExt = ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'];

class DocumentFormScreen extends StatelessWidget {
  const DocumentFormScreen({super.key, this.id, this.vehicleId});
  final String? id;
  final String? vehicleId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(id == null ? 'Add a document' : 'Edit document')),
      body: Loader<(List<Vehicle>, CarDocument?)>(
        load: () async => (await Repo.vehicles(), id == null ? null : await Repo.document(id!)),
        builder: (context, d, _) => _DocForm(vehicles: d.$1, doc: d.$2, vehicleId: vehicleId),
      ),
    );
  }
}

class _DocForm extends StatefulWidget {
  const _DocForm({required this.vehicles, this.doc, this.vehicleId});
  final List<Vehicle> vehicles;
  final CarDocument? doc;
  final String? vehicleId;

  @override
  State<_DocForm> createState() => _DocFormState();
}

class _DocFormState extends State<_DocForm> {
  late final doc = widget.doc;
  late String _type = doc?.type ?? 'insurance';
  late String? _vehicle = doc?.vehicleId ??
      (widget.vehicles.any((v) => v.id == widget.vehicleId)
          ? widget.vehicleId
          : (widget.vehicles.length == 1 ? widget.vehicles.first.id : null));
  late final _title = TextEditingController(text: doc?.title ?? '');
  late final _number = TextEditingController(text: doc?.number ?? '');
  late final _issuer = TextEditingController(text: doc?.issuer ?? '');
  late final _notes = TextEditingController(text: doc?.notes ?? '');
  late DateTime? _issued = doc?.issuedAt;
  late DateTime? _expires = doc?.expiresAt;
  late int _remind = doc?.remindDaysBefore ?? 30;
  Uint8List? _bytes;
  String? _fileName;
  String? _mime;
  bool _removeFile = false;
  bool _busy = false;

  void _setFile(Uint8List bytes, String name) {
    if (bytes.length > _maxBytes) return toast(context, 'That file is over 25 MB.');
    final ext = name.split('.').last.toLowerCase();
    if (!_allowedExt.contains(ext)) return toast(context, 'Use a PDF or an image (JPG, PNG, WEBP, HEIC).');
    setState(() {
      _bytes = bytes;
      _fileName = name;
      _mime = lookupMimeType(name, headerBytes: bytes.take(16).toList()) ?? (ext == 'pdf' ? 'application/pdf' : 'image/jpeg');
      if (_mime == 'image/jpg') _mime = 'image/jpeg';
      _removeFile = false;
      if (_title.text.trim().isEmpty) _title.text = documentTypes[_type] ?? '';
    });
  }

  Future<void> _pickFile() async {
    try {
      final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: _allowedExt);
      if (r.isEmpty) return;
      final f = r.first;
      final bytes = await f.xFile.readAsBytes();
      _setFile(bytes, f.name);
    } catch (e) {
      if (mounted) toast(context, 'Could not open the file: ${friendlyError(e)}');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2400, imageQuality: 88);
      if (f == null) return;
      _setFile(await f.readAsBytes(), f.name.contains('.') ? f.name : 'photo.jpg');
    } catch (e) {
      if (mounted) toast(context, 'Could not open the camera: ${friendlyError(e)}');
    }
  }

  String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final title = _t(_title) ?? documentTypes[_type]!;
    if (_issued != null && _expires != null && _expires!.isBefore(_issued!)) {
      return toast(context, 'The expiry date is before the issue date.');
    }
    setState(() => _busy = true);
    String? uploaded;
    try {
      final values = <String, dynamic>{
        'type': _type,
        'title': title,
        'vehicle_id': _vehicle,
        'number': _t(_number),
        'issuer': _t(_issuer),
        'notes': _t(_notes),
        'issued_at': isoDate(_issued),
        'expires_at': isoDate(_expires),
        'remind_days_before': _remind,
      };
      if (doc == null || !_sameDay(doc!.expiresAt, _expires) || doc!.remindDaysBefore != _remind) {
        values['last_notified_at'] = null;
      }
      String? replaced;
      if (_bytes != null) {
        uploaded = await Repo.uploadFile('documents', _fileName!, _bytes!, _mime!);
        values.addAll({'file_path': uploaded, 'file_name': _fileName, 'file_type': _mime, 'file_size': _bytes!.length});
        replaced = doc?.filePath;
      } else if (_removeFile && doc?.filePath != null) {
        values.addAll({'file_path': null, 'file_name': null, 'file_type': null, 'file_size': null});
        replaced = doc!.filePath;
      }
      final id = await Repo.saveDocument(doc?.id, values, replacedFile: replaced);
      if (!mounted) return;
      toast(context, doc == null ? 'Document saved.' : 'Changes saved.');
      if (doc == null) {
        context.pushReplacement('/documents/$id');
      } else {
        context.pop();
      }
    } catch (e) {
      if (uploaded != null) await Repo.removeFile(uploaded);
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _sameDay(DateTime? a, DateTime? b) => isoDate(a) == isoDate(b);

  Widget _fileBox() {
    final existing = doc?.filePath != null && !_removeFile && _bytes == null;
    final name = _fileName ?? (existing ? doc!.fileName : null);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.butter50,
        border: Border.all(color: AppColors.lineStrong),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_bytes != null && (_mime?.startsWith('image/') ?? false) && !(_mime!.contains('hei')))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_bytes!, height: 180, fit: BoxFit.cover)),
          ),
        Row(children: [
          Icon(name == null ? Icons.cloud_upload_outlined : Icons.insert_drive_file_outlined, color: AppColors.brown600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name ?? 'Attach a photo or PDF (max 25 MB)',
                style: TextStyle(fontWeight: name == null ? FontWeight.w400 : FontWeight.w600), overflow: TextOverflow.ellipsis),
          ),
          if (name != null)
            IconButton(
              tooltip: 'Remove file',
              onPressed: () => setState(() {
                _bytes = null;
                _fileName = null;
                _removeFile = true;
              }),
              icon: const Icon(Icons.close),
            ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.folder_open_outlined, size: 18), label: Text(name == null ? 'Choose file' : 'Replace')),
          OutlinedButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.photo_camera_outlined, size: 18), label: const Text('Scan with camera')),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    final remindOpts = {..._remindOptions, _remind}.toList()..sort();
    return PageBody(maxWidth: 720, children: [
      _fileBox(),
      const SizedBox(height: 20),
      ResponsiveGrid(children: [
        DropdownButtonFormField<String>(
          initialValue: _type,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Document type'),
          items: [for (final e in documentTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => _type = v!),
        ),
        DropdownButtonFormField<String?>(
          initialValue: _vehicle,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Vehicle'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Not vehicle-specific')),
            for (final v in widget.vehicles) DropdownMenuItem(value: v.id, child: Text(v.name)),
          ],
          onChanged: (v) => setState(() => _vehicle = v),
        ),
      ]),
      gap,
      TextField(controller: _title, decoration: InputDecoration(labelText: 'Title', hintText: documentTypes[_type])),
      gap,
      ResponsiveGrid(children: [
        TextField(controller: _number, decoration: const InputDecoration(labelText: 'Document / policy number')),
        TextField(controller: _issuer, decoration: const InputDecoration(labelText: 'Issued by', hintText: 'Insurer, agency…')),
      ]),
      gap,
      ResponsiveGrid(children: [
        DateField(label: 'Issued on', value: _issued, onChanged: (d) => setState(() => _issued = d)),
        DateField(label: 'Expires on', hint: 'Blank if it never expires', value: _expires, onChanged: (d) => setState(() => _expires = d)),
      ]),
      gap,
      DropdownButtonFormField<int>(
        initialValue: _remind,
        decoration: InputDecoration(
          labelText: 'Remind me before it expires',
          helperText: _expires == null ? 'Set an expiry date to get reminders' : 'Reminder on ${fmtDate(_expires!.subtract(Duration(days: _remind)))}',
        ),
        items: [
          for (final d in remindOpts)
            DropdownMenuItem(value: d, child: Text(d == 30 ? '1 month before' : (d == 60 ? '2 months before' : (d == 90 ? '3 months before' : '$d days before')))),
        ],
        onChanged: (v) => setState(() => _remind = v!),
      ),
      gap,
      TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
      const SizedBox(height: 22),
      FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : (doc == null ? 'Save document' : 'Save changes'))),
    ]);
  }
}
