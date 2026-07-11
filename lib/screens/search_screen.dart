import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../providers/language_provider.dart';
import '../services/ai_chef_service.dart';
import '../widgets/recipe_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Recipe> _results = const [];
  bool _hasSearched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runSearch(String q) {
    final query = q.trim();
    setState(() {
      _hasSearched = query.isNotEmpty;
      _results = query.isEmpty
          ? const []
          : AiChefService().searchByQuery(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.search),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: t.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          _runSearch('');
                        },
                      ),
              ),
              onChanged: (v) => setState(() {}),
              onSubmitted: _runSearch,
            ),
          ),
          Expanded(
            child: !_hasSearched
                ? _empty(t.searchHint)
                : _results.isEmpty
                    ? const Center(
                        child: Text(
                          '😕',
                          style: TextStyle(fontSize: 40),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) =>
                            RecipeCard(recipe: _results[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _empty(String hint) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search, size: 64, color: Color(0xFFCFCFCF)),
            const SizedBox(height: 12),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF777777), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}