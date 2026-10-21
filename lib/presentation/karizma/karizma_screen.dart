import '../../l10n/strings.dart';
import '../../services/karizma_backend.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

/// Social news UI V33. Server verifies authorship, audience and rate limits.
/// All financial/captain data is deliberately outside this widget.
class KarizmaScreen extends StatefulWidget {
  final KarizmaBackend? backend;
  final String audience;
  final bool visible;
  final VoidCallback? onMenu;
  const KarizmaScreen({
    super.key,
    required this.audience,
    this.visible = true,
    this.backend,
    this.onMenu,
  });

  @override
  State<KarizmaScreen> createState() => _KarizmaScreenState();
}

class _KarizmaScreenState extends State<KarizmaScreen> {
  late final KarizmaBackend _api;
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;
  String? _reactingId;
  StreamSubscription<String?>? _auth;
  int _readRevision = 0;
  BuildContext? _nicknameDialog;
  String? _account;

  @override
  void initState() {
    super.initState();
    _api = widget.backend ?? KarizmaBackend();
    _account = _api.accountId;
    _api.customerOpen.addListener(_onOpen);
    _auth = _api.accountChanges.listen((id) {
      if (!mounted || id == _account) return;
      _account = id;
      _readRevision++;
      setState(() {
        _posts = [];
        _reactingId = null;
        _error = null;
        _loading = false;
      });
      final dialog = _nicknameDialog;
      _nicknameDialog = null;
      if (dialog != null && dialog.mounted) Navigator.of(dialog).pop();
      if (widget.visible && _api.accountId != null) unawaited(_load());
    });
    if (widget.visible) _load();
  }

  void _onOpen() {
    if (widget.visible && widget.audience == 'customer') _load();
  }

  @override
  void didUpdateWidget(covariant KarizmaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audience != widget.audience) {
      _readRevision++;
      setState(() => _posts = []);
      if (widget.visible) _load();
    } else if (!oldWidget.visible && widget.visible)
      _load();
  }

  @override
  void dispose() {
    _readRevision++;
    _auth?.cancel();
    _api.customerOpen.removeListener(_onOpen);
    super.dispose();
  }

  Future<void> _load({bool markRead = true}) async {
    final owner = _api.accountId;
    final revision = ++_readRevision;
    bool current() =>
        mounted && owner == _api.accountId && revision == _readRevision;
    try {
      final result = await _api.posts(widget.audience);
      if (!current()) return;
      if (markRead && result.isNotEmpty) {
        DateTime latest = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
        for (final r in result) {
          final d = DateTime.tryParse('${r['created_at'] ?? ''}');
          if (d != null && d.isAfter(latest)) latest = d;
        }
        try {
          await _api.markSeen(widget.audience, latest);
        } catch (_) {
          /* Read receipt is never required to read posts. */
        }
      }
      if (!current()) return;
      setState(() {
        _posts = result;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (current())
        setState(() {
          _loading = false;
          _error = context.strings.newsLoadFailed;
        });
    }
  }

  Future<void> _react(Map<String, dynamic> post, int value) async {
    final owner = _api.accountId;
    if (owner == null) return;
    final id = '${post['id'] ?? ''}';
    if (id.isEmpty || _reactingId != null) return;
    setState(() => _reactingId = id);
    try {
      await _api.react(id, widget.audience, value);
      if (!mounted || owner != _api.accountId) return;
      await _load(markRead: false);
    } catch (_) {
      if (mounted && owner == _api.accountId)
        _message(context.strings.newsReactionFailed);
    } finally {
      if (mounted && owner == _api.accountId)
        setState(() => _reactingId = null);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message, style: TextStyle())));
  }

  Future<void> _chooseNickname() async {
    final owner = _api.accountId;
    if (owner == null) return;
    try {
      final value = await _api.nickname();
      if (!mounted || owner != _api.accountId) return;
      final next = await showDialog<String>(
        context: context,
        builder: (ctx) {
          _nicknameDialog = ctx;
          return NewsNicknameEditor(initialValue: value ?? '');
        },
      );
      _nicknameDialog = null;
      if (next == null || !mounted || owner != _api.accountId) return;
      await _api.saveNickname(next);
      if (mounted && owner == _api.accountId)
        _message(context.strings.newsNicknameSaved);
    } catch (_) {
      if (mounted && owner == _api.accountId)
        _message(context.strings.newsNicknameFailed);
    } finally {
      _nicknameDialog = null;
    }
  }

  Future<void> _showComments(Map<String, dynamic> post) async {
    final id = '${post['id'] ?? ''}';
    if (id.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _KarizmaCommentsSheet(
        postId: id,
        audience: widget.audience,
        backend: _api,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: Directionality.of(context),
    child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: widget.onMenu == null
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
                onPressed: widget.onMenu,
                icon: const Icon(Icons.menu_rounded),
              ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          context.strings.newsTitle,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: context.strings.newsDisplayName,
            onPressed: _chooseNickname,
            icon: Icon(Icons.person_outline_rounded, color: AppTheme.gold),
          ),
          IconButton(
            tooltip: context.strings.newsRefresh,
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded, color: AppTheme.gold),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : _error != null && _posts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  TextButton(
                    onPressed: _load,
                    child: Text(context.strings.newsRetry),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.gold,
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(12, 10, 12, 24),
                itemCount: _posts.isEmpty ? 1 : _posts.length,
                separatorBuilder: (_, __) => SizedBox(height: 12),
                itemBuilder: (_, i) {
                  if (_posts.isEmpty)
                    return Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Center(
                        child: Text(
                          context.strings.newsEmpty,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  final post = _posts[i];
                  final reaction = (post['my_reaction'] as num?)?.toInt() ?? 0;
                  return _KarizmaPostCard(
                    post: post,
                    reaction: reaction,
                    busy: _reactingId == '${post['id']}',
                    onLike: () => _react(post, 1),
                    onDislike: () => _react(post, -1),
                    onComments: () => _showComments(post),
                  );
                },
              ),
            ),
    ),
  );
}

class _KarizmaPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final int reaction;
  final bool busy;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onComments;
  const _KarizmaPostCard({
    required this.post,
    required this.reaction,
    required this.busy,
    required this.onLike,
    required this.onDislike,
    required this.onComments,
  });

  @override
  Widget build(BuildContext context) {
    final rawImage = '${post['image_url'] ?? ''}'.trim();
    // Support either an absolute public URL or a path in the existing bucket.
    final uri = Uri.tryParse(rawImage);
    final image =
        uri?.hasScheme == true &&
            (uri!.scheme == 'https' || uri.scheme == 'http')
        ? rawImage
        : rawImage.isNotEmpty
        ? SupabaseService.instance.client.storage
              .from(
                rawImage.startsWith('karizma/')
                    ? 'veto-karizma-images'
                    : 'veto-public',
              )
              .getPublicUrl(rawImage)
        : '';
    final likes = (post['likes'] as num?)?.toInt() ?? 0;
    final dislikes = (post['dislikes'] as num?)?.toInt() ?? 0;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF2A3650)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainer,
                  backgroundImage: AssetImage(
                    'assets/images/veto_sanya_app_icon.png',
                  ),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VETO SANYA',
                        style: TextStyle(
                          color: AppTheme.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        context.strings.newsCommunity,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.verified_rounded, color: AppTheme.gold, size: 18),
              ],
            ),
          ),
          if (image.isNotEmpty)
            InkWell(
              onTap: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => Dialog(
                  backgroundColor: Color(0xFF080C14),
                  insetPadding: EdgeInsets.all(10),
                  child: Stack(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: MediaQuery.sizeOf(context).height * .78,
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 5,
                          child: Image.network(image, fit: BoxFit.contain),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: Icon(
                            Icons.close,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  image,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      context.strings.newsImageUnavailable,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${post['title'] ?? ''}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '${post['body'] ?? ''}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Color(0xFF2A3650), height: 18),
          Wrap(
            alignment: WrapAlignment.spaceAround,
            children: [
              TextButton.icon(
                onPressed: busy ? null : onLike,
                icon: Icon(
                  reaction == 1
                      ? Icons.thumb_up_alt_rounded
                      : Icons.thumb_up_alt_outlined,
                  size: 18,
                  color: reaction == 1
                      ? AppTheme.gold
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                label: Text(context.strings.newsLikes('$likes')),
              ),
              TextButton.icon(
                onPressed: busy ? null : onDislike,
                icon: Icon(Icons.thumb_down_alt_outlined, size: 17),
                label: Text('$dislikes'),
              ),
              TextButton.icon(
                onPressed: onComments,
                icon: Icon(Icons.mode_comment_outlined, size: 19),
                label: Text(context.strings.newsComments),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KarizmaCommentsSheet extends StatefulWidget {
  final KarizmaBackend backend;
  final String postId;
  final String audience;
  const _KarizmaCommentsSheet({
    required this.postId,
    required this.audience,
    required this.backend,
  });
  @override
  State<_KarizmaCommentsSheet> createState() => _KarizmaCommentsSheetState();
}

class _KarizmaCommentsSheetState extends State<_KarizmaCommentsSheet> {
  KarizmaBackend get _api => widget.backend;
  String? _owner;
  StreamSubscription<String?>? _auth;
  int _revision = 0;
  bool get _current =>
      mounted && !_dismissed && _owner != null && _owner == _api.accountId;
  bool _dismissed = false;
  final _entry = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _saving = false;
  bool _useNickname = false;
  String? _error;
  Timer? _commentRefresh;
  @override
  void initState() {
    super.initState();
    _owner = _api.accountId;
    _auth = _api.accountChanges.listen((id) {
      if (!mounted || _dismissed || id == _owner) return;
      _dismissed = true;
      _revision++;
      _commentRefresh?.cancel();
      _entry.clear();
      setState(() => _comments = []);
      Navigator.of(context).pop();
    });
    _reload();
    // Read-only fallback for viewers without Realtime permission on private rows.
    _commentRefresh = Timer.periodic(Duration(seconds: 15), (_) {
      if (mounted && !_saving) _reload();
    });
  }

  @override
  void dispose() {
    _revision++;
    _auth?.cancel();
    _commentRefresh?.cancel();
    _entry.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (!_current) return;
    final revision = ++_revision;
    try {
      final items = await _api.comments(widget.postId, widget.audience);
      if (_current && revision == _revision)
        setState(() {
          _comments = items;
          _loading = false;
          _error = null;
        });
    } catch (_) {
      if (_current && revision == _revision)
        setState(() {
          _loading = false;
          _error = context.strings.newsCommentsFailed;
        });
    }
  }

  Future<void> _send() async {
    if (!_current || _saving || _entry.text.trim().isEmpty) return;
    final text = _entry.text.trim();
    setState(() => _saving = true);
    try {
      await _api.addComment(widget.postId, widget.audience, text, _useNickname);
      if (!_current) return;
      if (_entry.text.trim() == text) _entry.clear();
      await _reload();
    } catch (_) {
      if (_current) setState(() => _error = context.strings.newsCommentFailed);
    } finally {
      if (_current) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(15),
              child: Text(
                context.strings.newsComments,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.orangeAccent),
                ),
              ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (_, i) {
                          final x = _comments[i];
                          final frame = '${x['frame_key'] ?? ''}';
                          final photo = '${x['photo_url'] ?? ''}';
                          return ListTile(
                            leading: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: frame.isNotEmpty
                                      ? AppTheme.gold
                                      : Color(0xFF39455C),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainer,
                                backgroundImage: photo.startsWith('https://')
                                    ? NetworkImage(photo)
                                    : null,
                                child: photo.isEmpty
                                    ? Icon(
                                        Icons.person_rounded,
                                        color: AppTheme.gold,
                                      )
                                    : null,
                              ),
                            ),
                            title: Text(
                              '${x['display_name'] ?? context.strings.newsMember}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              '${x['body'] ?? ''}',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
              title: Text(
                context.strings.newsUseNickname,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              value: _useNickname,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _useNickname = v ?? false),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _entry,
                      maxLength: 350,
                      minLines: 1,
                      maxLines: 3,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: context.strings.newsWriteComment,
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : _send,
                    tooltip: context.strings.newsPostComment,
                    icon: Icon(Icons.send_rounded, color: AppTheme.gold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class NewsNicknameEditor extends StatefulWidget {
  final String initialValue;
  const NewsNicknameEditor({super.key, required this.initialValue});
  @override
  State<NewsNicknameEditor> createState() => _NewsNicknameEditorState();
}

class _NewsNicknameEditorState extends State<NewsNicknameEditor> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.strings.newsNicknameTitle),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.strings.newsNicknameHint),
        TextField(
          controller: _controller,
          maxLength: 30,
          decoration: InputDecoration(
            hintText: context.strings.newsNicknameExample,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.strings.newsCancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: Text(context.strings.newsSaveNickname),
      ),
    ],
  );
}
