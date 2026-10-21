import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'admin_place_pin_picker_v39.dart';
import 'admin_address_suggestions.dart';
import 'admin_city_boundary_picker_v44.dart';
import '../../services/supabase_service.dart';

/// Owner city/area/building administration. V49 activates a verified city
/// polygon and its future trip tariffs atomically on the server.
class AdminCityCatalogV37 extends StatefulWidget {
  final String kind;
  final String? initialCityId;
  const AdminCityCatalogV37({super.key, this.kind='all', this.initialCityId});
  @override
  State<AdminCityCatalogV37> createState() => _AdminCityCatalogV37State();
}

class _AdminCityCatalogV37State extends State<AdminCityCatalogV37> {
  List<Map<String, dynamic>> _cities = [];
  final Map<String,Map<String,dynamic>> _draftTariffs = {};
  String _governorate = 'الجيزة';
  bool _openedInitial = false;
  bool _busy = false;
  String? _error;
  static const _styles = <String, String>{
    'street':'شارع ورقم عقار', 'building':'عمارة',
    'compound':'حي أو كمبوند', 'village':'قرية وعلامة مميزة',
    'mixed':'أكثر من طريقة',
  };
  @override
  void initState() { super.initState(); _reload(); }

  Future<void> _reload() async {
    if (mounted) setState(() { _busy=true; _error=null; });
    try {
      final result = await SupabaseService.instance.client.rpc('v37_admin_city_catalog')
          .timeout(const Duration(seconds: 12));
      if (result is! Map) throw StateError('response_not_map');
      try {
        final tariffData=await SupabaseService.instance.client.rpc(
          'v43_owner_city_tariff_drafts',
        ).timeout(const Duration(seconds: 12));
        _draftTariffs.clear();
        if (tariffData is List) {
          for (final draft in tariffData.whereType<Map>()) {
            final m=Map<String,dynamic>.from(draft);
            _draftTariffs[m['city_id'].toString()]=m;
          }
        }
      } catch (_) { /* Draft city pricing is optional until V43 SQL is installed. */ }
      if (!mounted) return;
      setState(() {
        _cities = (result['cities'] as List? ?? const [])
            .whereType<Map>().map((x) => Map<String,dynamic>.from(x)).toList();
      });
      if (!_openedInitial && widget.initialCityId != null) {
        _openedInitial = true;
        final matches = _cities.where((c) => c['id']?.toString() == widget.initialCityId).toList();
        if (matches.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _editCity(matches.first);
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error='محتاج تفعيل SQL V37 أو مراجعة صلاحيات الأونر.');
    } finally { if (mounted) setState(() => _busy=false); }
  }

  Future<void> _editCity(Map<String, dynamic> city) async {
    var selected = city['address_style']?.toString() ?? 'mixed';
    if (!_styles.containsKey(selected)) selected = 'mixed';
    final geometry = TextEditingController(
      text: city['boundary_geojson'] == null ? '' : jsonEncode(city['boundary_geojson']),
    );
    final id=city['id']?.toString();
    if(id==null) {geometry.dispose(); return;}
    try {
      final saved=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(
        builder:(ctx,update)=>AlertDialog(
          title:Text('حدود ${city['name']}',style:const TextStyle(fontFamily:'Cairo')),
          content:SizedBox(width:510,child:SingleChildScrollView(child:Column(
            mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
            children:[
              const Text('طريقة كتابة العنوان',style:TextStyle(fontFamily:'Cairo')),
              DropdownButton<String>(value:selected,isExpanded:true,
                items:[for(final entry in _styles.entries)
                  DropdownMenuItem(value:entry.key,child:Text(entry.value))],
                onChanged:(v){if(v!=null)update(()=>selected=v);}),
              const SizedBox(height:10),
              OutlinedButton.icon(icon:const Icon(Icons.map_outlined),
                label:const Text('رسم / تعديل حدود المدينة'),
                onPressed:() async {
                  Map<String,dynamic>? previous;
                  try { final raw=jsonDecode(geometry.text);
                    if(raw is Map) previous=Map<String,dynamic>.from(raw);
                  } catch (_) {}
                  final boundary=await Navigator.of(ctx).push<Map<String,dynamic>>(
                    MaterialPageRoute(builder:(_)=>AdminCityBoundaryPickerV44(
                      cityName:city['name']?.toString()??'المدينة',existing:previous)));
                  if(boundary==null||!ctx.mounted)return;
                  geometry.text=jsonEncode(boundary);
                  update((){});
                }),
              const SizedBox(height:10),
              Text(geometry.text.isEmpty
                  ? 'ارسم حدود المدينة أولاً. من غير حدود هتفضل غير مفعلة.'
                  : 'بعد الحفظ: يتم التأكد من الحدود وإنشاء منطقة تسعير بالأسعار المعروضة تحت المدينة وتفعيلها تلقائيًا. أي تداخل مع منطقة فعّالة يتم رفضه للحماية.',
                style:const TextStyle(fontFamily:'Cairo',fontSize:12)),
              const SizedBox(height:8),
              const Text('لو المدينة متعددة المضلعات، ارسم نطاقًا واحدًا صحيحًا بدل حذف أجزاء بصمت.',
                style:TextStyle(fontFamily:'Cairo',fontSize:11)),
            ]))),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ وتفعيل تلقائي')),
          ],
        )));
      if(saved!=true||!mounted)return;
      Map<String,dynamic>? boundary;
      if(geometry.text.trim().isNotEmpty){
        final raw=jsonDecode(geometry.text);
        if(raw is! Map || raw['type']!='Polygon' || raw['coordinates'] is! List){
          throw const FormatException('ارسم حدود Polygon صالحة.');
        }
        boundary=Map<String,dynamic>.from(raw);
      }
      final result=await SupabaseService.instance.client.rpc(
        'v49_owner_save_activate_city',params:{
          'p_city':id,'p_style':selected,'p_boundary':boundary,
        }).timeout(const Duration(seconds:20));
      await _reload();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text(result is Map && result['enabled']==true
          ? 'تم حفظ الحدود والتسعير وتفعيل المدينة تلقائيًا.'
          : 'تم الحفظ كمسودة؛ ارسم الحدود لتفعيل المدينة.')));
    } catch (e) {
      if(mounted)setState(()=>_error='تعذر تفعيل المدينة: $e');
    } finally {geometry.dispose();}
  }

  // Uses V49 transactional saving: updates active city pricing zone and future quotes only.
  Future<void> _editTariff(Map<String,dynamic> city) async {
    final draft = _draftTariffs[city['id']?.toString()] ?? const <String,dynamic>{};
    final car = TextEditingController(text:'${draft['car_opening'] ?? 29}');
    final carKm = TextEditingController(text:'${draft['car_per_km'] ?? 9}');
    final moto = TextEditingController(text:'${draft['moto_opening'] ?? 23}');
    final motoKm = TextEditingController(text:'${draft['moto_per_km'] ?? 6.5}');
    try {
      final approved = await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
        title:Text('أسعار ${city['name']} — تفعيل تلقائي بعد رسم الحدود'),
        content:SizedBox(width:460,child:SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,children:[
            TextField(controller:car,keyboardType:const TextInputType.numberWithOptions(decimal:true),
              decoration:const InputDecoration(labelText:'بداية مشوار السيارة (جنيه)')),
            TextField(controller:carKm,keyboardType:const TextInputType.numberWithOptions(decimal:true),
              decoration:const InputDecoration(labelText:'كيلومتر السيارة (جنيه)')),
            TextField(controller:moto,keyboardType:const TextInputType.numberWithOptions(decimal:true),
              decoration:const InputDecoration(labelText:'بداية مشوار الموتوسيكل (جنيه)')),
            TextField(controller:motoKm,keyboardType:const TextInputType.numberWithOptions(decimal:true),
              decoration:const InputDecoration(labelText:'كيلومتر الموتوسيكل (جنيه)')),
            const Padding(padding:EdgeInsets.only(top:12),child:Text(
              'دي تسعيرة المدينة المعتمدة: عند حفظها تتحدث تلقائيًا للمشاوير الجديدة إذا حدود المدينة جاهزة.',
              style:TextStyle(fontSize:12))),
          ],))),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('رجوع')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ الأسعار')),
        ],
      ));
      if (approved!=true || !mounted) return;
      final amounts=[car.text,carKm.text,moto.text,motoKm.text]
        .map((text)=>double.tryParse(text.trim())).toList();
      if (amounts.any((a)=>a==null || a<0 || a>10000)) {
        throw const FormatException('invalid_city_tariff');
      }
      await SupabaseService.instance.client.rpc('v49_owner_save_city_tariff',params:{
        'p_city':city['id'], 'p_car_opening':amounts[0], 'p_car_km':amounts[1],
        'p_moto_opening':amounts[2], 'p_moto_km':amounts[3],
      }).timeout(const Duration(seconds:12));
      await _reload();
    } catch (_) {
      if(mounted)setState(()=>_error='تعذر اعتماد الأسعار: راجع حدود المدينة أو المناطق المتداخلة وثبّت SQL V49.');
    } finally {car.dispose();carKm.dispose();moto.dispose();motoKm.dispose();}
  }

  Future<void> _addAddress(Map<String,dynamic> city,
      {Map<String,dynamic>? parent,bool areaOnly=false}) async {
    final name=TextEditingController();
    final hint=TextEditingController();
    final letter=TextEditingController();
    final lat=TextEditingController();
    final lng=TextEditingController();
    var kind=parent!=null?'building':areaOnly?'compound':widget.kind=='building'?'building':'landmark';
    try {
      final saved=await showDialog<bool>(context:context,
        builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
          title:Text(parent!=null
            ? 'عمارة داخل ${parent['name']}'
            : areaOnly?'إضافة منطقة / مكان في ${city['name']}'
            : 'إضافة مكان في ${city['name']}',
            style:const TextStyle(fontFamily:'Cairo')),
          content:SizedBox(width:500,child:SingleChildScrollView(child:Column(
            mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
            children:[
              if(parent==null&&!areaOnly)DropdownButton<String>(value:kind,isExpanded:true,items:const [
                DropdownMenuItem(value:'landmark',child:Text('مكان معروف')),
                DropdownMenuItem(value:'building',child:Text('عمارة مستقلة')),
                DropdownMenuItem(value:'compound',child:Text('منطقة / كمبوند')),
                DropdownMenuItem(value:'street',child:Text('شارع')),
                DropdownMenuItem(value:'village',child:Text('قرية')),
              ],onChanged:(v){if(v!=null)update(()=>kind=v);}),
              if(parent!=null)TextField(controller:letter,maxLength:5,
                decoration:const InputDecoration(labelText:'حرف العمارة (اختياري: أ، ب، ج...)')),
              TextField(controller:name,maxLength:150,
                decoration:InputDecoration(labelText:parent!=null?'رقم العمارة':'اسم المكان / المنطقة')),
              TextField(controller:hint,maxLength:200,
                decoration:const InputDecoration(labelText:'وصف إضافي (اختياري)')),
              const SizedBox(height:8),
              OutlinedButton.icon(icon:const Icon(Icons.place),
                label:Text(lat.text.isEmpty?'تحديد موقع حقيقي على الخريطة':'تغيير النقطة المحددة'),
                onPressed:()async{
                  final point=await Navigator.of(ctx).push<LatLng>(MaterialPageRoute(
                    builder:(_)=>AdminPlacePinPickerV39(
                      initialLat:double.tryParse(lat.text) ??
                        double.tryParse('${parent?['latitude']}'),
                      initialLng:double.tryParse(lng.text) ??
                        double.tryParse('${parent?['longitude']}'),
                      requireFreshTap:parent!=null)));
                  if(point==null||!ctx.mounted)return;
                  lat.text=point.latitude.toStringAsFixed(7);
                  lng.text=point.longitude.toStringAsFixed(7);
                  update((){});
                }),
              if(lat.text.isNotEmpty)Text('الموقع: ${lat.text}, ${lng.text}'),
              const Text('لازم نقطة المكان تكون داخل حدود المدينة المفعلة. عمارات بدون نقطة تتسجل كمسودات فقط.',
                style:TextStyle(fontSize:11,fontFamily:'Cairo')),
            ]))),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ ونشر')),
          ],
        )));
      if(saved!=true||!mounted)return;
      final n=(parent!=null && letter.text.trim().isNotEmpty)
          ? '${letter.text.trim()} ${name.text.trim()}' : name.text.trim();
      if(n.isEmpty || (parent==null&&n.length<2))throw const FormatException('اكتب الاسم أو الرقم.');
      final la=double.tryParse(lat.text),lo=double.tryParse(lng.text);
      if(la==null||lo==null)throw const FormatException('حدد موقع المكان على الخريطة.');
      await SupabaseService.instance.client.rpc('v49_owner_add_place_or_building',params:{
        'p_city':city['id'],'p_parent':parent?['id'],'p_kind':kind,
        'p_name':n,'p_note':hint.text.trim(),'p_lat':la,'p_lng':lo,
      }).timeout(const Duration(seconds:15));
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('تم الحفظ والنشر للعميل بموقع معتمد.')));
    }catch(e){if(mounted)setState(()=>_error='تعذر إضافة العنوان: $e');}
    finally{name.dispose();hint.dispose();letter.dispose();lat.dispose();lng.dispose();}
  }

  Future<void> _bulkBuildingNumbers(Map<String,dynamic> city,Map<String,dynamic> area)async{
    final first=TextEditingController(text:'1');
    final last=TextEditingController(text:'100');
    final letter=TextEditingController();
    try{
      final saved=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
        title:Text('أرقام عمارات ${area['name']}'),
        content:SizedBox(width:400,child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:first,keyboardType:TextInputType.number,
            decoration:const InputDecoration(labelText:'من رقم')),
          TextField(controller:last,keyboardType:TextInputType.number,
            decoration:const InputDecoration(labelText:'إلى رقم')),
          TextField(controller:letter,maxLength:5,
            decoration:const InputDecoration(labelText:'حرف العمارات - اختياري')),
          const SizedBox(height:8),
          const Text('حتى 250 رقم في المرة. الأرقام مسودات حتى تحدد موقع كل عمارة على الخريطة.',
            style:TextStyle(fontSize:12)),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('رجوع')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('إنشاء الأرقام'))],
      ));
      if(saved!=true||!mounted)return;
      final start=int.tryParse(first.text),end=int.tryParse(last.text);
      if(start==null||end==null)throw const FormatException('أدخل أرقام صحيحة.');
      final count=await SupabaseService.instance.client.rpc('v50_owner_prepare_building_numbers',params:{
        'p_city':city['id'],'p_parent':area['id'],'p_first':start,'p_last':end,
        'p_letter':letter.text.trim(),
      }).timeout(const Duration(seconds:20));
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text('تم إنشاء $count عمارة كمسودات. اضغط تحديد موقع لكل عمارة لنشرها.')));
    }catch(e){if(mounted)setState(()=>_error='تعذر إضافة أرقام العمارات: $e');}
    finally{first.dispose();last.dispose();letter.dispose();}
  }

  // Customer GPS suggestions remain private until an owner chooses a verified
  // pin in the existing area/building tool, then marks the suggestion reviewed.
  Future<void> _showCustomerSuggestions(Map<String,dynamic> city) async {
    try {
      final raw=await SupabaseService.instance.client.rpc(
        'v50_owner_address_suggestions',params:{'p_city':city['id']})
        .timeout(const Duration(seconds:15));
      if(!mounted)return;
      final entries=(raw as List? ?? const []).whereType<Map>()
          .map((x)=>Map<String,dynamic>.from(x)).toList();
      await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
        title:Text('اقتراحات العملاء — ${city['name']}'),
        content:SizedBox(width:640,height:430,child:entries.isEmpty
          ? const Center(child:Text('مفيش اقتراحات جديدة'))
          : ListView(children:[
            const Text('حدد الموقع من الخريطة وانشر المنطقة/العمارة بأدوات الأدمن أولاً؛ بعدها علّم الاقتراح كمراجع.',
              style:TextStyle(fontFamily:'Cairo',fontSize:12)),
            for(final item in entries)Card(child:ListTile(
              leading:const Icon(Icons.person_pin_circle_outlined),
              title:Text('${item['name']??''}',style:const TextStyle(fontFamily:'Cairo')),
              subtitle:Text('منطقة: ${item['area']??''}   •   GPS: ${item['latitude']??''}, ${item['longitude']??''}',
                style:const TextStyle(fontSize:11)),
              trailing:Wrap(children:[
                IconButton(tooltip:'افتح أداة العناوين للتسجيل اليدوي',
                  icon:const Icon(Icons.map_outlined),onPressed:()async{
                    Navigator.pop(ctx);
                    await _reviewCityAddresses(city);
                  }),
                IconButton(tooltip:'تمت المراجعة يدويًا',icon:const Icon(Icons.done,color:Colors.green),
                  onPressed:()async{
                    try{
                      await SupabaseService.instance.client.rpc(
                        'v50_owner_mark_address_suggestion',params:{
                          'p_id':item['id'],'p_status':'reviewed'});
                      if(ctx.mounted)Navigator.pop(ctx);
                      if(mounted)await _showCustomerSuggestions(city);
                    }catch(e){if(mounted)setState(()=>_error='تعذر تسجيل المراجعة: $e');}
                  }),
                IconButton(tooltip:'رفض الاقتراح',icon:const Icon(Icons.close,color:Colors.redAccent),
                  onPressed:()async{
                    try{
                      await SupabaseService.instance.client.rpc(
                        'v50_owner_mark_address_suggestion',params:{
                          'p_id':item['id'],'p_status':'rejected'});
                      if(ctx.mounted)Navigator.pop(ctx);
                      if(mounted)await _showCustomerSuggestions(city);
                    }catch(e){if(mounted)setState(()=>_error='تعذر رفض الاقتراح: $e');}
                  }),
              ]),
            )),
          ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))],
      ));
    }catch(e){if(mounted)setState(()=>_error='تعذر تحميل اقتراحات العملاء: $e');}
  }

  Future<void> _pinDraftBuilding(Map<String,dynamic> entry)async{
    try{
      final point=await Navigator.of(context).push<LatLng>(MaterialPageRoute(
        builder:(_)=>AdminPlacePinPickerV39(
          initialLat:double.tryParse('${entry['latitude']}'),
          initialLng:double.tryParse('${entry['longitude']}'),
          requireFreshTap:true)));
      if(point==null)return;
      await SupabaseService.instance.client.rpc('v49_owner_pin_building',params:{
        'p_id':entry['id'],'p_lat':point.latitude,'p_lng':point.longitude,
      }).timeout(const Duration(seconds:15));
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('تم اعتماد موقع العمارة ونشرها للعميل.')));
    }catch(e){if(mounted)setState(()=>_error='لم يتم نشر العمارة: $e');}
  }

  Future<void> _toggleCity(Map<String,dynamic> city,bool enabled) async {
    try {
      await SupabaseService.instance.client.rpc('v49_owner_set_city_enabled',params:{
        'p_city':city['id'],'p_enable':enabled,
      }).timeout(const Duration(seconds:12));
      await _reload();
    } catch (_) {
      if (mounted) setState(()=>_error='تعذر التفعيل: ارسم حدودًا صحيحة وحدد أسعار المدينة، وتأكد من عدم تداخلها مع مدينة أخرى.');
    }
  }

  Future<void> _reviewCityAddresses(Map<String,dynamic> city)async{
    try{
      final result=await SupabaseService.instance.client.rpc('v49_owner_city_places',
        params:{'p_city':city['id']}).timeout(const Duration(seconds:15));
      if(!mounted)return;
      final all=(result as List? ?? const []).whereType<Map>()
        .map((a)=>Map<String,dynamic>.from(a)).toList();
      final areas=all.where((a)=>a['parent_id']==null &&
        a['kind']!='building').toList();
      final sorted=<Map<String,dynamic>>[
        for(final area in areas)...[
          area,...all.where((a)=>a['parent_id']==area['id']),
        ],
        ...all.where((a)=>a['parent_id']==null&&a['kind']=='building'),
      ];
      await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
        title:Text('مناطق وعمارات ${city['name']}'),
        content:SizedBox(width:700,height:500,child:Column(children:[
          const Text('1. أضف منطقة مثل «ابني بيتك». 2. أضف أرقام عمارات تحتها. 3. حدد موقع كل عمارة لنشرها.',
            style:TextStyle(fontSize:12,fontFamily:'Cairo')),
          const SizedBox(height:8),
          Expanded(child:sorted.isEmpty?const Center(child:Text('ابدأ بإضافة منطقة')):
            ListView(children:[for(final entry in sorted) Card(child:ListTile(
              leading:Icon(entry['parent_id']==null?Icons.location_city:Icons.apartment),
              title:Text(entry['parent_id']==null?'${entry['name']}':
                '${entry['parent_name']} ← عمارة ${entry['name']}'),
              subtitle:Text(entry['is_visible']==true?'منشور للعميل':
                entry['is_verified']==true?'معتمد لكن غير منشور':'مسودة — مطلوب موقع العمارة'),
              trailing:Wrap(spacing:0,children:[
                if(entry['parent_id']==null&&entry['kind']!='building')...[
                  IconButton(tooltip:'إضافة عمارة',icon:const Icon(Icons.add_location_alt),
                    onPressed:()async{Navigator.pop(ctx);await _addAddress(city,parent:entry);
                      if(mounted)await _reviewCityAddresses(city);}),
                  IconButton(tooltip:'أرقام عمارات دفعة واحدة',icon:const Icon(Icons.format_list_numbered),
                    onPressed:()async{Navigator.pop(ctx);await _bulkBuildingNumbers(city,entry);
                      if(mounted)await _reviewCityAddresses(city);}),
                ],
                if(entry['kind']=='building'&&entry['parent_id']!=null&&entry['is_visible']!=true)
                  IconButton(tooltip:'تحديد موقع ونشر',icon:const Icon(Icons.add_location),
                    onPressed:()async{Navigator.pop(ctx);await _pinDraftBuilding(entry);
                      if(mounted)await _reviewCityAddresses(city);}),
              ]),
            ))])),
        ])),
        actions:[
          TextButton(onPressed:()async{Navigator.pop(ctx);await _addAddress(city,areaOnly:true);
            if(mounted)await _reviewCityAddresses(city);},child:const Text('إضافة منطقة')),
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق')),
        ],
      ));
    }catch(e){if(mounted)setState(()=>_error='تعذر عرض الأماكن: $e');}
  }

  @override
  Widget build(BuildContext context) {
    final filtered=_cities.where((city)=>city['governorate']==_governorate).toList();
    return Directionality(textDirection:TextDirection.rtl,child:Scaffold(
      backgroundColor:const Color(0xFF0C1220),
      body:RefreshIndicator(onRefresh:_reload,child:ListView(
        padding:const EdgeInsets.all(16),children:[
          Row(children:[
            const Expanded(child:Text('المدن والعناوين',style:TextStyle(
              fontFamily:'Cairo',fontSize:20,color:Colors.white,fontWeight:FontWeight.w900))),
            IconButton(onPressed:_busy?null:_reload,icon:const Icon(Icons.refresh,color:Colors.amber)),
            IconButton(tooltip:'جميع اقتراحات العناوين وحالاتها',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AdminAddressSuggestions())),icon:const Icon(Icons.inbox_outlined,color:Colors.amber)),
          ]),
          const Text('ارسم حدود المدينة وحدد تسعيرتها، وبعدها أضف مناطق وعمارات بأرقام وحروف اختيارية. اقتراحات العملاء للمراجعة قبل النشر.',
            style:TextStyle(fontFamily:'Cairo',color:Colors.white70,fontSize:12)),
          if(_busy) const LinearProgressIndicator(),
          if(_error!=null) Padding(padding:const EdgeInsets.all(8),child:Text(_error!,
            style:const TextStyle(color:Colors.orangeAccent,fontFamily:'Cairo'))),
          const SizedBox(height:14),
          SegmentedButton<String>(segments:const [
            ButtonSegment(value:'الجيزة',label:Text('الجيزة')),
            ButtonSegment(value:'القاهرة',label:Text('القاهرة')),
          ],selected:{_governorate},onSelectionChanged:(s)=>setState(()=>_governorate=s.first)),
          const SizedBox(height:12),
          for(final city in filtered) Card(
            color:const Color(0xFF18243A),
            child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[
              const Icon(Icons.location_city,color:Colors.amber),const SizedBox(width:10),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(city['name']?.toString()??'',style:const TextStyle(color:Colors.white,
                  fontFamily:'Cairo',fontWeight:FontWeight.w800)),
                Text('${_styles[city['address_style']] ?? 'عناوين متعددة'} · ${city['pricing_zone_id'] == null ? 'منطقة غير معتمدة' : city['is_enabled']==true ? 'المدينة مفعلة' : 'مدينة غير مفعلة'}',
                  style:const TextStyle(color:Colors.white60,fontFamily:'Cairo',fontSize:11)),
                TextButton.icon(
                  onPressed:()=>_reviewCityAddresses(city),
                  icon:const Icon(Icons.apartment,size:17),
                  label:const Text('المناطق وأرقام العمارات',style:TextStyle(fontFamily:'Cairo',fontSize:11)),
                ),
                if(_draftTariffs.containsKey(city['id']?.toString()))
                  Text('سيارة: ${_draftTariffs[city['id']?.toString()]?['car_opening']} ج + ${_draftTariffs[city['id']?.toString()]?['car_per_km']} ج/كم   •   موتوسيكل: ${_draftTariffs[city['id']?.toString()]?['moto_opening']} ج + ${_draftTariffs[city['id']?.toString()]?['moto_per_km']} ج/كم',
                    style:const TextStyle(fontSize:10,color:Colors.amber)),
              ])),
              Switch(value:city['is_enabled']==true,
                onChanged:(v)=>_toggleCity(city,v)),
              IconButton(tooltip:'أسعار المدينة',onPressed:()=>_editTariff(city),
                icon:const Icon(Icons.payments_outlined,color:Colors.amber)),
              IconButton(tooltip:'اقتراحات العملاء',onPressed:()=>_showCustomerSuggestions(city),
                icon:const Icon(Icons.rate_review_outlined,color:Colors.amber)),
              IconButton(tooltip:'عرض العناوين',onPressed:()=>_reviewCityAddresses(city),
                icon:const Icon(Icons.list_alt,color:Colors.white70)),
              IconButton(tooltip:'إضافة منطقة / مكان',onPressed:()=>_addAddress(city,areaOnly:true),
                icon:const Icon(Icons.add_location_alt,color:Colors.amber)),
              IconButton(tooltip:'تعديل إعدادات العناوين',onPressed:()=>_editCity(city),
                icon:const Icon(Icons.edit_outlined,color:Colors.white70)),
            ]))),
          const SizedBox(height:32),
        ],
      )),
    ));
  }
}
