import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/address_suggestion_service.dart';
import '../../widgets/v37_suggest_address_button.dart';

class AddressSuggestionHistory extends StatefulWidget {
  const AddressSuggestionHistory({super.key});
  @override
  State<AddressSuggestionHistory> createState() =>
      _AddressSuggestionHistoryState();
}

class _AddressSuggestionHistoryState extends State<AddressSuggestionHistory> {
  late Future<List<Map<String, dynamic>>> _items;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _items = AddressSuggestionService().history();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String status(dynamic s) => switch (s) {
      'published' => l.published,
      'rejected' => l.rejected,
      'needs_information' => l.needsInformation,
      'reviewed' => l.reviewed,
      _ => l.pending,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.mySuggestions)),
      body: FutureBuilder(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Text('تعذر تحميل اقتراحات العناوين. تحقق من اتصال الإنترنت، ثم اضغط إعادة المحاولة. الطلبات السابقة لم تُحذف.',
                      textAlign: TextAlign.center),
                  ),
                  TextButton(
                    onPressed: () => setState(_reload),
                    child: Text(l.retry),
                  ),
                ],
              ),
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await _items;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (snapshot.data!.isEmpty) Text(l.emptySuggestions),
                for (final item in snapshot.data!)
                  Card(
                    child: ListTile(
                      title: Text(
                        '${item['city_label']} — ${item['place_label']}',
                      ),
                      subtitle: Text(
                        '${status(item['review_status'])}\n${item['review_reason'] ?? ''}',
                      ),
                      isThreeLine: true,
                      trailing: item['review_status'] == 'needs_information'
                          ? TextButton(
                              onPressed: () async {
                                await V37SuggestAddressButton.correct(
                                  context,
                                  item,
                                );
                                if (mounted) setState(_reload);
                              },
                              child: Text(l.correctSuggestion),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
