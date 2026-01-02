import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/class_provider.dart';
import '../widgets/class_card.dart';

class SearchFilterScreen extends StatefulWidget {
  const SearchFilterScreen({super.key});
  static const routeName = '/search-filter';

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  String _query = '';
  int? _dayFilter;

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<ClassProvider>().classes;
    final filtered = classes.where((c) {
      final matchesQuery = c.name.toLowerCase().contains(_query.toLowerCase()) ||
          c.location.toLowerCase().contains(_query.toLowerCase()) ||
          c.instructorOrRoom.toLowerCase().contains(_query.toLowerCase());
      final matchesDay = _dayFilter == null || c.daysOfWeek.contains(_dayFilter);
      return matchesQuery && matchesDay;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Search & Filter')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by class, instructor, location'),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All days'),
                    selected: _dayFilter == null,
                    onSelected: (_) => setState(() => _dayFilter = null),
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(7, (index) {
                    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                    final day = index + 1;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(labels[index]),
                        selected: _dayFilter == day,
                        onSelected: (_) => setState(() => _dayFilter = day),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No results'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => ClassCard(model: filtered[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
