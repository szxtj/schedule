import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/date_utils.dart';
import '../models/focus_session.dart';
import '../repositories/focus_repository.dart';

final focusRepositoryProvider = Provider<FocusRepository>((ref) {
  return FocusRepository();
});

class FocusSessionNotifier extends StateNotifier<List<FocusSession>> {
  final FocusRepository _repository;

  FocusSessionNotifier(this._repository) : super([]) {
    _load();
  }

  Future<void> _load() async {
    final sessions = await _repository.loadSessions();
    if (!mounted) return;
    state = sessions;
  }

  Future<void> reload() async => _load();

  Future<void> logSession(FocusSession session) async {
    await _repository.addSession(session);
    state = [session, ...state];
  }

  /// 获取指定日期的总专注时长（秒）
  int getTotalFocusSecondsForDate(String dateKey) {
    return state
        .where((s) => s.dateKey == dateKey)
        .fold(0, (sum, s) => sum + s.actualDurationSeconds);
  }
}

final focusSessionsProvider =
    StateNotifierProvider<FocusSessionNotifier, List<FocusSession>>((ref) {
      final repo = ref.watch(focusRepositoryProvider);
      return FocusSessionNotifier(repo);
    });

/// 获取今日已完成专注记录的总专注秒数
final todayTotalFocusSecondsProvider = Provider<int>((ref) {
  final sessions = ref.watch(focusSessionsProvider);
  final todayKey = AppDateUtils.todayKey();
  return sessions
      .where((s) => s.dateKey == todayKey)
      .fold(0, (sum, s) => sum + s.actualDurationSeconds);
});
