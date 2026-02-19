import 'package:flutter/material.dart';

class ArrayLiState extends StatefulWidget {
  const ArrayLiState({super.key});

  @override
  State<ArrayLiState> createState() => _ArrayLiStateState();
}

class _ArrayLiStateState extends State<ArrayLiState> {
  List<int> number = [1, 2, 5, 6, 8, 4, 3, 5, 2];
  List<int> duplicates = [];

  @override
  void initState() {
    super.initState();
    sortAndFindDuplicates();
  }

  void sortAndFindDuplicates() {
    number.sort();
    Set<int> seen = {};
    Set<int> dupSet = {};

    for (var item in number) {
      if (!seen.add(item)) {
        dupSet.add(item);
      }
    }

    duplicates = dupSet.toList();
  }

  List<int> numbers = [2, 3, 6, 4, 5, 8, 2, 3];
  List<int> duplicate = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ArrayList Logic')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sorted List:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(number.toString()),
            const SizedBox(height: 20),
            Text(
              'Duplicate Values:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(duplicates.isEmpty ? 'No Duplicates' : duplicates.toString()),
          ],
        ),
      ),
    );
  }
}
