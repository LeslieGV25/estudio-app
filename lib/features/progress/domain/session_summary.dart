import '../../packs/domain/entities/study_question.dart';
import 'entities/answer.dart';

/// Cómo terminó una pregunta de la sesión.
enum AnswerOutcome {
  correct,
  wrong,
  blank,

  /// Pregunta anulada: la respuesta se guarda, pero no cuenta (ni en los
  /// porcentajes ni en el desglose ni, más adelante, en el repaso).
  notCounted,

  /// La sesión terminó sin llegar a esta pregunta.
  unanswered,
}

/// Una pregunta de la sesión con su respuesta (si la hubo).
class SummaryItem {
  const SummaryItem(this.question, this.answer, this.outcome);

  final StudyQuestion question;
  final Answer? answer;
  final AnswerOutcome outcome;
}

/// Aciertos, fallos y en blanco de un tema. Solo respuestas que cuentan.
class TopicBreakdown {
  const TopicBreakdown({
    required this.topicId,
    required this.topicTitle,
    required this.correct,
    required this.wrong,
    required this.blank,
  });

  final int topicId;
  final String topicTitle;
  final int correct;
  final int wrong;
  final int blank;

  int get total => correct + wrong + blank;
}

/// Resumen final de una sesión, calculado a partir de sus preguntas y de
/// las respuestas guardadas (no del estado de la pantalla): así se puede
/// mostrar igual al terminar que al volver a abrirlo días después.
///
/// Lo comparten práctica, repaso y simulacro (este con su nota aparte).
class SessionSummary {
  SessionSummary._(this.items, this.byTopic);

  /// [questions] en el orden de la sesión. Si una pregunta tiene varias
  /// respuestas cuenta la primera; las respuestas a preguntas que ya no
  /// están en [questions] se ignoran.
  factory SessionSummary.from(
    List<StudyQuestion> questions,
    List<Answer> answers,
  ) {
    final firstAnswer = <String, Answer>{};
    for (final answer in answers) {
      firstAnswer.putIfAbsent(answer.questionId, () => answer);
    }

    final items = [
      for (final q in questions)
        SummaryItem(q, firstAnswer[q.id], _outcome(q, firstAnswer[q.id])),
    ];

    final topics = <int, _TopicCounter>{};
    for (final item in items) {
      final counter = topics.putIfAbsent(
        item.question.topicId,
        () => _TopicCounter(item.question.topicTitle),
      );
      switch (item.outcome) {
        case AnswerOutcome.correct:
          counter.correct++;
        case AnswerOutcome.wrong:
          counter.wrong++;
        case AnswerOutcome.blank:
          counter.blank++;
        case AnswerOutcome.notCounted || AnswerOutcome.unanswered:
          break;
      }
    }
    final byTopic = [
      for (final MapEntry(key: id, value: c) in topics.entries)
        if (c.total > 0)
          TopicBreakdown(
            topicId: id,
            topicTitle: c.title,
            correct: c.correct,
            wrong: c.wrong,
            blank: c.blank,
          ),
    ]..sort((a, b) => a.topicId.compareTo(b.topicId));

    return SessionSummary._(
      List.unmodifiable(items),
      List.unmodifiable(byTopic),
    );
  }

  static AnswerOutcome _outcome(StudyQuestion q, Answer? answer) {
    if (answer == null) return AnswerOutcome.unanswered;
    if (q.question.voided) return AnswerOutcome.notCounted;
    if (answer.isBlank) return AnswerOutcome.blank;
    return answer.isCorrect ? AnswerOutcome.correct : AnswerOutcome.wrong;
  }

  /// Todas las preguntas de la sesión, en su orden.
  final List<SummaryItem> items;

  /// Desglose por tema (por id de tema), solo con respuestas que cuentan.
  final List<TopicBreakdown> byTopic;

  int get correct => _count(AnswerOutcome.correct);
  int get wrong => _count(AnswerOutcome.wrong);
  int get blank => _count(AnswerOutcome.blank);
  int get notCounted => _count(AnswerOutcome.notCounted);
  int get unanswered => _count(AnswerOutcome.unanswered);

  /// Respuestas que entran en los porcentajes.
  int get counted => correct + wrong + blank;

  /// Porcentajes sobre [counted]; 0 si no hay ninguna.
  double get correctPercent => _percent(correct);
  double get wrongPercent => _percent(wrong);
  double get blankPercent => _percent(blank);

  /// Falladas y en blanco, para «repasar estas». Sin anuladas.
  List<SummaryItem> get missed => [
    for (final item in items)
      if (item.outcome == AnswerOutcome.wrong ||
          item.outcome == AnswerOutcome.blank)
        item,
  ];

  /// Anuladas respondidas («no cuenta»).
  List<SummaryItem> get voided => [
    for (final item in items)
      if (item.outcome == AnswerOutcome.notCounted) item,
  ];

  int _count(AnswerOutcome outcome) =>
      items.where((i) => i.outcome == outcome).length;

  double _percent(int n) => counted == 0 ? 0 : n * 100 / counted;
}

class _TopicCounter {
  _TopicCounter(this.title);

  final String title;
  int correct = 0;
  int wrong = 0;
  int blank = 0;

  int get total => correct + wrong + blank;
}
