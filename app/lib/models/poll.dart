// =====================================================
// 📊 BMSChat — МОДЕЛЬ ГОЛОСОВАНИЯ
// =====================================================
// Соответствует объекту, который возвращает
// GET /api/polls/:id и другие роуты.
// =====================================================

class Poll {
    final int id;
    final int chatId;
    final int messageId;
    final int createdBy;
    final String question;
    final bool isMultiple;
    final bool isAnonymous;
    final bool isClosed;
    final DateTime createdAt;
    final DateTime? closedAt;
    final List<PollOption> options;
    final List<int> myVotes;
    final int totalVotes;
    final int distinctVoters;

    const Poll({
        required this.id,
        required this.chatId,
        required this.messageId,
        required this.createdBy,
        required this.question,
        required this.isMultiple,
        required this.isAnonymous,
        required this.isClosed,
        required this.createdAt,
        this.closedAt,
        this.options = const [],
        this.myVotes = const [],
        this.totalVotes = 0,
        this.distinctVoters = 0,
    });

    factory Poll.fromJson(Map<String, dynamic> json) {
        return Poll(
            id: json['id'] as int? ?? 0,
            chatId: json['chat_id'] as int? ?? 0,
            messageId: json['message_id'] as int? ?? 0,
            createdBy: json['created_by'] as int? ?? 0,
            question: json['question'] as String? ?? '',
            isMultiple: json['is_multiple'] == true,
            isAnonymous: json['is_anonymous'] == true,
            isClosed: json['is_closed'] == true,
            createdAt:
                _parseDate(json['created_at']) ?? DateTime.now(),
            closedAt: _parseDate(json['closed_at']),
            options: (json['options'] as List<dynamic>?)
                    ?.map((o) =>
                        PollOption.fromJson(o as Map<String, dynamic>))
                    .toList() ??
                [],
            myVotes: (json['my_votes'] as List<dynamic>?)
                    ?.map((v) => v as int)
                    .toList() ??
                [],
            totalVotes: json['total_votes'] as int? ?? 0,
            distinctVoters: json['distinct_voters'] as int? ?? 0,
        );
    }

    Map<String, dynamic> toJson() {
        return {
            'id': id,
            'chat_id': chatId,
            'message_id': messageId,
            'created_by': createdBy,
            'question': question,
            'is_multiple': isMultiple,
            'is_anonymous': isAnonymous,
            'is_closed': isClosed,
            'created_at': createdAt.toIso8601String(),
            'closed_at': closedAt?.toIso8601String(),
            'options': options.map((o) => o.toJson()).toList(),
            'my_votes': myVotes,
            'total_votes': totalVotes,
            'distinct_voters': distinctVoters,
        };
    }

    Poll copyWith({
        int? id,
        int? chatId,
        int? messageId,
        int? createdBy,
        String? question,
        bool? isMultiple,
        bool? isAnonymous,
        bool? isClosed,
        DateTime? createdAt,
        DateTime? closedAt,
        List<PollOption>? options,
        List<int>? myVotes,
        int? totalVotes,
        int? distinctVoters,
    }) {
        return Poll(
            id: id ?? this.id,
            chatId: chatId ?? this.chatId,
            messageId: messageId ?? this.messageId,
            createdBy: createdBy ?? this.createdBy,
            question: question ?? this.question,
            isMultiple: isMultiple ?? this.isMultiple,
            isAnonymous: isAnonymous ?? this.isAnonymous,
            isClosed: isClosed ?? this.isClosed,
            createdAt: createdAt ?? this.createdAt,
            closedAt: closedAt ?? this.closedAt,
            options: options ?? this.options,
            myVotes: myVotes ?? this.myVotes,
            totalVotes: totalVotes ?? this.totalVotes,
            distinctVoters: distinctVoters ?? this.distinctVoters,
        );
    }

    /// Проголосовал ли я за вариант с этим id
    bool hasMyVote(int optionId) => myVotes.contains(optionId);

    /// Проголосовал ли я вообще
    bool get hasVoted => myVotes.isNotEmpty;

    /// Максимальное количество голосов (для нормализации прогресс-бара)
    int get maxVotes {
        if (options.isEmpty) return 0;
        return options
            .map((o) => o.votesCount)
            .reduce((a, b) => a > b ? a : b);
    }

    static DateTime? _parseDate(dynamic value) {
        if (value == null) return null;
        if (value is DateTime) return value;
        if (value is String) return DateTime.tryParse(value);
        return null;
    }

    @override
    String toString() =>
        'Poll(id: $id, q: "$question", options: ${options.length}, votes: $totalVotes)';
}

// =====================================================
// 📋 ВАРИАНТ ОТВЕТА
// =====================================================

class PollOption {
    final int id;
    final String text;
    final int position;
    final int votesCount;
    final List<PollVoter>? voters; // null, если полл анонимный

    const PollOption({
        required this.id,
        required this.text,
        required this.position,
        this.votesCount = 0,
        this.voters,
    });

    factory PollOption.fromJson(Map<String, dynamic> json) {
        final rawVoters = json['voters'] as List<dynamic>?;

        return PollOption(
            id: json['id'] as int? ?? 0,
            text: json['text'] as String? ?? '',
            position: json['position'] as int? ?? 0,
            votesCount: json['votes_count'] as int? ?? 0,
            voters: rawVoters
                ?.map((v) => PollVoter.fromJson(v as Map<String, dynamic>))
                .toList(),
        );
    }

    Map<String, dynamic> toJson() {
        return {
            'id': id,
            'text': text,
            'position': position,
            'votes_count': votesCount,
            'voters': voters?.map((v) => v.toJson()).toList(),
        };
    }

    PollOption copyWith({
        int? id,
        String? text,
        int? position,
        int? votesCount,
        List<PollVoter>? voters,
    }) {
        return PollOption(
            id: id ?? this.id,
            text: text ?? this.text,
            position: position ?? this.position,
            votesCount: votesCount ?? this.votesCount,
            voters: voters ?? this.voters,
        );
    }
}

// =====================================================
// 👤 ГОЛОСОВАВШИЙ
// =====================================================

class PollVoter {
    final int userId;
    final String? displayName;
    final String? username;

    const PollVoter({
        required this.userId,
        this.displayName,
        this.username,
    });

    factory PollVoter.fromJson(Map<String, dynamic> json) {
        return PollVoter(
            userId: json['user_id'] as int? ?? 0,
            displayName: json['display_name'] as String?,
            username: json['username'] as String?,
        );
    }

    Map<String, dynamic> toJson() {
        return {
            'user_id': userId,
            'display_name': displayName,
            'username': username,
        };
    }

    String get shortName {
        final n = displayName ?? username ?? 'Пользователь';
        return n.length > 20 ? '${n.substring(0, 20)}…' : n;
    }
}