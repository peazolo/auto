import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'frames.dart';
import 'stream_client.dart';

const _maxImages = 6;

const _suggestions = [
  'My check engine light just came on',
  'Squealing noise when I brake',
  "Car won't start, it just clicks",
  'White smoke from the exhaust',
  'Steering wheel shakes at high speed',
  'There is a puddle under my car',
];

class _Pending {
  _Pending(this.bytes, this.kind, this.name);
  final Uint8List bytes;
  final String kind; // image | video-frame
  final String name;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.chatId, this.vehicleId});
  final String? chatId;
  final String? vehicleId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late String? _chatId = widget.chatId;
  String? _vehicleId;
  String _title = 'New diagnosis';
  List<Vehicle> _vehicles = [];
  final List<ChatMessage> _messages = [];
  final List<_Pending> _pending = [];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = true;
  bool _sending = false;
  String? _status;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      _vehicles = await Repo.vehicles();
      if (_chatId != null) {
        final chat = await Repo.chat(_chatId!);
        if (chat == null) throw Exception('Conversation not found.');
        _title = chat.title;
        _vehicleId = chat.vehicleId;
        _messages
          ..clear()
          ..addAll(await Repo.messages(_chatId!));
      } else {
        _vehicleId = _vehicles.any((v) => v.id == widget.vehicleId)
            ? widget.vehicleId
            : (_vehicles.length == 1 ? _vehicles.first.id : null);
      }
    } catch (e) {
      _loadError = e;
    }
    if (mounted) setState(() => _loading = false);
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  int get _imageCount => _pending.length;

  Future<void> _addPhotos(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final files = source == ImageSource.camera
          ? [?await picker.pickImage(source: source, maxWidth: 1568, imageQuality: 85)]
          : await picker.pickMultiImage(maxWidth: 1568, imageQuality: 85, limit: _maxImages);
      for (final f in files) {
        if (_imageCount >= _maxImages) {
          if (mounted) toast(context, 'Up to $_maxImages images per message.');
          break;
        }
        final bytes = await f.readAsBytes();
        setState(() => _pending.add(_Pending(bytes, 'image', f.name)));
      }
    } catch (e) {
      if (mounted) toast(context, 'Could not open photos: ${friendlyError(e)}');
    }
  }

  Future<void> _addVideo(ImageSource source) async {
    try {
      final f = await ImagePicker().pickVideo(source: source, maxDuration: const Duration(seconds: 30));
      if (f == null) return;
      setState(() => _status = 'Reading video…');
      final room = _maxImages - _imageCount;
      if (room <= 0) {
        if (mounted) toast(context, 'Remove a photo to add a video.');
        return;
      }
      final frames = await extractFrames(f, count: room.clamp(1, 6));
      if (frames.isEmpty) throw Exception("Couldn't read frames from that video.");
      setState(() {
        for (var i = 0; i < frames.length; i++) {
          _pending.add(_Pending(frames[i], 'video-frame', 'frame-${i + 1}.jpg'));
        }
      });
      if (mounted) {
        toast(context, 'Added ${frames.length} frames from the video. Describe any sound you hear, since the AI sees frames, not audio.');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _status = null);
    }
  }

  void _attachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.paper,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () {
              Navigator.pop(ctx);
              _addPhotos(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose photos'),
            onTap: () {
              Navigator.pop(ctx);
              _addPhotos(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: const Text('Record a video'),
            subtitle: const Text('Up to 30 seconds'),
            onTap: () {
              Navigator.pop(ctx);
              _addVideo(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library_outlined),
            title: const Text('Choose a video'),
            onTap: () {
              Navigator.pop(ctx);
              _addVideo(ImageSource.gallery);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (_sending) return;
    if (text.isEmpty && _pending.isEmpty) return;
    final message = text.isEmpty ? 'What do you see? What could be wrong?' : text;

    setState(() {
      _sending = true;
      _status = _pending.isEmpty ? null : 'Uploading…';
    });
    final uploaded = <Attachment>[];
    try {
      for (final p in _pending) {
        final path = await Repo.uploadFile('diagnose', p.name, p.bytes, 'image/jpeg');
        uploaded.add(Attachment(path, p.kind, p.name));
      }
    } catch (e) {
      for (final a in uploaded) {
        await Repo.removeFile(a.path);
      }
      if (mounted) {
        toast(context, 'Upload failed: ${friendlyError(e)}');
        setState(() {
          _sending = false;
          _status = null;
        });
      }
      return;
    }

    final reply = ChatMessage(id: 'pending', role: 'assistant', content: '');
    setState(() {
      _messages.add(ChatMessage(id: 'local-${_messages.length}', role: 'user', content: message, attachments: uploaded));
      _messages.add(reply);
      _pending.clear();
      _input.clear();
      _status = 'Thinking…';
    });
    _toBottom();

    final client = makeStreamClient();
    try {
      var session = sb.auth.currentSession;
      if (session == null) throw Exception('Please sign in again.');
      if (session.isExpired) session = (await sb.auth.refreshSession()).session ?? session;

      final req = http.Request('POST', Uri.parse('${AppConfig.supabaseUrl}/functions/v1/diagnose'))
        ..headers.addAll({
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': AppConfig.supabaseAnonKey,
          'Content-Type': 'application/json',
        })
        ..body = jsonEncode({
          'chatId': _chatId,
          'vehicleId': _chatId == null ? _vehicleId : null,
          'message': message,
          'attachments': [for (final a in uploaded) a.toJson()],
        });
      final res = await client.send(req);
      if (res.statusCode != 200) {
        final body = await res.stream.bytesToString();
        String msg;
        try {
          msg = (jsonDecode(body) as Map)['error']?.toString() ?? 'The AI mechanic is unavailable right now.';
        } catch (_) {
          msg = res.statusCode == 404
              ? "The AI function isn't deployed yet."
              : 'The AI mechanic is unavailable right now (${res.statusCode}).';
        }
        throw _AiError(msg);
      }
      final newId = res.headers['x-chat-id'];
      if (_chatId == null && newId != null) {
        _chatId = newId;
        if (message.length > 3) _title = message.length > 60 ? '${message.substring(0, 57)}…' : message;
      }
      await for (final chunk in res.stream.transform(utf8.decoder)) {
        if (!mounted) break;
        setState(() {
          reply.content += chunk;
          _status = null;
        });
        _toBottom();
      }
      if (reply.content.trim().isEmpty) throw _AiError('No answer came back. Please try again.');
    } catch (e) {
      final msg = e is _AiError ? e.message : 'Connection problem: ${friendlyError(e)}';
      if (mounted) {
        setState(() {
          if (reply.content.trim().isEmpty) {
            _messages.remove(reply);
            final last = _messages.removeLast();
            _input.text = last.content;
            for (final a in last.attachments) {
              Repo.removeFile(a.path);
            }
          }
        });
        toast(context, msg);
      }
    } finally {
      client.close();
      if (mounted) {
        setState(() {
          _sending = false;
          _status = null;
        });
      }
      dataChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = _vehicles.where((v) => v.id == _vehicleId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (vehicle != null && _messages.isNotEmpty)
            Text(vehicle.name, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
        actions: [
          if (_chatId != null)
            IconButton(
              tooltip: 'Delete conversation',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirm(context, 'Delete this conversation?', 'Its messages and photos will be removed.')) return;
                try {
                  await Repo.deleteChat(_chatId!);
                  if (context.mounted) context.go('/diagnose');
                } catch (e) {
                  if (context.mounted) toast(context, friendlyError(e));
                }
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.caramel))
          : _loadError != null
              ? EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: "Couldn't load this conversation",
                  body: friendlyError(_loadError!),
                  action: FilledButton(onPressed: _load, child: const Text('Retry')),
                )
              : Column(children: [
                  Expanded(
                    child: _messages.isEmpty ? _intro() : _list(),
                  ),
                  _composer(),
                ]),
    );
  }

  Widget _intro() {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 12), children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.auto_awesome, size: 40, color: AppColors.caramel),
            const SizedBox(height: 10),
            Text('Tell me what’s going on', textAlign: TextAlign.center, style: display(26)),
            const SizedBox(height: 6),
            const Text(
              'Describe the symptom, when it happens, and anything you hear or smell. Add photos or a short video for a better read.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            if (_vehicles.isNotEmpty)
              DropdownButtonFormField<String?>(
                initialValue: _vehicleId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Which car?', prefixIcon: Icon(Icons.directions_car_outlined)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Not specific to one of my cars')),
                  for (final v in _vehicles) DropdownMenuItem(value: v.id, child: Text(v.name)),
                ],
                onChanged: (v) => setState(() => _vehicleId = v),
              ),
            const SizedBox(height: 18),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
              for (final s in _suggestions) ActionChip(label: Text(s), onPressed: _sending ? null : () => _send(s)),
            ]),
          ]),
        ),
      ),
    ]);
  }

  Widget _list() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      itemCount: _messages.length,
      itemBuilder: (context, i) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _Bubble(message: _messages[i], typing: _sending && i == _messages.length - 1, status: _status),
        ),
      ),
    );
  }

  Widget _composer() {
    return Material(
      color: AppColors.paper,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 788),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_pending.isNotEmpty)
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pending.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(_pending[i].bytes, width: 72, height: 72, fit: BoxFit.cover),
                        ),
                        if (_pending[i].kind == 'video-frame')
                          const Positioned(left: 4, bottom: 4, child: Icon(Icons.videocam, size: 16, color: Colors.white)),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: InkWell(
                            onTap: _sending ? null : () => setState(() => _pending.removeAt(i)),
                            child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                if (_status != null && !_sending)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(_status!, style: const TextStyle(color: AppColors.muted))),
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  IconButton(
                    tooltip: 'Add photo or video',
                    onPressed: _sending ? null : _attachMenu,
                    icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.brown600),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 4000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'Describe the problem…', counterText: '', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.butter50))
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiError implements Exception {
  _AiError(this.message);
  final String message;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.typing, this.status});
  final ChatMessage message;
  final bool typing;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final user = message.role == 'user';
    if (user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14, left: 48),
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppColors.espresso,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18), topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (message.attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: [
                  for (final a in message.attachments)
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: StorageImage(a.path, width: 84, height: 84)),
                ]),
              ),
            SelectableText(message.content, style: const TextStyle(color: AppColors.butter50, height: 1.4)),
          ]),
        ),
      );
    }
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14, right: 24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CircleAvatar(
          radius: 15,
          backgroundColor: AppColors.butter200,
          foregroundColor: AppColors.espresso,
          child: Icon(Icons.auto_awesome, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paper,
              border: Border.all(color: AppColors.line),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4), topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
            ),
            child: message.content.isEmpty && typing
                ? Row(children: [
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.caramel)),
                    const SizedBox(width: 10),
                    Text(status ?? 'Thinking…', style: const TextStyle(color: AppColors.muted)),
                  ])
                : MarkdownBody(
                    data: message.content,
                    selectable: true,
                    onTapLink: (_, href, _) {
                      if (href != null) launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
                    },
                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: const TextStyle(color: AppColors.ink, height: 1.5, fontSize: 15),
                      h1: display(22),
                      h2: display(19),
                      h3: display(17),
                      strong: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.espresso),
                      blockquoteDecoration: BoxDecoration(color: AppColors.butter100, borderRadius: BorderRadius.circular(8)),
                      code: const TextStyle(backgroundColor: AppColors.butter100, fontFamily: 'monospace'),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}
