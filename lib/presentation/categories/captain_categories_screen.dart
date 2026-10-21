import 'package:flutter/material.dart';
import '../../services/ride_categories.dart';
import '../../widgets/ride_category_card.dart';

class CaptainCategoriesScreen extends StatefulWidget {
  const CaptainCategoriesScreen({super.key});
  @override
  State<CaptainCategoriesScreen> createState() =>
      _CaptainCategoriesScreenState();
}

class _CaptainCategoriesScreenState extends State<CaptainCategoriesScreen> {
  late Future<List<RideCategory>> _data;
  @override
  void initState() {
    super.initState();
    _data = RideCategories.instance.mine();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        categoryCopy(context, 'الفئات المتاحة لي', 'My ride categories'),
      ),
    ),
    body: FutureBuilder<List<RideCategory>>(
      future: _data,
      builder: (context, s) {
        if (s.hasError)
          return Center(
            child: FilledButton(
              onPressed: () =>
                  setState(() => _data = RideCategories.instance.mine()),
              child: Text(categoryCopy(context, 'إعادة المحاولة', 'Retry')),
            ),
          );
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              categoryCopy(
                context,
                'الفئات اللي تقدر تستقبلها',
                'Categories you can receive',
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                categoryCopy(
                  context,
                  'التفعيل بعد مراجعة الهوية والعربية والمستندات والتأمين. الموافقة على فئة السيدات منفصلة.',
                  'Access requires identity, vehicle, document and insurance approval. Ladies approval is separate.',
                ),
              ),
            ),
            for (final c in s.data!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RideCategoryCard(
                  category: c,
                  selected: c.authorized,
                  status: c.authorized
                      ? categoryCopy(
                          context,
                          c.enabled
                              ? 'معتمدة — متاحة لاستقبال الطلبات'
                              : 'معتمدة — استقبال الطلبات متوقف',
                          c.enabled
                              ? 'Approved — receiving requests'
                              : 'Approved — new requests paused',
                        )
                      : categoryCopy(
                          context,
                          'تحتاج مراجعة الإدارة',
                          'Requires admin review',
                        ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
