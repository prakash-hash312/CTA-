
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_services.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODELS
// ══════════════════════════════════════════════════════════════════════════════

class _Topic {
  final int id;
  final String title;
  final List<_Lesson> lessons;
  const _Topic({required this.id, required this.title, this.lessons = const []});
  _Topic copyWith({List<_Lesson>? lessons}) =>
      _Topic(id: id, title: title, lessons: lessons ?? this.lessons);
}

class _SyllabusSection {
  final int id;
  final String title;
  final String description;
  final String gradeName;
  final String status;
  final String syllabusType;
  final String coverUrl;
  final List<_Topic> topics;

  const _SyllabusSection({
    required this.id,
    required this.title,
    this.description = '',
    this.gradeName = '',
    this.status = '',
    this.syllabusType = '',
    this.coverUrl = '',
    this.topics = const [],
  });

  bool get hasNestedTopics => topics.isNotEmpty;

  _SyllabusSection copyWith({List<_Topic>? topics}) => _SyllabusSection(
        id: id,
        title: title,
        description: description,
        gradeName: gradeName,
        status: status,
        syllabusType: syllabusType,
        coverUrl: coverUrl,
        topics: topics ?? this.topics,
      );
}

class _Lesson {
  final int id;
  final String title;
  final String contentType;
  final String rawHtml;
  final List<String> imageUrls;
  final List<String> linkUrls;
  final bool needsFetch;

  const _Lesson({
    required this.id,
    required this.title,
    this.contentType = 'content',
    this.rawHtml = '',
    this.imageUrls = const [],
    this.linkUrls = const [],
    this.needsFetch = false,
  });

  bool get hasHtml => rawHtml.trim().isNotEmpty;
  bool get hasImages => imageUrls.isNotEmpty;
  bool get hasLinks => linkUrls.isNotEmpty;
  bool get hasContent => hasHtml || hasImages || hasLinks;

  _Lesson copyWith({
    String? contentType,
    String? rawHtml,
    List<String>? imageUrls,
    List<String>? linkUrls,
    bool? needsFetch,
  }) =>
      _Lesson(
        id: id,
        title: title,
        contentType: contentType ?? this.contentType,
        rawHtml: rawHtml ?? this.rawHtml,
        imageUrls: imageUrls ?? this.imageUrls,
        linkUrls: linkUrls ?? this.linkUrls,
        needsFetch: needsFetch ?? this.needsFetch,
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// CACHE
// ══════════════════════════════════════════════════════════════════════════════

class _Cache {
  static final Map<int, Future<List<Map<String, dynamic>>>> grade = {};
  static final Map<int, Future<List<Map<String, dynamic>>>> topic = {};
  static final Map<int, Future<List<Map<String, dynamic>>>> subTopic = {};
  static final Map<int, Future<List<Map<String, dynamic>>>> content = {};

  static Future<List<Map<String, dynamic>>> get({
    required int key,
    required Map<int, Future<List<Map<String, dynamic>>>> map,
    required Future<List<Map<String, dynamic>>> Function() loader,
  }) =>
      map.putIfAbsent(key, loader);
}

// ══════════════════════════════════════════════════════════════════════════════
// URL UTILITIES
// ══════════════════════════════════════════════════════════════════════════════

bool _isHttp(String v) {
  final s = v.trim().toLowerCase();
  return s.startsWith('http://') || s.startsWith('https://');
}

bool _isImage(String url) {
  final u = url.toLowerCase().split('?').first;
  return u.endsWith('.jpg') ||
      u.endsWith('.jpeg') ||
      u.endsWith('.png') ||
      u.endsWith('.gif') ||
      u.endsWith('.webp') ||
      u.endsWith('.bmp') ||
      u.endsWith('.svg');
}

bool _isDocument(String url) {
  final u = url.toLowerCase().split('?').first;
  return u.endsWith('.pdf') ||
      u.endsWith('.doc') ||
      u.endsWith('.docx') ||
      u.endsWith('.ppt') ||
      u.endsWith('.pptx') ||
      u.endsWith('.xls') ||
      u.endsWith('.xlsx') ||
      u.endsWith('.txt');
}

bool _isBroken(String url) {
  final l = url.toLowerCase();
  return l.endsWith('/homeworkfiles') ||
      l.endsWith('/homeworkfiles/') ||
      l.endsWith('/cta_mob/homeworkfiles') ||
      l.endsWith('/cta_mob/homeworkfiles/') ||
      l.contains('servererror');
}

String _normalise(String raw) {
  var s = raw
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('%2F', '/')
      .trim();
  if ((s.startsWith('"') && s.endsWith('"')) ||
      (s.startsWith("'") && s.endsWith("'"))) {
    s = s.substring(1, s.length - 1);
  }
  if (s.isEmpty) return '';
  final l = s.toLowerCase();
  if (l.startsWith('http://') || l.startsWith('https://')) return s;
  if (s.startsWith('//')) return 'https:$s';
  if (s.startsWith('~/')) return 'https://www.ivpsemi.in/${s.substring(2)}';
  if (s.startsWith('/')) return 'https://www.ivpsemi.in$s';
  if (l.startsWith('cta_mob/') || l.startsWith('homeworkfiles/'))
    return 'https://www.ivpsemi.in/$s';
  if (l.startsWith('www.')) return 'https://$s';
  return s;
}

List<String> _extractUrls(String raw) {
  if (raw.trim().isEmpty) return [];
  final out = <String>{};

  for (final m in RegExp(r"""https?://[^\s"'<>\)]+""", caseSensitive: false)
      .allMatches(raw)) {
    final u = _normalise(m.group(0)!);
    if (_isHttp(u) && !_isBroken(u)) out.add(u);
  }
  for (final m in RegExp(r"""(?:href|src)\s*=\s*["']([^"']+)["']""",
          caseSensitive: false)
      .allMatches(raw)) {
    final u = _normalise(m.group(1)!);
    if (_isHttp(u) && !_isBroken(u)) out.add(u);
  }
  for (final m in RegExp(r"""(?:CTA_Mob/)?HomeworkFiles/[^\s"'<>]+""",
          caseSensitive: false)
      .allMatches(raw)) {
    final u = _normalise(m.group(0)!);
    if (_isHttp(u) && !_isBroken(u)) out.add(u);
  }
  return out.toList();
}

String? _homeworkUrl(String fileName) {
  final f = fileName.replaceAll('\\', '/').trim();
  if (f.isEmpty ||
      f.toLowerCase().startsWith('d:') ||
      f.toLowerCase().startsWith('c:')) return null;
  final name = f.split('/').last.split('?').first.trim();
  if (name.isEmpty) return null;
  return 'https://www.ivpsemi.in/CTA_Mob/HomeworkFiles/${Uri.encodeComponent(name)}';
}

String? _homeworkAlt(String fileName) {
  final f = fileName.replaceAll('\\', '/').trim();
  if (f.isEmpty ||
      f.toLowerCase().startsWith('d:') ||
      f.toLowerCase().startsWith('c:')) return null;
  final name = f.split('/').last.split('?').first.trim();
  if (name.isEmpty) return null;
  return 'https://www.ivpsemi.in/HomeworkFiles/${Uri.encodeComponent(name)}';
}

// ══════════════════════════════════════════════════════════════════════════════
// CONTENT ROW → _Lesson
// ══════════════════════════════════════════════════════════════════════════════

_Lesson _mapContentRow(
  Map<String, dynamic> row, {
  required int subSubTopicId,
  required String subSubTitle,
}) {
  debugPrint('📄 Content row keys : ${row.keys.toList()}');
  debugPrint('📄 Content row values: $row');

  final type =
      (row['ContentType'] ?? row['content_type'] ?? 'content').toString().toLowerCase().trim();

  final rawHtml = _firstNonEmpty(row, [
    'ContentHtml', 'content_html', 'Html', 'html',
    'Content', 'content', 'Body', 'body',
    'Description', 'description',
    'HSCPDataContent', 'HscpDataContent', 'DataContent', 'data_content',
  ]);

  final iframeRaw =
      _firstNonEmpty(row, ['IframeUrl', 'iframe_url', 'VideoUrl', 'video_url']);
  final rendRaw = _firstNonEmpty(
      row, ['RenderedContent', 'rendered_content', 'Rendered', 'rendered']);
  final fileRaw = _firstNonEmpty(
      row, ['FileName', 'file_name', 'File', 'file', 'FilePath', 'file_path']);
  final urlRaw = _firstNonEmpty(row, [
    'Url', 'url', 'Link', 'link', 'Path', 'path',
    'HSCPUrl', 'HscpUrl', 'ContentUrl', 'content_url',
  ]);

  final candidates = <String>{};

  for (final raw in [iframeRaw, rendRaw, urlRaw]) {
    if (raw.isEmpty) continue;
    final n = _normalise(raw);
    if (_isHttp(n) && !_isBroken(n)) candidates.add(n);
    candidates.addAll(_extractUrls(raw));
  }
  if (fileRaw.isNotEmpty) {
    final p = _homeworkUrl(fileRaw);
    final a = _homeworkAlt(fileRaw);
    if (p != null) candidates.add(p);
    if (a != null) candidates.add(a);
  }
  if (rawHtml.isNotEmpty) candidates.addAll(_extractUrls(rawHtml));

  final images = candidates.where(_isImage).toList();
  final links = candidates.where((u) => !_isImage(u)).toList();

  debugPrint('📄 id=$subSubTopicId type=$type '
      'images=${images.length} links=${links.length}');

  return _Lesson(
    id: subSubTopicId,
    title: subSubTitle,
    contentType: type,
    rawHtml: rawHtml,
    imageUrls: images,
    linkUrls: links,
    needsFetch: false,
  );
}

_Lesson _mergeContentRows(
  List<Map<String, dynamic>> rows, {
  required int subSubTopicId,
  required String subSubTitle,
}) {
  if (rows.isEmpty) {
    return _Lesson(id: subSubTopicId, title: subSubTitle, needsFetch: false);
  }

  final lessons = rows.map((row) => _mapContentRow(
        row,
        subSubTopicId: subSubTopicId,
        subSubTitle: subSubTitle,
      ));

  final htmlParts = <String>[];
  final imageUrls = <String>{};
  final linkUrls = <String>{};
  String contentType = 'content';

  for (final lesson in lessons) {
    if (lesson.rawHtml.trim().isNotEmpty) {
      htmlParts.add(lesson.rawHtml.trim());
    }
    imageUrls.addAll(lesson.imageUrls);
    linkUrls.addAll(lesson.linkUrls);
    if (htmlParts.isEmpty &&
        contentType == 'content' &&
        lesson.contentType.trim().isNotEmpty) {
      contentType = lesson.contentType;
    }
  }

  return _Lesson(
    id: subSubTopicId,
    title: subSubTitle,
    contentType: contentType,
    rawHtml: htmlParts.join('<br/><br/>'),
    imageUrls: imageUrls.toList(),
    linkUrls: linkUrls.toList(),
    needsFetch: false,
  );
}

String _firstNonEmpty(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v != null && '$v'.trim().isNotEmpty) return '$v'.trim();
  }
  return '';
}

// ══════════════════════════════════════════════════════════════════════════════
// HTML INLINE WEBVIEW
// ══════════════════════════════════════════════════════════════════════════════

class _HtmlView extends StatefulWidget {
  final String html;
  final Future<void> Function(String) onOpen;
  const _HtmlView({required this.html, required this.onOpen});
  @override
  State<_HtmlView> createState() => _HtmlViewState();
}

class _HtmlViewState extends State<_HtmlView> {
  double _h = 300;
  InAppWebViewController? _ctrl;

  String get _doc => '''<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<style>
html,body{margin:0;padding:0;background:transparent;overflow-x:hidden;width:100%}
body{color:#1f2937;padding:10px 12px 14px;box-sizing:border-box;-webkit-text-size-adjust:100%}
*,*::before,*::after{box-sizing:border-box}
img,video,iframe,canvas{max-width:100%!important;height:auto!important}
table{width:100%!important;max-width:100%!important;border-collapse:collapse!important}
td,th{white-space:normal!important;word-break:break-word!important;vertical-align:top;padding:4px 6px}
p,li,h1,h2,h3,h4,h5,h6,span,div{word-break:break-word;overflow-wrap:anywhere}
ul,ol{padding-left:20px!important}
a{color:#1E429F;word-break:break-all}
</style>
<script>
function fix(){
  document.querySelectorAll('a,button').forEach(el=>{
    const txt=(el.innerText||el.textContent||'').trim().toLowerCase();
    if(txt==='open content'||txt==='alt link'){el.remove();}
  });
  document.querySelectorAll('*').forEach(n=>{n.style.maxWidth='100%'});
  document.querySelectorAll('table').forEach(t=>{t.removeAttribute('width');t.style.width='100%'});
}
document.addEventListener('DOMContentLoaded',fix);
window.addEventListener('load',fix);
</script>
</head><body>${widget.html}</body></html>''';

  Future<void> _sync(InAppWebViewController c) async {
    final r = await c.evaluateJavascript(
        source:
            'Math.max(document.body.scrollHeight,document.documentElement.scrollHeight).toString()');
    final h = double.tryParse('$r');
    if (h != null && h > 0 && mounted) setState(() => _h = h + 24);
  }

  @override
  void didUpdateWidget(_HtmlView old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html) {
      _h = 300;
      _ctrl?.loadData(
        data: _doc,
        baseUrl: WebUri('https://www.ivpsemi.in/CTA_Mob/'),
        mimeType: 'text/html',
        encoding: 'utf-8',
      );
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: _h,
        child: InAppWebView(
          initialSettings: InAppWebViewSettings(
            transparentBackground: true,
            disableVerticalScroll: true,
            disableHorizontalScroll: true,
            javaScriptEnabled: true,
            useWideViewPort: true,
            loadWithOverviewMode: true,
            supportZoom: false,
          ),
          initialData: InAppWebViewInitialData(
            data: _doc,
            baseUrl: WebUri('https://www.ivpsemi.in/CTA_Mob/'),
            mimeType: 'text/html',
            encoding: 'utf-8',
          ),
          onWebViewCreated: (c) => _ctrl = c,
          onLoadStop: (c, _) async {
            await _sync(c);
            await Future.delayed(const Duration(milliseconds: 300));
            await _sync(c);
          },
          shouldOverrideUrlLoading: (_, action) async {
            final url = action.request.url?.toString() ?? '';
            if (_isHttp(url)) {
              await widget.onOpen(url);
              return NavigationActionPolicy.CANCEL;
            }
            return NavigationActionPolicy.ALLOW;
          },
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class StudentSyllabusScreen extends StatefulWidget {
  const StudentSyllabusScreen({super.key});
  @override
  State<StudentSyllabusScreen> createState() => _StudentSyllabusScreenState();
}

class _StudentSyllabusScreenState extends State<StudentSyllabusScreen> {
  static const _navy = Color(0xFF0D1F4C);
  static const _blue = Color(0xFF1E429F);
  static const _sky = Color(0xFF2F80ED);
  static const _bg = Color(0xFFF6F7FB);

  bool _loading = true;
  String? _error;
  String _gradeTitle = 'Student Syllabus';
  int? _activeStudId;
  List<_SyllabusSection> _sections = [];
  int _mainId = 0;
  List<_Topic> _topics = [];
  int? _selTopicId;
  int? _selLessonId;
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    apiService.loadSession().then((_) {
      if (!mounted) return;
      _load();
    });
  }

  bool get _useHscpSectionView {
    // For some student accounts TopicInfo returns empty (API limitation/data),
    // but GradeInfo still returns valid "sections" with cover images.
    // In that case show the section grid UI (like stud_id=17399).
    const hscpSectionStudIds = {17399, 14618, 20674};
    return (_activeStudId != null && hscpSectionStudIds.contains(_activeStudId)) ||
        (_sections.isNotEmpty && _topics.isEmpty);
  }

  // ── key helpers ──────────────────────────────────────────────────────────────
  int _int(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final p = int.tryParse('$v');
      if (p != null && p > 0) return p;
    }
    for (final e in m.entries) {
      for (final k in keys) {
        if (e.key.toLowerCase().contains(k.toLowerCase())) {
          final p = int.tryParse('${e.value}');
          if (p != null && p > 0) return p;
        }
      }
    }
    return 0;
  }

  String _str(Map<String, dynamic> m, List<String> keys, {String fb = ''}) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && '$v'.trim().isNotEmpty) return '$v'.trim();
    }
    return fb;
  }

  String _coverUrl(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '';
    final normalized = v.replaceAll('\\', '/');
    if (_isHttp(normalized)) return normalized;
    if (normalized.startsWith('/')) return 'https://www.ivpsemi.in$normalized';
    final lower = normalized.toLowerCase();
    final idx = lower.indexOf('hw_coverimages/');
    if (idx >= 0) {
      return 'https://www.ivpsemi.in/${normalized.substring(idx)}';
    }
    return '';
  }

  // ── FIXED _load() ────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _activeStudId = null;
      _sections = [];
      _topics = [];
      _selTopicId = null;
      _selLessonId = null;
      _expanded.clear();
    });

    try {
      // ── STEP 1: Resolve student ID ─────────────────────────────────────────
      // 🔑 FIX: For accounts like ita_41974 whose ViewProfile API returns 500,
      // ensureCurrentStudentId() returns null. Instead of throwing immediately
      // we try 4 fallback levels before giving up:
      //   a) ensureCurrentStudentId()  — tries profile + homework APIs
      //   b) currentStudentId          — already-cached value from session
      //   c) currentUserId             — the id from the login response
      //   d) StudentHomeWork API       — confirm userId works as stud_id

      int? studId = await apiService.ensureCurrentStudentId();

      if (studId == null || studId <= 0) {
        studId = apiService.currentStudentId;
        debugPrint('⚠️ [Syllabus] ensureCurrentStudentId returned null, '
            'trying currentStudentId=$studId');
      }

      if (studId == null || studId <= 0) {
        studId = apiService.currentUserId;
        debugPrint('⚠️ [Syllabus] Falling back to currentUserId=$studId');
      }

      // Last resort: call StudentHomeWork with userId to confirm it's valid
      if ((studId == null || studId <= 0) && apiService.currentUserId != null) {
        try {
          final hwRows =
              await apiService.fetchStudentHomeWork(studId: apiService.currentUserId);
          if (hwRows.isNotEmpty) {
            studId = apiService.currentUserId;
            debugPrint('✅ [Syllabus] Confirmed userId=$studId works as stud_id '
                'via StudentHomeWork');
          }
        } catch (e) {
          debugPrint('⚠️ [Syllabus] StudentHomeWork fallback failed: $e');
        }
      }

      if (studId == null || studId <= 0) {
        throw Exception(
            'Could not identify your student account.\n'
            'Please log out and log in again.\n'
            'If the issue persists, contact your administrator.');
      }

      debugPrint('👤 [Syllabus] Using studId=$studId');
      _activeStudId = studId;

      // ── STEP 2: GradeInfo ──────────────────────────────────────────────────
      final gradeRows = await _Cache.get(
        key: studId,
        map: _Cache.grade,
        loader: () => apiService.fetchSyllabusGradeInfo(studId: studId!),
      );
      debugPrint('📚 GradeInfo: ${gradeRows.length} rows');

      // 🔑 FIX: If GradeInfo is empty for resolved studId, retry with
      // currentUserId — some accounts store syllabus under a different id.
      if (gradeRows.isEmpty) {
        final altId = apiService.currentUserId;
        if (altId != null && altId > 0 && altId != studId) {
          debugPrint('⚠️ [Syllabus] GradeInfo empty for studId=$studId, '
              'retrying with userId=$altId');
          final altRows =
              await apiService.fetchSyllabusGradeInfo(studId: altId);
          if (altRows.isNotEmpty) {
            _activeStudId = altId;
            studId = altId;
            _Cache.grade[altId] = Future.value(altRows);
            gradeRows.addAll(altRows);
          }
        }
      }

      if (gradeRows.isEmpty) {
        throw Exception(
            'No syllabus records found for your account.\n'
            'Please contact your administrator.');
      }

      debugPrint('📚 keys=${gradeRows.first.keys.toList()}');
      _gradeTitle = _str(
        gradeRows.first,
        ['grade_name', 'GradeName', 'Title', 'title'],
        fb: 'Student Syllabus',
      );

      // ── STEP 3: Build sections ─────────────────────────────────────────────
      final sections = <_SyllabusSection>[];
      for (final g in gradeRows) {
        final mainId = _int(g, [
          'MainTopicID', 'main_topic_id', 'MainID', 'main_id',
          'GradeID', 'grade_id', 'ID', 'id'
        ]);
        if (mainId == 0) continue;
        _mainId = _mainId == 0 ? mainId : _mainId;

        final sectionTitle = _str(g, [
          'Title',
          'title',
          'Name',
          'name',
          'SyllabusName',
          'syllabus_name',
        ], fb: 'Syllabus $mainId');
        final sectionDesc = _str(g, ['Description', 'description']);
        final sectionGrade =
            _str(g, ['grade_name', 'GradeName'], fb: _gradeTitle);
        final sectionStatus =
            _str(g, ['syllabus_status', 'status'], fb: 'Not Yet');
        final sectionType =
            _str(g, ['syllabus_type', 'SyllabusType'], fb: 'Student');
        final cover =
            _coverUrl(_str(g, [
          'CoverUrl',
          'cover_image',
          'coverUrl',
          'Cover_Image',
          'cover',
          'image',
          'ImageUrl',
          'image_url',
        ]));

        final topicRows = await _Cache.get(
          key: (studId * 1000000) + mainId,
          map: _Cache.topic,
          loader: () =>
              apiService.fetchSyllabusTopicInfo(mainId: mainId, studId: studId!),
        );
        // Some accounts store topics under a different identifier than the
        // stud_id used for GradeInfo. If TopicInfo comes back empty, retry with
        // user/emp ids (similar to GradeInfo fallback).
        if (topicRows.isEmpty) {
          final altCandidates = <int>{
            if (apiService.currentUserId != null && apiService.currentUserId! > 0)
              apiService.currentUserId!,
            if (apiService.currentEmpId != null && apiService.currentEmpId! > 0)
              apiService.currentEmpId!,
          }.where((id) => id != studId).toList();

          for (final altId in altCandidates) {
            debugPrint(
                '⚠️ [Syllabus] TopicInfo empty for mainId=$mainId studId=$studId, retrying with altId=$altId');
            final altRows =
                await apiService.fetchSyllabusTopicInfo(mainId: mainId, studId: altId);
            if (altRows.isNotEmpty) {
              topicRows.addAll(altRows);
              _Cache.topic[(altId * 1000000) + mainId] = Future.value(altRows);
              break;
            }
          }
        }
        final topics = <_Topic>[];

        for (final t in topicRows) {
          final subTopicId = _int(t, [
            'SubTopicID', 'sub_topic_id', 'TopicID', 'topic_id', 'ID', 'id'
          ]);
          if (subTopicId == 0) continue;
          final topicTitle =
              _str(t, ['Title', 'title', 'Name', 'name'], fb: 'Topic $subTopicId');

          final subRows = await _Cache.get(
            key: subTopicId,
            map: _Cache.subTopic,
            loader: () =>
                apiService.fetchSyllabusSubTopicInfo(topicId: subTopicId),
          );

          final lessons = <_Lesson>[];
          if (subRows.isNotEmpty) {
            for (final s in subRows) {
              final subSubId = _int(s, [
                'SubSubTopicID', 'sub_sub_topic_id', 'ID', 'id',
                'SubTopicID', 'sub_topic_id'
              ]);
              if (subSubId == 0) continue;
              final subTitle =
                  _str(s, ['Title', 'title', 'Name', 'name'], fb: 'Lesson $subSubId');
              lessons.add(
                  _Lesson(id: subSubId, title: subTitle, needsFetch: true));
            }
          } else {
            final direct = await _Cache.get(
              key: subTopicId,
              map: _Cache.content,
              loader: () =>
                  apiService.fetchSyllabusContent(subtopicId: subTopicId),
            );
            if (direct.isNotEmpty) {
              lessons.add(_mergeContentRows(
                direct,
                subSubTopicId: subTopicId,
                subSubTitle: topicTitle,
              ));
            }
          }

          topics.add(
              _Topic(id: subTopicId, title: topicTitle, lessons: lessons));
        }

        sections.add(_SyllabusSection(
          id: mainId,
          title: sectionTitle,
          description: sectionDesc,
          gradeName: sectionGrade,
          status: sectionStatus,
          syllabusType: sectionType,
          coverUrl: cover,
          topics: topics,
        ));
      }

      if (sections.isEmpty) {
        throw Exception(
            'No syllabus sections were mapped from the API response.');
      }

      if (!mounted) return;

      // Auto-select first lesson
      int? selTopic, selLesson;
      for (final section in sections) {
        for (final tp in section.topics) {
          if (tp.lessons.isNotEmpty) {
            selTopic = tp.id;
            selLesson = tp.lessons.first.id;
            break;
          }
        }
        if (selTopic != null) break;
      }

      setState(() {
        _sections = sections;
        _topics = sections.expand((s) => s.topics).toList();
        _selTopicId = selTopic;
        _selLessonId = selLesson;
        if (selTopic != null) _expanded.add(selTopic);
        _loading = false;
      });

      if (selTopic != null && selLesson != null) {
        await _ensureLoaded(selTopic, selLesson);
      }
    } catch (e, st) {
      debugPrint('❌ _load: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  // ── lazy content loader ───────────────────────────────────────────────────────
  Future<void> _ensureLoaded(int topicId, int lessonId) async {
    final ti = _topics.indexWhere((t) => t.id == topicId);
    if (ti < 0) return;
    final li = _topics[ti].lessons.indexWhere((l) => l.id == lessonId);
    if (li < 0) return;
    final lesson = _topics[ti].lessons[li];
    if (!lesson.needsFetch) return;

    debugPrint('📥 Fetching Content(Subtopic_id=$lessonId)');
    _Lesson updated;
    try {
      List<Map<String, dynamic>> rows = await _Cache.get(
        key: lessonId,
        map: _Cache.content,
        loader: () => apiService.fetchSyllabusContent(subtopicId: lessonId),
      );
      if (rows.isEmpty && topicId != lessonId) {
        rows = await _Cache.get(
          key: topicId,
          map: _Cache.content,
          loader: () => apiService.fetchSyllabusContent(subtopicId: topicId),
        );
      }
      debugPrint('📥 Content rows=${rows.length}');

      if (rows.isNotEmpty) {
        updated = _mergeContentRows(
          rows,
          subSubTopicId: lesson.id,
          subSubTitle: lesson.title,
        );
      } else {
        updated = lesson.copyWith(needsFetch: false);
      }
    } catch (e) {
      debugPrint('⚠️ _ensureLoaded: $e');
      updated = lesson.copyWith(needsFetch: false);
    }

    if (!mounted) return;
    setState(() {
      final ls = List<_Lesson>.from(_topics[ti].lessons)..[li] = updated;
      final ts = List<_Topic>.from(_topics)
        ..[ti] = _topics[ti].copyWith(lessons: ls);
      _topics = ts;
    });
  }

  // ── open url ──────────────────────────────────────────────────────────────────
  Future<void> _open(String raw) async {
    final url = _normalise(raw);
    if (!_isHttp(url)) return;
    debugPrint('🔗 Opening: $url');
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Cannot open link'),
          backgroundColor: Colors.red.shade700,
          action: SnackBarAction(
            label: 'Copy',
            textColor: Colors.white,
            onPressed: () => Clipboard.setData(ClipboardData(text: url)),
          ),
        ));
      }
    }
  }

  // ── flat ordered lesson list ──────────────────────────────────────────────────
  List<({int topicId, _Lesson lesson})> get _flat {
    final out = <({int topicId, _Lesson lesson})>[];
    for (final t in _topics) {
      for (final l in t.lessons) {
        out.add((topicId: t.id, lesson: l));
      }
    }
    return out;
  }

  ({int topicId, _Lesson lesson})? get _prev {
    final f = _flat;
    final i =
        f.indexWhere((e) => e.topicId == _selTopicId && e.lesson.id == _selLessonId);
    if (i <= 0) return null;
    return f[i - 1];
  }

  ({int topicId, _Lesson lesson})? get _next {
    final f = _flat;
    final i =
        f.indexWhere((e) => e.topicId == _selTopicId && e.lesson.id == _selLessonId);
    if (i < 0 || i >= f.length - 1) return null;
    return f[i + 1];
  }

  Future<void> _selectLesson(int topicId, int lessonId) async {
    setState(() {
      _selTopicId = topicId;
      _selLessonId = lessonId;
      _expanded.add(topicId);
    });
    await _ensureLoaded(topicId, lessonId);
  }

  _Lesson? get _currentLesson {
    if (_selTopicId == null || _selLessonId == null) return null;
    try {
      return _topics
          .firstWhere((t) => t.id == _selTopicId)
          .lessons
          .firstWhere((l) => l.id == _selLessonId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openSection(_SyllabusSection section) async {
    if (!section.hasNestedTopics) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Topics not available yet for this section.'),
      ));
      return;
    }
    final firstTopic = section.topics.isNotEmpty ? section.topics.first : null;
    final firstLesson = firstTopic != null && firstTopic.lessons.isNotEmpty
        ? firstTopic.lessons.first
        : null;

    if (firstTopic != null && firstLesson != null) {
      await _selectLesson(firstTopic.id, firstLesson.id);
    }
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SectionPage(
          section: section,
          lesson: firstLesson,
          onOpen: _open,
          onEnsureLoaded: firstTopic != null && firstLesson != null
              ? () => _ensureLoaded(firstTopic.id, firstLesson.id)
              : null,
          resolveLesson: firstTopic != null && firstLesson != null
              ? () {
                  try {
                    final topic =
                        _topics.firstWhere((t) => t.id == firstTopic.id);
                    return topic.lessons
                        .firstWhere((l) => l.id == firstLesson.id);
                  } catch (_) {
                    return null;
                  }
                }
              : null,
        ),
      ),
    );
  }

  Widget _buildSectionGrid() {
    if (_sections.isEmpty) {
      return const Center(
        child: Text('No syllabus sections found.',
            style: TextStyle(color: Colors.black45)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 700
                ? 2
                : 1;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: 0.9,
          ),
          itemCount: _sections.length,
          itemBuilder: (_, i) => _buildSectionCard(_sections[i]),
        );
      },
    );
  }

  Widget _buildSectionCard(_SyllabusSection section) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9DEE8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: _SectionCover(section: section),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(
              section.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2B2B2B),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              section.description.isNotEmpty
                  ? section.description
                  : section.gradeName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: () => _openSection(section),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8EA7D7),
                foregroundColor: Colors.black87,
                elevation: 0,
                minimumSize: const Size(88, 34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SIDEBAR
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSidebar({required bool openInNewPage}) {
    if (_topics.isEmpty) {
      return const Center(
          child: Text('No topics found.',
              style: TextStyle(color: Colors.black45)));
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEAF2FF), Color(0xFFF8FBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _topics.length,
        itemBuilder: (_, i) =>
            _buildTopicCard(_topics[i], i, openInNewPage),
      ),
    );
  }

  Widget _buildTopicCard(_Topic topic, int idx, bool openInNewPage) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFDCE8FF)),
      ),
      child: openInNewPage
          ? Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: Text(topic.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _blue,
                              fontSize: 16)),
                    ),
                    ...topic.lessons.map((l) => _lessonTile(topic, l,
                        openInNewPage: true, dense: false)),
                  ]),
            )
          : Theme(
              data: ThemeData(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: _expanded.contains(topic.id),
                onExpansionChanged: (v) => setState(() =>
                    v ? _expanded.add(topic.id) : _expanded.remove(topic.id)),
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                title: Text(topic.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: _blue)),
                subtitle: Text('${topic.lessons.length} lessons',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black45)),
                children: topic.lessons
                    .map((l) => Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          child: _lessonTile(topic, l,
                              openInNewPage: false, dense: true),
                        ))
                    .toList(),
              ),
            ),
    );
  }

  Widget _lessonTile(_Topic topic, _Lesson lesson,
      {required bool openInNewPage, required bool dense}) {
    final sel = _selTopicId == topic.id && _selLessonId == lesson.id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: sel ? const Color(0xFFE5EEFF) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            if (openInNewPage) {
              await _selectLesson(topic.id, lesson.id);
              if (!mounted) return;
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _LessonPage(
                      topicId: topic.id,
                      lessonId: lesson.id,
                      screen: this,
                    ),
                  ));
            } else {
              await _selectLesson(topic.id, lesson.id);
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: 12, vertical: dense ? 10 : 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: sel
                      ? const Color(0xFFA9C7FF)
                      : const Color(0xFFE2EAF7)),
            ),
            child: Row(children: [
              Icon(
                  sel
                      ? Icons.play_circle_fill
                      : Icons.play_circle_outline,
                  color: sel ? _sky : Colors.blueGrey,
                  size: 20),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(lesson.title,
                      style: TextStyle(
                        fontSize: dense ? 13 : 14,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? _blue : Colors.black87,
                      ))),
              if (openInNewPage)
                const Icon(Icons.chevron_right,
                    color: Colors.black38, size: 18),
            ]),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RIGHT PANE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRightPane() {
    final lesson = _currentLesson;
    if (lesson == null) {
      return const Center(
          child: Text('Select a lesson from the left panel',
              style: TextStyle(fontSize: 15, color: Colors.black45)));
    }
    return _LessonContent(
        lesson: lesson,
        onOpen: _open,
        navy: _navy,
        blue: _blue,
        sky: _sky);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _useHscpSectionView ? Colors.white : _navy,
        foregroundColor: _useHscpSectionView ? _navy : Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              _useHscpSectionView ? 'Student' : 'Student Syllabus',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          if (!_loading && _error == null)
            Text(_gradeTitle,
                style: TextStyle(
                  fontSize: 11,
                  color: _useHscpSectionView
                      ? Colors.black54
                      : Colors.white60,
                )),
        ]),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _load,
              tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry')),
                  ]),
                ))
              : _useHscpSectionView
                  ? _buildSectionGrid()
                  : LayoutBuilder(builder: (ctx, box) {
                      if (box.maxWidth >= 900) {
                        return Row(children: [
                          SizedBox(
                              width: 320,
                              child: _buildSidebar(openInNewPage: false)),
                          const VerticalDivider(
                              width: 1, color: Color(0xFFD5E1F7)),
                          Expanded(child: _buildRightPane()),
                        ]);
                      }
                      return _buildSidebar(openInNewPage: true);
                    }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LESSON CONTENT WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class _LessonContent extends StatelessWidget {
  final _Lesson lesson;
  final Future<void> Function(String) onOpen;
  final Color navy, blue, sky;

  const _LessonContent({
    required this.lesson,
    required this.onOpen,
    required this.navy,
    required this.blue,
    required this.sky,
  });

  String get _typeTag => lesson.contentType.toUpperCase();
  Color get _typeColor {
    switch (lesson.contentType) {
      case 'video':
      case 'iframe':
        return const Color(0xFFDC2626);
      case 'image':
        return const Color(0xFF059669);
      case 'pdf':
        return const Color(0xFFEA580C);
      case 'file':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF1E429F);
    }
  }

  List<String> get _docUrls => lesson.linkUrls.where(_isDocument).toList();
  List<String> get _webUrls =>
      lesson.linkUrls.where((u) => !_isDocument(u)).toList();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(lesson.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0D1F4C),
              height: 1.3,
            )),
        const SizedBox(height: 14),
        if (lesson.needsFetch)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ))
        else if (!lesson.hasContent)
          _emptyCard()
        else ...[
          if (lesson.hasHtml)
            _HtmlView(html: lesson.rawHtml, onOpen: onOpen),
          if (lesson.hasHtml) const SizedBox(height: 14),
          if (lesson.hasImages) ...[
            _sectionLabel(
                'Images', Icons.image_outlined, const Color(0xFF059669)),
            const SizedBox(height: 10),
            ...lesson.imageUrls.map((url) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ImageCard(url: url, onOpen: onOpen),
                )),
            const SizedBox(height: 4),
          ],
          if (_docUrls.isNotEmpty) ...[
            _sectionLabel('Documents', Icons.description_outlined,
                const Color(0xFFEA580C)),
            const SizedBox(height: 10),
            ..._docUrls.map((url) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child:
                      _LinkCard(url: url, onOpen: onOpen, isDocument: true),
                )),
            const SizedBox(height: 4),
          ],
          if (_webUrls.isNotEmpty) ...[
            _sectionLabel(
                'Links', Icons.link_rounded, const Color(0xFF1E429F)),
            const SizedBox(height: 10),
            ..._webUrls.map((url) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LinkCard(url: url, onOpen: onOpen),
                )),
          ],
        ],
      ]),
    );
  }

  Widget _sectionLabel(String label, IconData icon, Color color) =>
      Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ]);

  Widget _emptyCard() => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 4),
        padding:
            const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDE3F0)),
        ),
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, size: 40, color: Colors.black26),
          SizedBox(height: 10),
          Text('No content for this lesson',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.black45)),
          SizedBox(height: 4),
          Text('The server returned no data for this sub-topic.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black38)),
        ]),
      );
}

class _SectionCover extends StatelessWidget {
  final _SyllabusSection section;
  const _SectionCover({required this.section});

  @override
  Widget build(BuildContext context) {
    if (section.coverUrl.isNotEmpty) {
      return Image.network(
        section.coverUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFD7F4A5),
                Color(0xFFF9F5D6),
                Color(0xFFCAE8A5)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.15,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Colors.white, Colors.transparent],
                  radius: 0.9,
                  center: const Alignment(-0.6, -0.7),
                ),
              ),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Image.asset('images/CTALogo.png', fit: BoxFit.contain),
          ),
        ),
      ],
    );
  }
}

class _LinkCard extends StatelessWidget {
  final String url;
  final Future<void> Function(String) onOpen;
  final bool isDocument;

  const _LinkCard({
    required this.url,
    required this.onOpen,
    this.isDocument = false,
  });

  String get _label {
    final uri = Uri.tryParse(url);
    final last = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : '';
    if (last.isNotEmpty) return Uri.decodeComponent(last);
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE3F0)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDocument
              ? const Color(0xFFFFEDD5)
              : const Color(0xFFDBEAFE),
          foregroundColor: isDocument
              ? const Color(0xFFEA580C)
              : const Color(0xFF1E429F),
          child: Icon(isDocument
              ? Icons.description_outlined
              : Icons.link_rounded),
        ),
        title: Text(
          _label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          url,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
        onTap: () => onOpen(url),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// IMAGE CARD
// ══════════════════════════════════════════════════════════════════════════════

class _ImageCard extends StatefulWidget {
  final String url;
  final Future<void> Function(String) onOpen;
  const _ImageCard({required this.url, required this.onOpen});
  @override
  State<_ImageCard> createState() => _ImageCardState();
}

class _ImageCardState extends State<_ImageCard> {
  bool _err = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE3F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _err
            ? _errWidget()
            : Image.network(
                widget.url,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                loadingBuilder: (_, child, prog) {
                  if (prog == null) return child;
                  final pct = prog.expectedTotalBytes != null
                      ? prog.cumulativeBytesLoaded /
                          prog.expectedTotalBytes!
                      : null;
                  return Container(
                    height: 200,
                    color: const Color(0xFFF0F5FF),
                    child: Center(
                        child: CircularProgressIndicator(
                            value: pct,
                            color: const Color(0xFF1E429F))),
                  );
                },
                errorBuilder: (_, __, ___) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _err = true);
                  });
                  return _errWidget();
                },
              ),
      ),
    );
  }

  Widget _errWidget() => Container(
        height: 130,
        color: const Color(0xFFF5F7FF),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.broken_image_outlined,
              size: 32, color: Colors.black26),
          const SizedBox(height: 6),
          const Text('Image could not load',
              style: TextStyle(color: Colors.black38, fontSize: 12)),
          TextButton.icon(
            onPressed: () => widget.onOpen(widget.url),
            icon: const Icon(Icons.open_in_browser_rounded, size: 14),
            label: const Text('Open in browser',
                style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1E429F)),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// LESSON DETAIL PAGE
// ══════════════════════════════════════════════════════════════════════════════

class _LessonPage extends StatefulWidget {
  final int topicId;
  final int lessonId;
  final _StudentSyllabusScreenState screen;

  const _LessonPage({
    required this.topicId,
    required this.lessonId,
    required this.screen,
  });

  @override
  State<_LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<_LessonPage> {
  late int _topicId;
  late int _lessonId;
  bool _navigating = false;

  static const _navy = Color(0xFF0D1F4C);
  static const _blue = Color(0xFF1E429F);
  static const _sky = Color(0xFF2F80ED);

  @override
  void initState() {
    super.initState();
    _topicId = widget.topicId;
    _lessonId = widget.lessonId;
  }

  _Lesson? get _lesson {
    try {
      return widget.screen._topics
          .firstWhere((t) => t.id == _topicId)
          .lessons
          .firstWhere((l) => l.id == _lessonId);
    } catch (_) {
      return null;
    }
  }

  List<({int topicId, _Lesson lesson})> get _flat => widget.screen._flat;

  int get _flatIndex =>
      _flat.indexWhere((e) => e.topicId == _topicId && e.lesson.id == _lessonId);

  ({int topicId, _Lesson lesson})? get _prevItem {
    final i = _flatIndex;
    return i > 0 ? _flat[i - 1] : null;
  }

  ({int topicId, _Lesson lesson})? get _nextItem {
    final i = _flatIndex;
    return (i >= 0 && i < _flat.length - 1) ? _flat[i + 1] : null;
  }

  Future<void> _go(({int topicId, _Lesson lesson}) target) async {
    if (_navigating) return;
    setState(() => _navigating = true);
    try {
      await widget.screen._selectLesson(target.topicId, target.lesson.id);
      if (!mounted) return;
      setState(() {
        _topicId = target.topicId;
        _lessonId = target.lesson.id;
      });
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _lesson;
    final prev = _prevItem;
    final next = _nextItem;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FF),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(lesson?.title ?? 'Lesson',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: Column(children: [
        Container(
          color: _navy,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(children: [
            Expanded(
              child: _navigating
                  ? const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)))
                  : OutlinedButton.icon(
                      onPressed: prev == null ? null : () => _go(prev),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15),
                      label: const Text('Previous',
                          style:
                              TextStyle(fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            prev == null ? Colors.white38 : Colors.white,
                        side: BorderSide(
                            color: prev == null
                                ? Colors.white24
                                : Colors.white60,
                            width: 1.3),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    (next == null || _navigating) ? null : () => _go(next),
                icon: _navigating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.arrow_forward_ios_rounded, size: 15),
                label: Text(_navigating ? 'Loading…' : 'Next',
                    style:
                        const TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      next == null ? const Color(0xFF334E7A) : _sky,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF334E7A),
                  disabledForegroundColor: Colors.white38,
                  elevation: next == null ? 0 : 2,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ),
        Expanded(
          child: lesson == null
              ? const Center(child: CircularProgressIndicator())
              : _LessonContent(
                  lesson: lesson,
                  onOpen: widget.screen._open,
                  navy: _navy,
                  blue: _blue,
                  sky: _sky,
                ),
        ),
      ]),
    );
  }
}

class _SectionPage extends StatefulWidget {
  final _SyllabusSection section;
  final _Lesson? lesson;
  final Future<void> Function(String) onOpen;
  final Future<void> Function()? onEnsureLoaded;
  final _Lesson? Function()? resolveLesson;

  const _SectionPage({
    required this.section,
    required this.lesson,
    required this.onOpen,
    this.onEnsureLoaded,
    this.resolveLesson,
  });

  @override
  State<_SectionPage> createState() => _SectionPageState();
}

class _SectionPageState extends State<_SectionPage> {
  bool _loading = false;
  _Lesson? _lesson;

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;
    if (widget.lesson != null &&
        widget.lesson!.needsFetch &&
        widget.onEnsureLoaded != null) {
      _prime();
    }
  }

  Future<void> _prime() async {
    setState(() => _loading = true);
    try {
      await widget.onEnsureLoaded!();
      _lesson = widget.resolveLesson?.call() ?? _lesson;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D1F4C),
        elevation: 0,
        title: Text(
          section.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _SectionCover(section: section),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD9DEE8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2230),
                  ),
                ),
                const SizedBox(height: 10),
                if (section.description.isNotEmpty)
                  Text(
                    section.description,
                    style: const TextStyle(
                        fontSize: 14, height: 1.5, color: Colors.black87),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _metaChip('Grade', section.gradeName),
                    _metaChip('Type', section.syllabusType),
                    _metaChip('Status', section.status),
                    if (section.topics.isNotEmpty)
                      _metaChip('Topics', '${section.topics.length}'),
                    if (section.topics.isEmpty)
                      _metaChip('Section ID', '${section.id}'),
                  ],
                ),
              ],
            ),
          ),
          if (_loading) ...[
            const SizedBox(height: 18),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_lesson != null && !_lesson!.needsFetch) ...[
            const SizedBox(height: 18),
            _LessonContent(
              lesson: _lesson!,
              onOpen: widget.onOpen,
              navy: const Color(0xFF0D1F4C),
              blue: const Color(0xFF1E429F),
              sky: const Color(0xFF2F80ED),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaChip(String label, String value) {
    final safeValue = value.trim().isEmpty ? '-' : value.trim();
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: RichText(
        text: TextSpan(
          style:
              const TextStyle(color: Colors.black87, fontSize: 13),
          children: [
            TextSpan(
              text: '$label: ',
              style:
                  const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: safeValue),
          ],
        ),
      ),
    );
  }
}
