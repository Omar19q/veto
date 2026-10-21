import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/admin_environment_support.dart';
import 'admin_captain_applications_panel.dart';
import 'admin_captain_intake_v19.dart';
import 'legacy_applications_v16.dart';
import 'admin_team_linking_v58.dart';
import '../growth/admin_badge_activation_screen.dart';
import 'admin_behavior_robot_v58.dart';

/// Three existing application sources, paginated on the server.
/// No records are updated by this screen.
class AdminCaptainRecoveryV58 extends StatefulWidget {
  const AdminCaptainRecoveryV58({super.key});
  @override
  State<AdminCaptainRecoveryV58> createState() => _AdminCaptainRecoveryV58State();
}

class _AdminCaptainRecoveryV58State extends State<AdminCaptainRecoveryV58> {
  static const _pageSize = 50;
  int _offset = 0;
  String _filter = 'all';
  bool _loading = false;
  String? _error;
  String? _countsError;
  int _requestId = 0;
  Map<String, dynamic> _data = const {};
  Map<String, dynamic> _counts = const {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  int number(String name) => (_data[name] as num?)?.toInt() ?? 0;
  Future<void> _refresh() async {
    final requestId = ++_requestId;
    setState(() { _loading = true; _error = null; _countsError = null; });
    // These are independent endpoints. A failed statistics RPC must never
    // hide successfully loaded historical applications.
    Future<void> getApplications() async {
      try {
        final raw = await SupabaseService.instance.client.rpc(
          'v58_owner_application_page',
          params: {'p_offset': _offset, 'p_limit': _pageSize, 'p_status': _filter});
        if (!mounted || requestId != _requestId) return;
        setState(() => _data = Map<String, dynamic>.from(raw as Map));
      } catch (error) {
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _data = const {};
          _error = AdminEnvironmentSupport.explain(error, 'v58_owner_application_page');
        });
      }
    }
    Future<void> getCounts() async {
      try {
        final raw = await SupabaseService.instance.client.rpc('v58_admin_live_counts');
        if (!mounted || requestId != _requestId) return;
        setState(() => _counts = Map<String, dynamic>.from(raw as Map));
      } catch (error) {
        if (!mounted || requestId != _requestId) return;
        setState(() {
          _counts = const {};
          _countsError = AdminEnvironmentSupport.explain(error, 'v58_admin_live_counts');
        });
      }
    }
    await Future.wait([getApplications(), getCounts()]);
    if (mounted && requestId == _requestId) setState(() => _loading = false);
  }

  Future<void> _open(Widget page) async {
    await Navigator.push<void>(context, MaterialPageRoute(
      builder: (_) => Scaffold(body: SafeArea(child: page))));
    if (mounted) _refresh();
  }

  String _status(Object? value) {
    switch (value) {
      case 'pending': return 'قيد المراجعة';
      case 'needs_info': return 'مطلوب استكمال';
      case 'reviewed': return 'تمت المراجعة';
      case 'converted': return 'تم التحويل إلى كابتن';
      case 'rejected': return 'مرفوض';
      default: return value?.toString() ?? '—';
    }
  }
  String _source(Object? value) {
    switch(value) {
      case 'new_v19': return 'طلب تسجيل جديد';
      case 'verified_v16': return 'طلب موثّق V16';
      default: return 'الأرشيف القديم';
    }
  }
  Widget _counter(String name, int? value, IconData icon) => Container(
    constraints: const BoxConstraints(minWidth: 116),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).colorScheme.surfaceContainerHighest),
    padding: const EdgeInsets.all(12),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 21),
      Text(value?.toString() ?? '—', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      Text(name, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final list = (_data['rows'] as List? ?? const [])
        .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final hasMore = (_offset + list.length) < number('filtered_total');
    const choices = <String,String>{
      'all':'الكل','pending':'قيد المراجعة',
      'needs_info':'استكمال','reviewed':'تمت المراجعة',
      'converted':'أصبح كابتن','rejected':'مرفوض'
    };
    return Directionality(textDirection: TextDirection.rtl, child: Column(
      children: [
        const AdminEnvironmentBanner(),
        Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          const Align(alignment: Alignment.centerRight, child: Text('كل طلبات الكباتن — القديم والجديد',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _counter('كل سجلات الطلبات',_data.isEmpty ? null : number('total'),Icons.folder_copy_outlined),
            _counter('تحت المراجعة',_data.isEmpty ? null : number('pending'),Icons.hourglass_top_rounded),
            _counter('طلب استكمال',_data.isEmpty ? null : number('needs_info'),Icons.assignment_late_outlined),
            _counter('تم التحويل لكابتن',_data.isEmpty ? null : number('converted'),Icons.verified_rounded),
            _counter('عملاء مسجّلون',(_counts['customers'] as num?)?.toInt(),Icons.people_outline),
            _counter('كباتن سيارات',(_counts['car_captains'] as num?)?.toInt(),Icons.directions_car),
            _counter('كباتن موتوسيكل',(_counts['motorcycle_captains'] as num?)?.toInt(),Icons.two_wheeler),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final entry in choices.entries)
              ChoiceChip(label: Text(entry.value),selected:_filter==entry.key,
                onSelected: (_) { setState(() {_filter=entry.key; _offset=0;}); _refresh();}),
          ]),
          Wrap(spacing: 8, children: [
            TextButton.icon(onPressed:_loading?null:_refresh,
              icon:const Icon(Icons.refresh),label:const Text('تحديث')),
            TextButton.icon(onPressed:()=>_open(const AdminCaptainIntakeV19()),
              icon:const Icon(Icons.new_releases_outlined),label:const Text('مراجعة V19')),
            TextButton.icon(onPressed:()=>_open(const AdminCaptainApplicationsPanel()),
              icon:const Icon(Icons.assignment_turned_in_outlined),label:const Text('مراجعة V16')),
            TextButton.icon(onPressed:()=>_open(const LegacyApplicationsV16()),
              icon:const Icon(Icons.history),label:const Text('الأرشيف القديم')),
            TextButton.icon(onPressed:()=>_open(const AdminBadgeActivationScreen()),
              icon:const Icon(Icons.qr_code_2_outlined),label:const Text('تفعيل وطباعة البادجات')),
            TextButton.icon(onPressed:()=>_open(const AdminTeamLinkingV58()),
              icon:const Icon(Icons.groups),label:const Text('الفرق والبادجات')),
            TextButton.icon(onPressed:()=>_open(const AdminBehaviorRobotV58()),
              icon:const Icon(Icons.smart_toy_outlined),label:const Text('مراقب السلوك')),
          ]),
          if (_loading) const LinearProgressIndicator(),
          if (_error!=null) Text(_error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
          if (_countsError!=null) Text(_countsError!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
        ])),
        Expanded(child: list.isEmpty && !_loading
          ? Center(child:Text(_error != null
              ? 'تعذر قراءة الطلبات. لا يعني ذلك حذفها. اضغط تحديث بعد إصلاح سبب الاتصال أو الصلاحية.'
              : 'لا توجد طلبات في هذه الفئة ضمن قاعدة البيانات المتصلة.'))
          : ListView.builder(
              itemCount:list.length,
              itemBuilder:(context,index) {
                final a=list[index];
                final source=a['source'];
                final converted=a['converted']==true;
                return Card(
                  margin:const EdgeInsets.symmetric(horizontal:12,vertical:4),
                  child:ListTile(
                    leading: Icon(converted?Icons.verified_user:Icons.assignment_ind_outlined),
                    title:Text(a['full_name']?.toString()??'طلب بدون اسم',
                      style:const TextStyle(fontWeight:FontWeight.w700)),
                    subtitle:Text('${a['phone']??''}  •  ${_source(source)}\n'
                      '${_status(a['display_status'])}  •  ${a['vehicle_type']??''}'),
                    isThreeLine:true,
                    trailing:const Icon(Icons.chevron_left),
                    onTap:()=>_open(source=='new_v19'
                      ?const AdminCaptainIntakeV19()
                      :source=='verified_v16'
                        ?const AdminCaptainApplicationsPanel()
                        :const LegacyApplicationsV16()),
                  ),
                );
              })),
        Padding(padding:const EdgeInsets.fromLTRB(12,5,12,12),
          child:Row(children:[
            Expanded(child:Text(_data.isEmpty ? 'لا تتوفر أرقام صحيحة حتى ينجح التحميل' : 'عرض ${list.isEmpty ? 0 : _offset+1}–${_offset+list.length} من ${number('filtered_total')} سجل • 50 في الصفحة',
              style:const TextStyle(fontSize:11))),
            IconButton(tooltip:'السابق',onPressed:_loading||_offset==0?null:() {
              setState(()=>_offset=(_offset-_pageSize).clamp(0,100000).toInt());
              _refresh();},icon:const Icon(Icons.chevron_right)),
            IconButton(tooltip:'التالي',onPressed:_loading||!hasMore?null:(){
              setState(()=>_offset+=_pageSize);
              _refresh();},icon:const Icon(Icons.chevron_left)),
          ])),
      ],
    ));
  }
}
