import '../models/focus_session.dart';
import 'storage_service.dart';

class FocusRepository {
  static const String _fileName = 'focus_sessions.json';
  final StorageService _storage;

  FocusRepository({StorageService? storage})
      : _storage = storage ?? StorageService.instance;

  Future<List<FocusSession>> loadSessions() async {
    final data = await _storage.readJson(_fileName);
    if (data == null || data is! List) {
      return [];
    }
    return data.map((item) => FocusSession.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> saveSessions(List<FocusSession> sessions) async {
    final list = sessions.map((s) => s.toJson()).toList();
    await _storage.writeJson(_fileName, list);
  }

  Future<void> addSession(FocusSession session) async {
    final sessions = await loadSessions();
    sessions.insert(0, session);
    await saveSessions(sessions);
  }
}

