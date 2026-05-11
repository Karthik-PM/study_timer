import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/study_session.dart';
import '../models/subject_tag.dart';
import 'database_service.dart';

const _syncPort = 45321;

enum SyncMode { merge, getFromHost, sendToHost }

class SyncServer {
  HttpServer? _server;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, _syncPort);
    _server!.listen(_handle);
  }

  void stop() {
    _server?.close(force: true);
    _server = null;
  }

  bool get isRunning => _server != null;

  Future<void> _handle(HttpRequest req) async {
    req.response.headers.add('Access-Control-Allow-Origin', '*');
    req.response.headers.contentType = ContentType.json;

    try {
      if (req.method == 'GET' && req.uri.path == '/sessions') {
        final sessions = await DatabaseService.getSessions();
        final tags = await DatabaseService.getTags();
        req.response.write(jsonEncode({
          'sessions': sessions.map((s) => s.toMap()).toList(),
          'tags': tags.map((t) => t.toMap()).toList(),
        }));
      } else if (req.method == 'POST' && req.uri.path == '/sync') {
        final body = await utf8.decoder.bind(req).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final remoteSessions = (data['sessions'] as List)
            .map((m) => StudySession.fromMap(m as Map<String, dynamic>))
            .toList();
        final remoteTags = (data['tags'] as List)
            .map((m) => SubjectTag.fromMap(m as Map<String, dynamic>))
            .toList();
        final merged = await _merge(remoteSessions, remoteTags);
        req.response.write(jsonEncode(merged));
      } else if (req.method == 'POST' && req.uri.path == '/overwrite') {
        // Client is pushing its data to overwrite everything on the host
        final body = await utf8.decoder.bind(req).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final remoteSessions = (data['sessions'] as List)
            .map((m) => StudySession.fromMap(m as Map<String, dynamic>))
            .toList();
        final remoteTags = (data['tags'] as List)
            .map((m) => SubjectTag.fromMap(m as Map<String, dynamic>))
            .toList();
        await _overwrite(remoteSessions, remoteTags);
        req.response.write(jsonEncode({'ok': true}));
      } else {
        req.response.statusCode = 404;
        req.response.write('{"error":"not found"}');
      }
    } catch (e) {
      req.response.statusCode = 500;
      req.response.write(jsonEncode({'error': e.toString()}));
    }

    await req.response.close();
  }
}

Future<SyncResult> syncWithHost(String hostIp, SyncMode mode) async {
  final ip = hostIp.contains(':') ? hostIp.split(':').first : hostIp;
  final base = 'http://$ip:$_syncPort';

  switch (mode) {
    case SyncMode.merge:
      return _doMerge(base);
    case SyncMode.getFromHost:
      return _doGetFromHost(base);
    case SyncMode.sendToHost:
      return _doSendToHost(base);
  }
}

// Bidirectional merge — both devices end up with everything
Future<SyncResult> _doMerge(String base) async {
  final getResp = await http
      .get(Uri.parse('$base/sessions'))
      .timeout(const Duration(seconds: 10));
  if (getResp.statusCode != 200) throw Exception('Host unreachable');

  final hostData = jsonDecode(getResp.body) as Map<String, dynamic>;
  final hostSessions = (hostData['sessions'] as List)
      .map((m) => StudySession.fromMap(m as Map<String, dynamic>))
      .toList();
  final hostTags = (hostData['tags'] as List)
      .map((m) => SubjectTag.fromMap(m as Map<String, dynamic>))
      .toList();

  final mySessions = await DatabaseService.getSessions();
  final myTags = await DatabaseService.getTags();

  final postResp = await http
      .post(
        Uri.parse('$base/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessions': mySessions.map((s) => s.toMap()).toList(),
          'tags': myTags.map((t) => t.toMap()).toList(),
        }),
      )
      .timeout(const Duration(seconds: 15));

  if (postResp.statusCode != 200) throw Exception('Sync failed on host');

  final result = await _merge(hostSessions, hostTags);
  return SyncResult(
    sessionsAdded: result['sessionsAdded'] as int,
    tagsAdded: result['tagsAdded'] as int,
    mode: SyncMode.merge,
  );
}

// Pull — replace all local data with host's data
Future<SyncResult> _doGetFromHost(String base) async {
  final getResp = await http
      .get(Uri.parse('$base/sessions'))
      .timeout(const Duration(seconds: 10));
  if (getResp.statusCode != 200) throw Exception('Host unreachable');

  final hostData = jsonDecode(getResp.body) as Map<String, dynamic>;
  final hostSessions = (hostData['sessions'] as List)
      .map((m) => StudySession.fromMap(m as Map<String, dynamic>))
      .toList();
  final hostTags = (hostData['tags'] as List)
      .map((m) => SubjectTag.fromMap(m as Map<String, dynamic>))
      .toList();

  await _overwrite(hostSessions, hostTags);
  return SyncResult(
    sessionsAdded: hostSessions.length,
    tagsAdded: hostTags.length,
    mode: SyncMode.getFromHost,
  );
}

// Push — replace all host data with our data
Future<SyncResult> _doSendToHost(String base) async {
  final mySessions = await DatabaseService.getSessions();
  final myTags = await DatabaseService.getTags();

  final postResp = await http
      .post(
        Uri.parse('$base/overwrite'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessions': mySessions.map((s) => s.toMap()).toList(),
          'tags': myTags.map((t) => t.toMap()).toList(),
        }),
      )
      .timeout(const Duration(seconds: 15));

  if (postResp.statusCode != 200) throw Exception('Push failed on host');

  return SyncResult(
    sessionsAdded: 0,
    tagsAdded: 0,
    mode: SyncMode.sendToHost,
  );
}

Future<Map<String, dynamic>> _merge(
    List<StudySession> remoteSessions, List<SubjectTag> remoteTags) async {
  final existingIds =
      (await DatabaseService.getSessions()).map((s) => s.id).toSet();
  int sessionsAdded = 0;
  for (final s in remoteSessions) {
    if (!existingIds.contains(s.id)) {
      await DatabaseService.insertSession(s);
      sessionsAdded++;
    }
  }

  final existingTagIds =
      (await DatabaseService.getTags()).map((t) => t.id).toSet();
  int tagsAdded = 0;
  for (final t in remoteTags) {
    if (!existingTagIds.contains(t.id)) {
      await DatabaseService.insertTag(t);
      tagsAdded++;
    }
  }

  return {'sessionsAdded': sessionsAdded, 'tagsAdded': tagsAdded};
}

Future<void> _overwrite(
    List<StudySession> sessions, List<SubjectTag> tags) async {
  await DatabaseService.deleteAllSessions();
  await DatabaseService.deleteAllTags();
  for (final t in tags) {
    await DatabaseService.insertTag(t);
  }
  for (final s in sessions) {
    await DatabaseService.insertSession(s);
  }
}

class SyncResult {
  final int sessionsAdded;
  final int tagsAdded;
  final SyncMode mode;
  const SyncResult({
    required this.sessionsAdded,
    required this.tagsAdded,
    required this.mode,
  });
}
