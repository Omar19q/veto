import '../../l10n/strings.dart';
import '../../services/partner_portal_backend.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

/// Live partner reports; never exposes phone numbers of referred captains.
class PartnerPortalV39 extends StatefulWidget {
  final PartnerPortalBackend? backend;
  const PartnerPortalV39({super.key, this.backend});
  @override
  State<PartnerPortalV39> createState() => _PartnerPortalV39State();
}

class _PartnerPortalV39State extends State<PartnerPortalV39> {
  static const gold = Color(0xFFFFC426);
  Map<String, dynamic>? info;
  List<Map<String, dynamic>> monthly = const [];
  List<Map<String,dynamic>> teamMembers=const [];
  bool loading = true;
  bool saving = false;
  String? error;
  Timer? _timer;
  late final PartnerPortalBackend _backend;
  StreamSubscription<String?>? _auth;
  String? _owner;
  int _revision = 0;
  bool _invalidated = false;
  bool _refreshing = false;
  bool _monthlyUnavailable = false;
  BuildContext? _walletDialog;
  bool get _current =>
      mounted &&
      !_invalidated &&
      _owner != null &&
      _backend.accountId == _owner;

  @override
  void initState() {
    super.initState();
    _backend = widget.backend ?? PartnerPortalBackend();
    _owner = _backend.accountId;
    _auth = _backend.accountChanges.listen((id) {
      if (!mounted || id == _owner) return;
      _invalidated = true;
      _revision++;
      _timer?.cancel();
      setState(() {
        info = null;
        monthly = const [];
        teamMembers=const [];
        loading = false;
        error = context.strings.buildingSession;
      });
      final dialog = _walletDialog;
      if (dialog != null && dialog.mounted) Navigator.of(dialog).pop();
    });
    _refresh();
    // Read-only, bounded live refresh; no changes to OneSignal or realtime channels.
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _revision++;
    _auth?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!_current || _refreshing) return;
    _refreshing = true;
    final revision = ++_revision;
    bool current() => _current && revision == _revision;
    if (!silent && mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      final result = await _backend.report();
      if (!current()) return;
      List<Map<String, dynamic>> monthRows = const [];
      bool monthlyUnavailable = false;
      try {
        final resultMonths = await _backend.monthlyReport();
        if (resultMonths is List) {
          monthRows = resultMonths
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {
        monthlyUnavailable = true;
      }
      List<Map<String,dynamic>> roster=teamMembers;
      if(widget.backend==null) {
        try {
          final team=await SupabaseService.instance.client.rpc('v58_partner_my_team');
          if(team is Map) roster=(team['captains'] as List? ?? [])
              .whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
        } catch (_) {}
      }
      if (current()) {
        setState(() {
          teamMembers=roster;
          info = result is Map ? Map<String, dynamic>.from(result) : null;
          monthly = monthRows;
          _monthlyUnavailable = monthlyUnavailable;
          error = null;
        });
      }
    } catch (_) {
      if (current()) {
        setState(() => error = context.strings.partnerLoadFailed);
      }
    } finally {
      _refreshing = false;
      if (current() && !silent) setState(() => loading = false);
    }
  }

  Future<void> _editWallet() async {
    if (!_current || saving) return;
    try {
      final next = await showDialog<String>(
        context: context,
        builder: (ctx) {
          _walletDialog = ctx;
          return PartnerPayoutEditor(
            initialValue: info?['payout_wallet']?.toString() ?? '',
          );
        },
      );
      _walletDialog = null;
      if (next == null || !_current) return;
      setState(() => saving = true);
      await _backend.saveWallet(next.trim());
      if (!_current) return;
      await _refresh(silent: true);
    } catch (_) {
      if (_current)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.partnerWalletUnconfirmed)),
        );
    } finally {
      _walletDialog = null;
      if (_current) setState(() => saving = false);
    }
  }

  Widget _stat(String label, Object? value, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: gold),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: Directionality.of(context),
    child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.strings.partnerTitle),
        actions: [
          IconButton(
            onPressed: () => _refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: !_current
          ? Center(child: Text(context.strings.buildingSession))
          : loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!, textAlign: TextAlign.center))
          : info?['active'] != true
          ? Center(child: Text(context.strings.partnerInactive))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Icon(Icons.handshake_rounded, size: 55, color: gold),
                Text(
                  info?['name']?.toString() ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    title: Text(context.strings.partnerTeamCode),
                    subtitle: SelectableText(info?['code']?.toString() ?? ''),
                    leading: const Icon(Icons.qr_code_rounded, color: gold),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _stat(
                      context.strings.partnerCaptains,
                      info?['captains'] ?? 0,
                      Icons.groups,
                    ),
                    const SizedBox(width: 8),
                    _stat(
                      context.strings.partnerTrips,
                      info?['completed_trips'] ?? 0,
                      Icons.route,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _stat(
                      context.strings.partnerDue,
                      context.strings.moneyValue(
                        '${info?['pending_egp'] ?? 0}',
                      ),
                      Icons.account_balance_wallet,
                    ),
                    const SizedBox(width: 8),
                    _stat(
                      context.strings.partnerPaid,
                      context.strings.moneyValue('${info?['paid_egp'] ?? 0}'),
                      Icons.check_circle_outline,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(child:ExpansionTile(
                  leading:const Icon(Icons.groups_2_outlined,color:gold),
                  title:Text('كباتن الفريق • ${teamMembers.length}'),
                  subtitle:const Text('كود البادج مستقل عن كود الفريق'),
                  children:[
                    if(teamMembers.isEmpty)
                      const ListTile(title:Text('لا توجد أسماء مرتبطة بالفريق بعد')),
                    for(final captain in teamMembers)
                      ListTile(
                        title:Text(captain['name']?.toString()??'كابتن'),
                        subtitle:Text('كود البادج: ${captain['badge_code']??'غير مخصص'}'),
                        trailing:Text(captain['vehicle_type']?.toString()??''),
                      ),
                  ],
                )),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.percent_rounded, color: gold),
                    title: Text(
                      context.strings.partnerShare(
                        '${info?['share_percent'] ?? 3}',
                      ),
                    ),
                    subtitle: Text(
                      info?['share_enabled'] == true
                          ? context.strings.partnerSettledOnly
                          : context.strings.partnerCommissionDisabled,
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.payments_rounded, color: gold),
                    title: Text(context.strings.partnerPayoutWallet),
                    subtitle: Text(
                      info?['payout_wallet']?.toString().isNotEmpty == true
                          ? '${info?['payout_wallet']}'
                          : context.strings.partnerAddWallet,
                    ),
                    trailing: saving
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.edit_outlined),
                    onTap: saving ? null : _editWallet,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    context.strings.partnerSchedule,
                    textAlign: TextAlign.center,
                  ),
                ),
                Text(
                  context.strings.partnerTeam,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                for (final raw in (info?['team'] as List? ?? const []))
                  if (raw is Map)
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.directions_car),
                        ),
                        title: Text(
                          raw['name']?.toString() ??
                              context.strings.partnerCaptain,
                        ),
                        subtitle: Text(
                          context.strings.partnerTeamRides(
                            raw['vehicle'] == 'motorcycle'
                                ? context.strings.partnerMotorcycle
                                : context.strings.partnerCar,
                            '${raw['completed'] ?? 0}',
                          ),
                        ),
                        trailing: Text(
                          context.strings.moneyValue('${raw['earned'] ?? 0}'),
                          style: const TextStyle(
                            color: gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                const SizedBox(height: 12),
                Text(
                  context.strings.partnerMonthly,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_monthlyUnavailable)
                  Text(context.strings.partnerMonthlyUnavailable),
                for (final row in monthly)
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.calendar_month_rounded,
                        color: gold,
                      ),
                      title: Text(row['month']?.toString() ?? ''),
                      subtitle: Text(
                        context.strings.partnerMonthValues(
                          '${row['due'] ?? 0}',
                          '${row['paid'] ?? 0}',
                        ),
                      ),
                      trailing: Text(
                        context.strings.moneyValue('${row['earned'] ?? 0}'),
                        style: const TextStyle(
                          color: gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  context.strings.partnerStatements,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                for (final raw in (info?['settlements'] as List? ?? const []))
                  if (raw is Map)
                    Card(
                      child: ListTile(
                        title: Text(
                          context.strings.moneyValue('${raw['amount'] ?? 0}'),
                        ),
                        subtitle: Text(
                          raw['cutoff']?.toString().split('T').first ?? '',
                        ),
                        trailing: Text(
                          raw['state'] == 'paid'
                              ? context.strings.partnerTransferred
                              : context.strings.partnerPendingTransfer,
                        ),
                      ),
                    ),
              ],
            ),
    ),
  );
}

class PartnerAccessTileV39 extends StatefulWidget {
  const PartnerAccessTileV39({super.key});
  @override
  State<PartnerAccessTileV39> createState() => _PartnerAccessTileV39State();
}

class _PartnerAccessTileV39State extends State<PartnerAccessTileV39> {
  bool active = false;
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final result = await SupabaseService.instance.client
          .rpc('v39_partner_me')
          .timeout(const Duration(seconds: 6));
      if (mounted && result is Map)
        setState(() => active = result['active'] == true);
    } catch (_) {
      /* Partnership must never block the existing account UI. */
    }
  }

  @override
  Widget build(BuildContext context) => active
      ? Card(
          child: ListTile(
            leading: const Icon(
              Icons.handshake_rounded,
              color: Color(0xFFFFC426),
            ),
            title: Text(context.strings.partnerOpen),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const PartnerPortalV39()),
            ),
          ),
        )
      : const SizedBox.shrink();
}

class PartnerPayoutEditor extends StatefulWidget {
  final String initialValue;
  const PartnerPayoutEditor({super.key, required this.initialValue});
  @override
  State<PartnerPayoutEditor> createState() => _PartnerPayoutEditorState();
}

class _PartnerPayoutEditorState extends State<PartnerPayoutEditor> {
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
    title: Text(context.strings.partnerPayoutTitle),
    content: TextField(
      controller: _controller,
      keyboardType: TextInputType.phone,
      maxLength: 11,
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText: context.strings.partnerWalletNumber,
        hintText: '01xxxxxxxxx',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.strings.partnerCancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: Text(context.strings.partnerSave),
      ),
    ],
  );
}
