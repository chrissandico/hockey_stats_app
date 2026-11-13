import '../models/data_models.dart';

/// Canonical penalty types for voice commands. This mirrors the list in
/// LogPenaltyScreen (`_commonPenaltyTypes`); if that list changes, this one
/// must change with it — the parser can only accept types the screen can log.
const List<String> kVoicePenaltyTypes = [
  'Unknown',
  'Tripping',
  'Hooking',
  'Slashing',
  'Interference',
  'Roughing',
  'High-sticking',
  'Cross-checking',
  'Holding',
  'Delay of Game',
  'Unsportsmanlike Conduct',
  'Too Many Men',
  'Boarding',
  'Charging',
  'Elbowing',
  'Fighting',
  'Kneeing',
  'Spearing',
];

enum VoiceCommandKind {
  teamShot,
  opponentShot,
  playerShot,
  goal,
  penalty,
  undo,
}

/// A parsed voice command. Produced only from a transcript AND the current
/// roster: a jersey number that is not on the roster never appears here —
/// the parse is rejected instead (see [VoiceParseResult.rejectionReason]).
class VoiceCommand {
  final VoiceCommandKind kind;

  /// The shooter (playerShot), scorer (goal), or penalized player (penalty).
  final Player? player;
  final Player? assist1;
  final Player? assist2;

  /// Canonical penalty type, e.g. 'Tripping' (penalty only).
  final String? penaltyType;

  /// Penalty length in minutes (penalty only).
  final int? penaltyMinutes;

  /// Situation spoken as part of a goal command; null means "use the game's
  /// current situation" (goal only).
  final GoalSituation? situation;

  const VoiceCommand({
    required this.kind,
    this.player,
    this.assist1,
    this.assist2,
    this.penaltyType,
    this.penaltyMinutes,
    this.situation,
  });

  /// Plain-language rendering for the verify-before-logging card, in the
  /// app's own terms (jersey numbers, canonical penalty type, situation).
  String describe() {
    switch (kind) {
      case VoiceCommandKind.teamShot:
        return 'Team shot';
      case VoiceCommandKind.opponentShot:
        return 'Opponent shot';
      case VoiceCommandKind.playerShot:
        return 'Shot — #${player!.jerseyNumber}';
      case VoiceCommandKind.goal:
        final buffer = StringBuffer('Goal — #${player!.jerseyNumber}');
        final assists = [
          if (assist1 != null) '#${assist1!.jerseyNumber}',
          if (assist2 != null) '#${assist2!.jerseyNumber}',
        ];
        if (assists.isNotEmpty) {
          buffer.write(' · Assists ${assists.join(', ')}');
        }
        if (situation != null) {
          buffer.write(' · ${_situationLabel(situation!)}');
        }
        return buffer.toString();
      case VoiceCommandKind.penalty:
        return 'Penalty — #${player!.jerseyNumber} · $penaltyType · '
            '$penaltyMinutes min';
      case VoiceCommandKind.undo:
        return 'Undo — delete the last logged event';
    }
  }

  static String _situationLabel(GoalSituation situation) {
    switch (situation) {
      case GoalSituation.powerPlay:
        return 'Power play';
      case GoalSituation.shortHanded:
        return 'Short handed';
      case GoalSituation.evenStrength:
        return 'Even strength';
    }
  }
}

/// The result of parsing one transcript: either a [command] to verify with
/// the keeper, or a [rejectionReason] explaining why nothing was parsed.
class VoiceParseResult {
  final VoiceCommand? command;
  final String? rejectionReason;

  const VoiceParseResult._({this.command, this.rejectionReason});

  factory VoiceParseResult.parsed(VoiceCommand command) =>
      VoiceParseResult._(command: command);

  factory VoiceParseResult.rejected(String reason) =>
      VoiceParseResult._(rejectionReason: reason);

  bool get isSuccess => command != null;
}

class _HeardNumber {
  final int value;
  final int start; // first token index
  final int end; // one past the last token index
  const _HeardNumber(this.value, this.start, this.end);
}

/// Parses speech transcripts into [VoiceCommand]s against a fixed grammar:
/// a small verb set, jersey numbers **from the roster only**, the app's
/// penalty types, and goal situations. Anything outside the grammar is a
/// rejection with a plain-language reason — never a guess. Pure and
/// synchronous so the whole grammar is unit-testable.
class VoiceCommandParser {
  final Map<int, Player> _byJersey;

  VoiceCommandParser(List<Player> roster)
      : _byJersey = {for (final p in roster) p.jerseyNumber: p};

  static const Map<String, int> _ones = {
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
  };

  static const Map<String, int> _tens = {
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
  };

  /// Spoken penalty phrases → canonical type. Longest phrases are matched
  /// first so e.g. "too many men" wins over any shorter overlap.
  static final Map<String, String> _penaltyPhrases = () {
    final map = <String, String>{};
    for (final type in kVoicePenaltyTypes) {
      map[type.toLowerCase().replaceAll('-', ' ')] = type;
    }
    map['unsportsmanlike'] = 'Unsportsmanlike Conduct';
    return map;
  }();

  VoiceParseResult parse(String transcript) {
    final tokens = _tokenize(transcript);
    if (tokens.isEmpty) {
      return VoiceParseResult.rejected('Nothing was heard.');
    }

    // Undo: "undo", "undo last", "delete last event", …
    if (tokens.first == 'undo' ||
        (tokens.first == 'delete' && tokens.contains('last'))) {
      return VoiceParseResult.parsed(
          const VoiceCommand(kind: VoiceCommandKind.undo));
    }

    // Opponent events: only their shot is a voice command in v1.
    if (tokens.contains('opponent') || tokens.contains('their')) {
      if (tokens.contains('shot')) {
        return VoiceParseResult.parsed(
            const VoiceCommand(kind: VoiceCommandKind.opponentShot));
      }
      if (tokens.contains('goal')) {
        return VoiceParseResult.rejected(
            'Opponent goals are logged from the Log Shot screen for now.');
      }
      return VoiceParseResult.rejected(_didNotUnderstand());
    }

    if (tokens.first == 'goal') return _parseGoal(tokens);
    if (tokens.first == 'penalty') return _parsePenalty(tokens);
    if (tokens.contains('shot')) return _parseShot(tokens);

    return VoiceParseResult.rejected(_didNotUnderstand());
  }

  VoiceParseResult _parseShot(List<String> tokens) {
    final numbers = _extractNumbers(tokens);
    if (numbers.isEmpty) {
      return VoiceParseResult.parsed(
          const VoiceCommand(kind: VoiceCommandKind.teamShot));
    }
    if (numbers.length > 1) {
      return VoiceParseResult.rejected(
          'Heard more than one number for a shot — say just the shooter, '
          'like "Shot 25".');
    }
    final player = _rosterPlayer(numbers.single.value);
    if (player == null) {
      return VoiceParseResult.rejected(
          '#${numbers.single.value} is not on the roster.');
    }
    return VoiceParseResult.parsed(
        VoiceCommand(kind: VoiceCommandKind.playerShot, player: player));
  }

  VoiceParseResult _parseGoal(List<String> tokens) {
    // Situation phrases may appear anywhere in the command.
    GoalSituation? situation;
    final consumed = <int>{};
    for (var i = 0; i + 1 < tokens.length; i++) {
      final pair = '${tokens[i]} ${tokens[i + 1]}';
      if (pair == 'power play') {
        situation = GoalSituation.powerPlay;
        consumed.addAll([i, i + 1]);
      } else if (pair == 'short handed') {
        situation = GoalSituation.shortHanded;
        consumed.addAll([i, i + 1]);
      } else if (pair == 'even strength') {
        situation = GoalSituation.evenStrength;
        consumed.addAll([i, i + 1]);
      }
    }
    if (tokens.contains('shorthanded')) {
      situation = GoalSituation.shortHanded;
    }

    final numbers = _extractNumbers(tokens)
        .where((n) => !consumed.contains(n.start))
        .toList();

    // Numbers after an assist marker ("assist", "assists", "assisted by")
    // are assists; the first number before it is the scorer. With no marker
    // at all ("goal 25 88"), numbers after the scorer are still read as
    // assists — silently dropping them cost a keeper an assist in the field
    // (2026-11-13: "assisted" wasn't a recognized marker, so the scorer
    // logged and every assist vanished).
    const assistMarkers = {'assist', 'assists', 'assisted', 'assisting'};
    final assistIndex = tokens.indexWhere(assistMarkers.contains);
    final List<_HeardNumber> scorerNumbers;
    final List<_HeardNumber> assistNumbers;
    if (assistIndex == -1) {
      scorerNumbers = numbers.take(1).toList();
      assistNumbers = numbers.skip(1).toList();
    } else {
      scorerNumbers = numbers.where((n) => n.start < assistIndex).toList();
      assistNumbers = numbers.where((n) => n.start > assistIndex).toList();
    }

    if (scorerNumbers.isEmpty) {
      return VoiceParseResult.rejected(
          'Didn\'t hear who scored — say "Goal" then the scorer\'s number.');
    }
    final scorer = _rosterPlayer(scorerNumbers.first.value);
    if (scorer == null) {
      return VoiceParseResult.rejected(
          '#${scorerNumbers.first.value} is not on the roster.');
    }
    if (assistNumbers.length > 2) {
      return VoiceParseResult.rejected(
          'Heard more than two assists — a goal has at most two.');
    }
    final assists = <Player>[];
    for (final heard in assistNumbers) {
      final player = _rosterPlayer(heard.value);
      if (player == null) {
        return VoiceParseResult.rejected(
            '#${heard.value} is not on the roster.');
      }
      if (player.id == scorer.id) {
        return VoiceParseResult.rejected(
            'The scorer can\'t assist on their own goal.');
      }
      if (assists.any((a) => a.id == player.id)) {
        return VoiceParseResult.rejected(
            '#${heard.value} was heard as both assists.');
      }
      assists.add(player);
    }

    return VoiceParseResult.parsed(VoiceCommand(
      kind: VoiceCommandKind.goal,
      player: scorer,
      assist1: assists.isNotEmpty ? assists[0] : null,
      assist2: assists.length > 1 ? assists[1] : null,
      situation: situation,
    ));
  }

  VoiceParseResult _parsePenalty(List<String> tokens) {
    final numbers = _extractNumbers(tokens);

    // A number directly followed by "minute(s)"/"min" is the duration;
    // the first other number is the player.
    _HeardNumber? durationNumber;
    for (final n in numbers) {
      if (n.end < tokens.length &&
          (tokens[n.end] == 'minutes' ||
              tokens[n.end] == 'minute' ||
              tokens[n.end] == 'min' ||
              tokens[n.end] == 'mins')) {
        durationNumber = n;
      }
    }
    final playerNumbers =
        numbers.where((n) => n != durationNumber).toList();

    // Penalty type: longest spoken phrase that appears in the transcript.
    String? penaltyType;
    var bestLength = 0;
    final joined = tokens.join(' ');
    _penaltyPhrases.forEach((phrase, canonical) {
      if (phrase.length > bestLength && joined.contains(phrase)) {
        penaltyType = canonical;
        bestLength = phrase.length;
      }
    });

    if (playerNumbers.isEmpty) {
      return VoiceParseResult.rejected(
          'Didn\'t hear who took the penalty — say "Penalty" then the '
          'player\'s number.');
    }
    final player = _rosterPlayer(playerNumbers.first.value);
    if (player == null) {
      return VoiceParseResult.rejected(
          '#${playerNumbers.first.value} is not on the roster.');
    }
    if (penaltyType == null) {
      return VoiceParseResult.rejected(
          'Didn\'t hear the penalty type — say it like "tripping" or '
          '"hooking".');
    }
    if (durationNumber == null) {
      return VoiceParseResult.rejected(
          'Didn\'t hear the penalty length — end with "2 minutes".');
    }

    return VoiceParseResult.parsed(VoiceCommand(
      kind: VoiceCommandKind.penalty,
      player: player,
      penaltyType: penaltyType,
      penaltyMinutes: durationNumber.value,
    ));
  }

  Player? _rosterPlayer(int jerseyNumber) => _byJersey[jerseyNumber];

  static String _didNotUnderstand() => 'Didn\'t understand that — try '
      '"Shot 25", "Goal 25, assists 88 and 49", or '
      '"Penalty 12, tripping, 2 minutes".';

  static List<String> _tokenize(String transcript) {
    final normalized = transcript
        .toLowerCase()
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r"[^a-z0-9\s]"), ' ');
    return normalized
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Finds every number in the token stream, whether spoken as digits
  /// ("25") or words ("twenty five" / "twenty-five", already split on the
  /// hyphen by [_tokenize]).
  static List<_HeardNumber> _extractNumbers(List<String> tokens) {
    final result = <_HeardNumber>[];
    var i = 0;
    while (i < tokens.length) {
      final token = tokens[i];
      if (RegExp(r'^\d+$').hasMatch(token)) {
        result.add(_HeardNumber(int.parse(token), i, i + 1));
        i++;
        continue;
      }
      if (_tens.containsKey(token)) {
        var value = _tens[token]!;
        var end = i + 1;
        if (end < tokens.length) {
          final next = _ones[tokens[end]];
          if (next != null && next > 0 && next < 10) {
            value += next;
            end++;
          }
        }
        result.add(_HeardNumber(value, i, end));
        i = end;
        continue;
      }
      if (_ones.containsKey(token)) {
        result.add(_HeardNumber(_ones[token]!, i, i + 1));
        i++;
        continue;
      }
      i++;
    }
    return result;
  }
}
