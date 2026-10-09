import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'vehicles_list.dart';

const fuelTypes = ['Petrol', 'Diesel', 'Hybrid', 'Plug-in hybrid', 'Electric', 'LPG / CNG', 'Other'];

class VehicleFormScreen extends StatelessWidget {
  const VehicleFormScreen({super.key, this.id, this.welcome = false});
  final String? id;
  final bool welcome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(id == null ? 'Add a vehicle' : 'Edit vehicle')),
      body: Loader<(Profile, Vehicle?)>(
        load: () async => (await Repo.profile(), id == null ? null : await Repo.vehicle(id!)),
        builder: (context, d, _) => _VehicleForm(profile: d.$1, vehicle: d.$2, welcome: welcome),
      ),
    );
  }
}

class _VehicleForm extends StatefulWidget {
  const _VehicleForm({required this.profile, this.vehicle, required this.welcome});
  final Profile profile;
  final Vehicle? vehicle;
  final bool welcome;

  @override
  State<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<_VehicleForm> {
  late final v = widget.vehicle;
  late final _make = TextEditingController(text: v?.make ?? '');
  late final _model = TextEditingController(text: v?.model ?? '');
  late final _year = TextEditingController(text: v?.year.toString() ?? '');
  late final _nickname = TextEditingController(text: v?.nickname ?? '');
  late final _trim = TextEditingController(text: v?.trim ?? '');
  late final _color = TextEditingController(text: v?.color ?? '');
  late final _plate = TextEditingController(text: v?.plate ?? '');
  late final _vin = TextEditingController(text: v?.vin ?? '');
  late final _mileage = TextEditingController(text: v?.mileage.toString() ?? '');
  late String? _fuel = v?.fuelType;
  Uint8List? _photo;
  String _photoName = 'car.jpg';
  bool _removePhoto = false;
  bool _busy = false;

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final f = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      setState(() {
        _photo = bytes;
        _photoName = f.name;
        _removePhoto = false;
      });
    } catch (e) {
      if (mounted) toast(context, 'Could not open photos: ${friendlyError(e)}');
    }
  }

  String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final year = int.tryParse(_year.text.trim());
    final nextYear = DateTime.now().year + 1;
    if (_t(_make) == null || _t(_model) == null) return toast(context, 'Make and model are required.');
    if (year == null || year < 1900 || year > nextYear) return toast(context, 'Enter a year between 1900 and $nextYear.');
    final mileage = int.tryParse(_mileage.text.trim().replaceAll(',', '')) ?? 0;
    if (mileage < 0) return toast(context, 'Odometer cannot be negative.');

    setState(() => _busy = true);
    try {
      String? photoPath = v?.photoPath;
      String? oldPhoto;
      if (_photo != null) {
        final ext = _photoName.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
        photoPath = await Repo.uploadFile('vehicles', _photoName, _photo!, 'image/$ext');
        oldPhoto = v?.photoPath;
      } else if (_removePhoto) {
        oldPhoto = v?.photoPath;
        photoPath = null;
      }
      final values = <String, dynamic>{
        'make': _t(_make),
        'model': _t(_model),
        'year': year,
        'nickname': _t(_nickname),
        'trim': _t(_trim),
        'color': _t(_color),
        'plate': _t(_plate)?.toUpperCase(),
        'vin': _t(_vin)?.toUpperCase(),
        'fuel_type': _fuel,
        'photo_path': photoPath,
      };
      if (v == null || mileage != v!.mileage) {
        values['mileage'] = mileage;
        values['mileage_updated_at'] = DateTime.now().toUtc().toIso8601String();
      }
      final id = await Repo.saveVehicle(v?.id, values);
      if (oldPhoto != null) await Repo.removeFile(oldPhoto);
      if (!mounted) return;
      toast(context, v == null ? 'Vehicle added.' : 'Vehicle saved.');
      if (v == null) {
        context.pushReplacement('/vehicles/$id');
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _photoPreview() {
    Widget child;
    if (_photo != null) {
      child = Image.memory(_photo!, fit: BoxFit.cover);
    } else if (v != null && !_removePhoto && v!.photoPath != null) {
      child = VehiclePhoto(v!);
    } else {
      child = Container(
        color: AppColors.butter100,
        alignment: Alignment.center,
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add_a_photo_outlined, size: 36, color: AppColors.brown600),
          SizedBox(height: 6),
          Text('Add a photo (optional)', style: TextStyle(color: AppColors.brown600)),
        ]),
      );
    }
    final hasPhoto = _photo != null || (v?.photoPath != null && !_removePhoto);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: InkWell(onTap: () => _pickPhoto(ImageSource.gallery), child: child),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(onPressed: () => _pickPhoto(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined, size: 18), label: const Text('Choose photo')),
        OutlinedButton.icon(onPressed: () => _pickPhoto(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined, size: 18), label: const Text('Camera')),
        if (hasPhoto)
          TextButton(onPressed: () => setState(() { _photo = null; _removePhoto = true; }), child: const Text('Remove')),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    final unit = widget.profile.distanceUnit;
    return PageBody(maxWidth: 720, children: [
      if (widget.welcome) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.butter100, borderRadius: BorderRadius.circular(16)),
          child: const Text("Welcome to AUTOX! Let's add your first car. Only make, model and year are required.",
              style: TextStyle(color: AppColors.espresso)),
        ),
        gap,
      ],
      _photoPreview(),
      const SizedBox(height: 20),
      ResponsiveGrid(columns: 3, breakpoint: 600, children: [
        TextField(controller: _make, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Make *', hintText: 'Toyota')),
        TextField(controller: _model, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Model *', hintText: 'Corolla')),
        TextField(controller: _year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Year *', hintText: '2018')),
      ]),
      gap,
      ResponsiveGrid(children: [
        TextField(controller: _nickname, decoration: const InputDecoration(labelText: 'Nickname', hintText: 'Daily driver')),
        TextField(controller: _mileage, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Current odometer ($unit)')),
      ]),
      gap,
      ResponsiveGrid(columns: 3, breakpoint: 600, children: [
        TextField(controller: _trim, decoration: const InputDecoration(labelText: 'Trim', hintText: 'LE')),
        TextField(controller: _color, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Colour')),
        DropdownButtonFormField<String>(
          initialValue: fuelTypes.contains(_fuel) ? _fuel : null,
          decoration: const InputDecoration(labelText: 'Fuel'),
          items: [for (final f in fuelTypes) DropdownMenuItem(value: f, child: Text(f))],
          onChanged: (f) => setState(() => _fuel = f),
        ),
      ]),
      gap,
      ResponsiveGrid(children: [
        TextField(controller: _plate, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Plate number')),
        TextField(controller: _vin, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'VIN')),
      ]),
      const SizedBox(height: 22),
      FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : (v == null ? 'Add vehicle' : 'Save changes'))),
    ]);
  }
}
