import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/pack_stats.dart';
import '../stats_texts.dart';

/// Un tema con su dato y el botón «Practicar este tema», que abre la
/// configuración de práctica con ese tema ya marcado.
class TopicToPractice extends StatelessWidget {
  const TopicToPractice({super.key, required this.topic, required this.detail});

  final TopicStats topic;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            topicTitle(topic),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(detail),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.go('/practice?tema=${topic.topic.id}'),
              icon: const Icon(Icons.school_outlined),
              label: const Text('Practicar este tema'),
            ),
          ),
        ],
      ),
    ),
  );
}
