import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/team_chat_service_v16.dart';

const _gold = Color(0xFFE5BE6B);

class TeamChatScreenV16 extends StatefulWidget {
  const TeamChatScreenV16({super.key});
  @override
  State<TeamChatScreenV16> createState() => _TeamChatScreenV16State();
}

class _TeamChatScreenV16State extends State<TeamChatScreenV16> {
  final service = TeamChatServiceV16.shared;
  List<Map<String, dynamic>> threads = [];
  VoidCallback? stop;
  bool busy = false, more = true, manage = false;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    stop = service.watch(() => unawaited(load()));
    unawaited(load());
  }

  @override
  void dispose() {
    stop?.call();
    super.dispose();
  }

  Future<void> load({bool older = false}) async {
    final token = ++generation;
    if (mounted) setState(() => busy = true);
    try {
      final canManage = await service.client.rpc(
        'v16_has_permission',
        params: {'p_permission': 'chat.manage'},
      );
      final rows = await service.inbox(
        before: older && threads.isNotEmpty
            ? threads.last['created_at'] as String
            : null,
      );
      if (!mounted || token != generation) return;
      setState(() {
        threads = older ? [...threads, ...rows] : rows;
        more = rows.length == 30;
        error = null;
        manage = canManage == true;
      });
    } catch (_) {
      if (mounted && token == generation) {
        setState(() {
          threads = [];
          error = 'تعذر تحميل المحادثات. تحقق من الاتصال وصلاحيتك.';
        });
      }
    } finally {
      if (mounted && token == generation) setState(() => busy = false);
    }
  }

  Future<void> create() async {
    try {
      final people = await service.directory();
      if (!mounted) return;
      final result = await showDialog<String>(
        context: context,
        builder: (_) =>
            _NewThread(service: service, people: people, manage: manage),
      );
      if (result != null) {
        await load();
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => TeamConversationScreenV16(
              threadId: result,
              title: 'محادثة الفريق',
            ),
          ),
        );
        await load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحميل قائمة الفريق أو إنشاء المحادثة. تأكد من تطبيق SQL الخاص بمحادثات موظف التحقق.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('محادثات الفريق'),
        actions: [
          IconButton(
            onPressed: busy ? null : () => load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _gold,
        onPressed: create,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('محادثة جديدة'),
      ),
      body: Column(
        children: [
          if (busy) const LinearProgressIndicator(color: _gold),
          if (error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(error!)),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => load(),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  if (threads.isEmpty && !busy && error == null)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'ابدأ محادثة آمنة مع فريقك',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final t in threads)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _gold.withValues(alpha: .2),
                        child: Icon(
                          t['is_group'] == true
                              ? Icons.groups
                              : Icons.person_outline,
                        ),
                      ),
                      title: Text('${t['title']}'),
                      subtitle: Text(
                        t['is_group'] == true ? 'مجموعة الفريق' : 'محادثة خاصة',
                      ),
                      trailing: (t['unread'] as num) > 0
                          ? Badge(label: Text('${t['unread']}'))
                          : null,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => TeamConversationScreenV16(
                              threadId: t['id'] as String,
                              title: t['title'] as String,
                              isGroup: t['is_group'] == true,
                              canManage: manage,
                            ),
                          ),
                        );
                        await load();
                      },
                    ),
                  if (more && threads.isNotEmpty)
                    TextButton(
                      onPressed: busy ? null : () => load(older: true),
                      child: const Text('محادثات أقدم'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NewThread extends StatefulWidget {
  const _NewThread({
    required this.service,
    required this.people,
    required this.manage,
  });
  final TeamChatServiceV16 service;
  final List<Map<String, dynamic>> people;
  final bool manage;
  @override
  State<_NewThread> createState() => _NewThreadState();
}

class _NewThreadState extends State<_NewThread> {
  final title = TextEditingController();
  final selected = <String>{};
  bool group = false, busy = false;
  String? error;
  String filter = '';
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AlertDialog(
      title: const Text('محادثة جديدة'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اختر شخصًا لمحادثة خاصة، أو فعّل «مجموعة» وحدد أعضاء الفريق.'),
              const SizedBox(height: 12),
              if (widget.manage)
                SwitchListTile(
                  title: const Text('مجموعة'),
                  value: group,
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                          group = v;
                          selected.clear();
                        }),
                ),
              if (group)
                TextField(
                  controller: title,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'اسم المجموعة'),
                ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'ابحث عن موظف',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => filter = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 10),
              if (!widget.people.any((p) => p['user_id'] != widget.service.client.auth.currentUser?.id))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('لا يوجد أعضاء متاحون حاليًا. يجب أن يكون الموظف نشطًا ومربوطًا بحسابه، وأن تكون محادثات الفريق مفعلة من السيرفر.'),
                ),
              for (final p in widget.people)
                if (p['user_id'] != widget.service.client.auth.currentUser?.id &&
                    '${p['name'] ?? ''}'.toLowerCase().contains(filter))
                  CheckboxListTile(
                    title: Text('${p['name']}'),
                    value: selected.contains(p['user_id']),
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            if (!group) selected.clear();
                            if (v == true) {
                              selected.add(p['user_id'] as String);
                            } else {
                              selected.remove(p['user_id']);
                            }
                          }),
                  ),
              if (error != null) Text(error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: busy || selected.isEmpty
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    final label = group
                        ? title.text.trim()
                        : widget.people.firstWhere(
                                (p) => selected.contains(p['user_id']),
                              )['name']
                              as String;
                    if (label.isEmpty) throw StateError('title');
                    final id = await widget.service.create(
                      label,
                      selected.toList(),
                      group,
                    );
                    if (context.mounted) Navigator.pop(context, id);
                  } catch (_) {
                    if (mounted) {
                      setState(() {
                        busy = false;
                        error =
                            'تعذر الإنشاء. أدخل اسمًا وتحقق من صلاحيات الأعضاء.';
                      });
                    }
                  }
                },
          child: Text(busy ? 'جارٍ الإنشاء…' : 'إنشاء'),
        ),
      ],
    ),
  );
}

class TeamConversationScreenV16 extends StatefulWidget {
  const TeamConversationScreenV16({
    super.key,
    required this.threadId,
    required this.title,
    this.isGroup = false,
    this.canManage = false,
  });
  final String threadId, title;
  final bool isGroup, canManage;
  @override
  State<TeamConversationScreenV16> createState() =>
      _TeamConversationScreenV16State();
}

class _TeamConversationScreenV16State extends State<TeamConversationScreenV16> {
  final service = TeamChatServiceV16.shared;
  final composer = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  final pending = <TeamPendingMessageV16>[];
  final names = <String, String>{};
  VoidCallback? stop;
  bool busy = false, more = true;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    stop = service.watch(() => unawaited(load()));
    unawaited(load());
    unawaited(loadNames());
  }

  Future<void> loadNames() async {
    try {
      final people = await service.directory();
      if (mounted) {
        setState(() {
          for (final p in people) {
            names[p['user_id'] as String] = p['name'] as String;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    stop?.call();
    composer.dispose();
    super.dispose();
  }

  Future<void> load({bool older = false}) async {
    final token = ++generation;
    if (mounted) setState(() => busy = true);
    try {
      final rows = await service.history(
        widget.threadId,
        before: older && messages.isNotEmpty
            ? (messages.last['id'] as num).toInt()
            : null,
      );
      if (!mounted || generation != token) return;
      setState(() {
        messages = older ? [...messages, ...rows] : rows;
        more = rows.length == 40;
        error = null;
        pending.removeWhere((p) => rows.any((m) => m['client_key'] == p.key));
      });
      if (!older && rows.isNotEmpty) {
        await service.read(widget.threadId, (rows.first['id'] as num).toInt());
      }
    } catch (_) {
      if (mounted && token == generation) {
        setState(() {
          messages = [];
          error = 'تعذر تحميل المحادثة أو تم سحب صلاحية الوصول.';
        });
      }
    } finally {
      if (mounted && token == generation) setState(() => busy = false);
    }
  }

  Future<void> send(TeamPendingMessageV16 message) async {
    if (message.sending) return;
    setState(() {
      message.sending = true;
      message.failed = false;
    });
    try {
      await service.send(widget.threadId, message.key, message.body);
      if (mounted) {
        setState(() => pending.remove(message));
        await load();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          message.sending = false;
          message.failed = true;
        });
      }
    }
  }

  Future<void> members() async {
    try {
      final people = await service.directory();
      final current = await service.members(widget.threadId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          final selected = current.map((m) => m['user_id']).toSet();
          bool saving = false;
          String? problem;
          return StatefulBuilder(
            builder: (context, setDialog) => Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('إدارة أعضاء المجموعة'),
                content: SizedBox(
                  width: 380,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final p in people)
                          if (p['user_id'] !=
                              service.client.auth.currentUser?.id)
                            CheckboxListTile(
                              title: Text('${p['name']}'),
                              value: selected.contains(p['user_id']),
                              onChanged: saving
                                  ? null
                                  : (v) async {
                                      setDialog(() => saving = true);
                                      try {
                                        await service.memberSet(
                                          widget.threadId,
                                          p['user_id'] as String,
                                          v == true,
                                        );
                                        setDialog(() {
                                          if (v == true) {
                                            selected.add(p['user_id']);
                                          } else {
                                            selected.remove(p['user_id']);
                                          }
                                          problem = null;
                                        });
                                      } catch (_) {
                                        setDialog(
                                          () => problem = 'تعذر تحديث العضو',
                                        );
                                      } finally {
                                        setDialog(() => saving = false);
                                      }
                                    },
                            ),
                        if (problem != null) Text(problem!),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    child: const Text('تم'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر تحميل الأعضاء')));
      }
    }
  }

  Widget bubble(
    String body, {
    required bool mine,
    String? sender,
    Widget? footer,
  }) => Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 340),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: mine
            ? _gold.withValues(alpha: .23)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sender != null)
            Text(
              sender,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          Text(body),
          if (footer != null) footer,
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.isGroup && widget.canManage)
            IconButton(
              onPressed: members,
              icon: const Icon(Icons.group_add_outlined),
            ),
          IconButton(onPressed: () => load(), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (busy) const LinearProgressIndicator(color: _gold),
            if (error != null)
              Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
            Expanded(
              child: ListView(
                reverse: true,
                children: [
                  for (final p in pending.reversed)
                    bubble(
                      p.body,
                      mine: true,
                      footer: p.failed
                          ? TextButton.icon(
                              onPressed: () => send(p),
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('فشل الإرسال · إعادة المحاولة'),
                            )
                          : const Text(
                              'جارٍ الإرسال…',
                              style: TextStyle(fontSize: 11),
                            ),
                    ),
                  for (final m in messages)
                    bubble(
                      '${m['body']}',
                      mine:
                          m['sender_id'] == service.client.auth.currentUser?.id,
                      sender: names[m['sender_id']] ?? 'عضو الفريق',
                    ),
                  if (more && messages.isNotEmpty)
                    TextButton(
                      onPressed: busy ? null : () => load(older: true),
                      child: const Text('تحميل الرسائل السابقة'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: composer,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 4000,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالة…',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () {
                      final text = composer.text.trim();
                      if (text.isEmpty) return;
                      final p = TeamPendingMessageV16(text);
                      setState(() => pending.add(p));
                      composer.clear();
                      unawaited(send(p));
                    },
                    icon: const Icon(Icons.send),
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

class TeamNotificationCenterV16 extends StatefulWidget {
  const TeamNotificationCenterV16({super.key});
  @override
  State<TeamNotificationCenterV16> createState() =>
      _TeamNotificationCenterV16State();
}

class _TeamNotificationCenterV16State extends State<TeamNotificationCenterV16> {
  final service = TeamChatServiceV16.shared;
  List<Map<String, dynamic>> rows = [];
  VoidCallback? stop;
  bool busy = false, more = true;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    stop = service.watch(() => unawaited(load()));
    unawaited(load());
  }

  @override
  void dispose() {
    stop?.call();
    super.dispose();
  }

  Future<void> load({bool older = false}) async {
    final token = ++generation;
    setState(() => busy = true);
    try {
      final result = await service.notifications(
        before: older && rows.isNotEmpty
            ? (rows.last['id'] as num).toInt()
            : null,
      );
      if (mounted && token == generation) {
        setState(() {
          rows = older ? [...rows, ...result] : result;
          more = result.length == 40;
          error = null;
        });
      }
    } catch (_) {
      if (mounted && token == generation) {
        setState(() {
          rows = [];
          error = 'تعذر تحميل الإشعارات. تحقق من الاتصال والصلاحيات.';
        });
      }
    } finally {
      if (mounted && token == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('إشعارات الفريق'),
        actions: [
          IconButton(onPressed: () => load(), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          if (busy) const LinearProgressIndicator(color: _gold),
          if (error != null) Text(error!),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => load(),
              child: ListView(
                children: [
                  if (rows.isEmpty && !busy)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'لا توجد إشعارات',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final n in rows)
                    ListTile(
                      leading: Icon(
                        n['read_at'] == null
                            ? Icons.mark_chat_unread_outlined
                            : Icons.done_all,
                        color: _gold,
                      ),
                      title: Text('${n['title']}'),
                      subtitle: Text('${n['created_at']}'),
                      onTap: () async {
                        try {
                          await service.notificationRead(
                            (n['id'] as num).toInt(),
                          );
                          if (!context.mounted) return;
                          if (n['thread_id'] != null) {
                            await Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => TeamConversationScreenV16(
                                  threadId: n['thread_id'] as String,
                                  title: 'محادثة الفريق',
                                ),
                              ),
                            );
                          }
                          if (mounted) await load();
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تعذر فتح الإشعار')),
                            );
                          }
                        }
                      },
                    ),
                  if (more && rows.isNotEmpty)
                    TextButton(
                      onPressed: busy ? null : () => load(older: true),
                      child: const Text('إشعارات أقدم'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
