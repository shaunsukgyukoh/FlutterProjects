import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'i18n/app_i18n.dart';
import 'package:flutter/foundation.dart' show kIsWeb;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<String>('app_store'); // json string store
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const App(),
    ),
  );
}

/// -------------------------
/// Data (your JSON embedded for MVP)
/// -------------------------
const int trubleSeedVersion = 7;


/// -------------------------
/// Models
/// -------------------------
class Applicability {
  final List<String> models;
  final String gaUsage; // ALL/YES/NO
  final List<String> gaBoardTypes;

  const Applicability({
    required this.models,
    required this.gaUsage,
    required this.gaBoardTypes,
  });

  factory Applicability.fromJson(Map<String, dynamic> j) => Applicability(
        models: (j['models'] as List? ?? const []).map((e) => e.toString()).toList(),
        gaUsage: (j['ga_usage'] ?? j['gaUsage'] ?? 'ALL').toString(),
        gaBoardTypes: (j['ga_board_types'] as List? ??
                j['gaBoardTypes'] as List? ??
                const ['ALL'])
            .map((e) => e.toString())
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'models': models,
        'ga_usage': gaUsage,
        'ga_board_types': gaBoardTypes,
      };
}

class StepItem {
  String text;
  bool done;
  Uint8List? imageBytes;

  StepItem({required this.text, this.done = false, this.imageBytes});

  factory StepItem.fromJson(Map<String, dynamic> j) => StepItem(
        text: j['text'].toString(),
        done: (j['done'] == true),
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'done': done,
        'image_b64': imageBytes == null ? null : base64Encode(imageBytes!),
      };

  static StepItem fromJsonWithImage(Map<String, dynamic> j) => StepItem(
        text: j['text'].toString(),
        done: (j['done'] == true),
        imageBytes: (j['image_b64'] == null) ? null : base64Decode(j['image_b64'] as String),
      );
}

class SolutionItem {
  String title;
  final List<StepItem> steps;

  SolutionItem({required this.title, required this.steps});

  factory SolutionItem.fromJson(Map<String, dynamic> j) => SolutionItem(
        title: j['title'].toString(),
        steps: (j['steps'] as List).map((e) => StepItem.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'steps': steps.map((e) => e.toJson()).toList(),
      };

  static SolutionItem fromJsonWithImage(Map<String, dynamic> j) => SolutionItem(
        title: j['title'].toString(),
        steps: (j['steps'] as List).map((e) => StepItem.fromJsonWithImage(e)).toList(),
      );
}

class TroubleItem {
  final String id;
  final String symptom;
  final String cause;
  final List<String> tags;
  final Applicability applicability;
  final List<SolutionItem> solutions;
  

  TroubleItem({
    required this.id,
    required this.symptom,
    required this.cause,
    required this.tags,
    required this.applicability,
    required this.solutions,
  });

  // ✅ id를 JSON에서 읽음
  factory TroubleItem.fromJson(Map<String, dynamic> j) => TroubleItem(
        id: (j['id'] ?? '').toString(),
        symptom: j['symptom'].toString(),
        cause: j['cause'].toString(),
        tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        applicability: Applicability.fromJson(j['applicability']),
        solutions: (j['solutions'] as List).map((e) => SolutionItem.fromJson(e)).toList(),
      );

  // ✅ id를 JSON에 저장
  Map<String, dynamic> toJson() => {
        'id': id,
        'symptom': symptom,
        'cause': cause,
        'tags': tags,
        'applicability': applicability.toJson(),
        'solutions': solutions.map((e) => e.toJson()).toList(),
      };
}

class ReportMeta {
  String hospital;
  String serial;
  String contact;
  String model;     // 설치구성: 모델
  String gaUsage;   // YES/NO/ALL
  String gaBoard;   // 보드타입
  String symptom;   // 현상 (기본값: trouble.symptom)
  String cause;     // 원인 (기본값: trouble.cause)
  String action;    // 조치방식(텍스트)
  DateTime actionDate; // 조치일자

  ReportMeta({
    this.hospital = '',
    this.serial = '',
    this.contact = '',
    this.model = 'ALL',
    this.gaUsage = 'ALL',
    this.gaBoard = 'ALL',
    this.symptom = '',
    this.cause = '',
    this.action = '',
    DateTime? actionDate,
  }) : actionDate = actionDate ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'hospital': hospital,
        'serial': serial,
        'contact': contact,
        'model': model,
        'gaUsage': gaUsage,
        'gaBoard': gaBoard,
        'symptom': symptom,
        'cause': cause,
        'action': action,
        'actionDate': actionDate.toIso8601String(),
      };

  factory ReportMeta.fromJson(Map<String, dynamic> j) => ReportMeta(
        hospital: (j['hospital'] ?? '').toString(),
        serial: (j['serial'] ?? '').toString(),
        contact: (j['contact'] ?? '').toString(),
        model: (j['model'] ?? 'ALL').toString(),
        gaUsage: (j['gaUsage'] ?? 'ALL').toString(),
        gaBoard: (j['gaBoard'] ?? 'ALL').toString(),
        symptom: (j['symptom'] ?? '').toString(),
        cause: (j['cause'] ?? '').toString(),
        action: (j['action'] ?? '').toString(),
        actionDate: DateTime.tryParse((j['actionDate'] ?? '').toString()) ?? DateTime.now(),
      );
}

Future<String> _loadAssetString(String path) async {
  return await rootBundle.loadString(path);
}

/// -------------------------
/// Persistence keys
/// -------------------------
class StoreKeys {
  static const troubles = 'troubles';   // list json
  static const installGuides = 'install_guides';     // 
  static const operationGuides = 'operation_guides'; // 
  static const settings = 'settings';   // settings json
  static const language = 'language';

  static const checklistType = 'checklist::type'; // expo/demo/clinical
  static String checklistKey(ChecklistType type) => 'checklist::${type.name}';
  static String checklistRecordsKey(ChecklistType type) => 'checklist_records::${type.name}';

  static String progressKey(String troubleId, int solutionIndex)
    => 'progress::$troubleId::$solutionIndex';

  static String reportMetaKey(String troubleId)
    => 'report_meta::$troubleId';
}

/// -------------------------
/// AppState (filters + Hive persistence)
/// -------------------------
class AppState extends ChangeNotifier {
  final Box<String> _box = Hive.box<String>('app_store');

  String lang = 'ko';
  File? _troublesBackupFile;
  Timer? _backupDebounce;

  late List<String> allModels;
  late List<String> allGaBoardTypes;
  late List<String> allTags;
  Map<String, String> modelLabelsEn = {};
  Map<String, String> tagLabelsEn = {};

  List<TroubleItem> troubles = [];
  List<GuideSection> installSections = [];
  List<GuideSection> operationSections = [];

  static const List<String> checklistGroupNames = [
    '본체 및 핵심 장비',
    '액세서리 및 케이블, 전원',
    '소모품',
    '홍보물',
    '세척',
  ];

  Map<String, List<ChecklistRow>> _seedChecklistRowsByType(ChecklistType type) {
    final seed = _checklistSeedJson ?? <String, dynamic>{};
    final template = _templateFromSeed(seed);
    // ✅ seed가 없거나 비정상이면 안전 fallback (기존 템플릿이 없어졌다면 최소 빈 map)
    final base = (template.isEmpty)
        ? <String, List<ChecklistRow>>{}
        : _seedChecklistRowsFromTemplate(template);

    // ✅ type rule 적용 (assets에서)
    final rules = _typeRulesFromSeed(seed, type);

    // remove groups
    final remove = (rules['remove_groups'] as List? ?? const [])
        .map((e) => e.toString())
        .toSet();
    for (final g in remove) {
      base.remove(g);
    }

    // ensure groups (추가/덮어쓰기)
    final ensure = rules['ensure_groups'];
    if (ensure is Map) {
      for (final entry in ensure.entries) {
        final group = entry.key.toString();
        final items = entry.value;
        if (items is List) {
          base[group] = items.map((name) {
            final n = name.toString();
            return ChecklistRow(
              name: n,
              imageAssetPath: checklistImageMap[n],
            );
          }).toList();
        }
      }
    }
    
    // 전시에서만 홍보물
    if (type != ChecklistType.exhibition) {
      base.remove('홍보물');
    }

    // 임상에서만 세척
    if (type != ChecklistType.clinical) {
      base.remove('세척');
    } else {
      // 임상일 때만 세척 추가 (혹시 _checklistTemplate에 없으면 여기서 추가)
      base['세척'] ??= [
        ChecklistRow(name: '방수캡+에어러버'),
        ChecklistRow(name: '세척솔 롱'),
        ChecklistRow(name: '세척솔 숏'),
        ChecklistRow(name: '세척기 어답터'),
        ChecklistRow(name: '푸시기'),
      ];
    }

    return base;
  }

  Future<String> _loadAssetString(String path) async {
    return await rootBundle.loadString(path);
  }

  Future<Map<String, dynamic>> _loadSettingsFromAssets() async {
    final raw = await _loadAssetString('assets/data/settings_v6.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, dynamic>{};
    return decoded.cast<String, dynamic>();
  }

  String labelOf(String raw) {
    if (lang != 'en') return raw;
    return modelLabelsEn[raw] ?? tagLabelsEn[raw] ?? raw;
  }

  Future<List<Map<String, dynamic>>> _loadTroublesSeedFromAssets() async {
    const candidates = <String>[
      'assets/data/troubles_seed_v7.json',
      'assets/data/troubles_v6.json',
    ];

    for (final path in candidates) {
      try {
        final raw = await _loadAssetString(path);
        final decoded = jsonDecode(raw);
        if (decoded is! List) continue;
        return decoded.cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
      } catch (_) {
        // Try next candidate path.
      }
    }
    return <Map<String, dynamic>>[];
  }


  final Map<ChecklistType, Map<String, List<ChecklistRow>>> _checklists = {};

  Map<String, List<ChecklistRow>> loadChecklist(ChecklistType type) {
    // 캐시 우선
    if (_checklists.containsKey(type)) return _checklists[type]!;

    final key = StoreKeys.checklistKey(type);
    final raw = _box.get(key);

    Map<String, List<ChecklistRow>> parsed;

    if (raw == null || raw.trim().isEmpty) {
      // 없으면 seed 생성 후 저장
      parsed = _seedChecklistRowsByType(type);
      _checklists[type] = parsed;
      // 최초 저장
      _box.put(key, jsonEncode(_encodeChecklist(parsed)));
      return parsed;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        parsed = _seedChecklistRowsByType(type);
      } else {
        parsed = _decodeChecklist(decoded.cast<String, dynamic>());
      }
    } catch (_) {
      parsed = _seedChecklistRowsByType(type);
    }

    _checklists[type] = parsed;
    return parsed;
  }

  Future<void> updateChecklist(ChecklistType type) async {
    final data = loadChecklist(type); // 캐시/로드 보장
    final key = StoreKeys.checklistKey(type);
    await _box.put(key, jsonEncode(_encodeChecklist(data)));
    notifyListeners();
  }

  Future<void> addChecklistRow(ChecklistType type, String group, ChecklistRow row) async {
    final data = loadChecklist(type);
    final rowsRaw = data[group] ?? <ChecklistRow>[];
    final rows = [...rowsRaw]..sort((a, b) {
      int priority(ChecklistRow e) {
        if (e.qty == 0) return 3; // 맨 아래
        if (e.status == ChecklistStatus.ok) return 2; // 그 위 (O)
        if (e.status == ChecklistStatus.verifying) return 1; // 그 위 (검증중)
        return 0; // 나머지 맨 위
      }

      final pa = priority(a);
      final pb = priority(b);

      if (pa != pb) return pa.compareTo(pb);

      return a.name.compareTo(b.name); // 동일 그룹 내 안정 정렬
    });
    data[group] = [...rows, row];
    await updateChecklist(type);
  }

  Future<void> updateChecklistRow(ChecklistType type, String group, int index, ChecklistRow nextRow) async {
    final data = loadChecklist(type);
    final rows = [...(data[group] ?? <ChecklistRow>[])];
    if (index < 0 || index >= rows.length) return;
    rows[index] = nextRow;
    data[group] = rows;
    await updateChecklist(type);
  }

  Future<void> deleteChecklistRow(ChecklistType type, String group, int index) async {
    final data = loadChecklist(type);
    final rows = [...(data[group] ?? <ChecklistRow>[])];
    if (index < 0 || index >= rows.length) return;
    rows.removeAt(index);
    data[group] = rows;
    await updateChecklist(type);
  }

  Map<String, dynamic> _encodeChecklist(Map<String, List<ChecklistRow>> data) {
    return data.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()));
  }

  Map<String, List<ChecklistRow>> _decodeChecklist(Map<String, dynamic> m) {
    final out = <String, List<ChecklistRow>>{};
    for (final group in AppState.checklistGroupNames) {
      final rawList = m[group];
      if (rawList is List) {
        out[group] = rawList
            .whereType<Map>()
            .map((e) => ChecklistRow.fromJson(e.cast<String, dynamic>()))
            .toList();
      } else {
        out[group] = <ChecklistRow>[];
      }
    }
    // 혹시 예상치 못한 그룹이 들어있다면 같이 살림
    for (final entry in m.entries) {
      if (out.containsKey(entry.key)) continue;
      final rawList = entry.value;
      if (rawList is List) {
        out[entry.key] = rawList
            .whereType<Map>()
            .map((e) => ChecklistRow.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    }
    return out;
  }

  final Map<ChecklistType, List<ChecklistRecord>> _checklistRecords = {};

  List<ChecklistRecord> loadChecklistRecords(ChecklistType type) {
    if (_checklistRecords.containsKey(type)) return _checklistRecords[type]!;

    final key = StoreKeys.checklistRecordsKey(type);
    final raw = _box.get(key) ?? '';

    List<ChecklistRecord> migrateLegacyIfNeeded() {
      final legacyRaw = _box.get(StoreKeys.checklistKey(type)) ?? '';
      if (legacyRaw.trim().isEmpty) return <ChecklistRecord>[];
      try {
        final decoded = jsonDecode(legacyRaw);
        if (decoded is! Map) return <ChecklistRecord>[];
        final rows = _decodeChecklist(decoded.cast<String, dynamic>());
        final now = DateTime.now();
        final migrated = ChecklistRecord(
          id: '${type.name}:${now.microsecondsSinceEpoch}',
          type: type,
          eventName: '${type.name.toUpperCase()} Legacy',
          eventDate: now,
          updatedAt: now,
          rows: rows,
        );
        final result = <ChecklistRecord>[migrated];
        _checklistRecords[type] = result;
        _box.put(
          key,
          jsonEncode(result.map((e) => e.toJson()).toList()),
        );
        return result;
      } catch (_) {
        return <ChecklistRecord>[];
      }
    }

    if (raw.trim().isEmpty) {
      final migrated = migrateLegacyIfNeeded();
      _checklistRecords[type] = migrated;
      return migrated;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _checklistRecords[type] = <ChecklistRecord>[];
        return _checklistRecords[type]!;
      }
      final records = decoded
          .whereType<Map>()
          .map((e) => ChecklistRecord.fromJson((e).cast<String, dynamic>()))
          .where((e) => e.type == type)
          .toList();
      records.sort((a, b) => b.eventDate.compareTo(a.eventDate));
      _checklistRecords[type] = records;
      return records;
    } catch (_) {
      _checklistRecords[type] = <ChecklistRecord>[];
      return _checklistRecords[type]!;
    }
  }

  ChecklistRecord? getChecklistRecord(ChecklistType type, String recordId) {
    final records = loadChecklistRecords(type);
    for (final r in records) {
      if (r.id == recordId) return r;
    }
    return null;
  }

  Map<String, List<ChecklistRow>> loadChecklistForRecord(ChecklistType type, String recordId) {
    final record = getChecklistRecord(type, recordId);
    if (record == null) return <String, List<ChecklistRow>>{};
    return record.rows;
  }

  Future<void> _persistChecklistRecords(ChecklistType type) async {
    final records = _checklistRecords[type] ?? <ChecklistRecord>[];
    await _box.put(
      StoreKeys.checklistRecordsKey(type),
      jsonEncode(records.map((e) => e.toJson()).toList()),
    );
  }

  Future<String> createChecklistRecord({
    required ChecklistType type,
    required String eventName,
    required DateTime eventDate,
  }) async {
    final now = DateTime.now();
    final id = '${type.name}:${now.microsecondsSinceEpoch}';
    final next = ChecklistRecord(
      id: id,
      type: type,
      eventName: eventName,
      eventDate: DateTime(eventDate.year, eventDate.month, eventDate.day),
      updatedAt: now,
      rows: _seedChecklistRowsByType(type),
    );
    final records = [...loadChecklistRecords(type), next]
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
    _checklistRecords[type] = records;
    await _persistChecklistRecords(type);
    notifyListeners();
    return id;
  }

  Future<void> updateChecklistRecordMeta({
    required ChecklistType type,
    required String recordId,
    required String eventName,
    required DateTime eventDate,
  }) async {
    final records = [...loadChecklistRecords(type)];
    final idx = records.indexWhere((e) => e.id == recordId);
    if (idx < 0) return;
    final cur = records[idx];
    records[idx] = cur.copyWith(
      eventName: eventName,
      eventDate: DateTime(eventDate.year, eventDate.month, eventDate.day),
      updatedAt: DateTime.now(),
    );
    records.sort((a, b) => b.eventDate.compareTo(a.eventDate));
    _checklistRecords[type] = records;
    await _persistChecklistRecords(type);
    notifyListeners();
  }

  Future<void> deleteChecklistRecord({
    required ChecklistType type,
    required String recordId,
  }) async {
    final records = [...loadChecklistRecords(type)];
    records.removeWhere((e) => e.id == recordId);
    _checklistRecords[type] = records;
    await _persistChecklistRecords(type);
    notifyListeners();
  }

  Future<void> addChecklistRowToRecord(
    ChecklistType type,
    String recordId,
    String group,
    ChecklistRow row,
  ) async {
    final records = [...loadChecklistRecords(type)];
    final idx = records.indexWhere((e) => e.id == recordId);
    if (idx < 0) return;

    final record = records[idx];
    final data = record.rows;
    final rowsRaw = data[group] ?? <ChecklistRow>[];
    final rows = [...rowsRaw]..sort((a, b) {
      int priority(ChecklistRow e) {
        if (e.qty == 0) return 3;
        if (e.status == ChecklistStatus.ok) return 2;
        if (e.status == ChecklistStatus.verifying) return 1;
        return 0;
      }

      final pa = priority(a);
      final pb = priority(b);
      if (pa != pb) return pa.compareTo(pb);
      return a.name.compareTo(b.name);
    });

    data[group] = [...rows, row];
    records[idx] = record.copyWith(rows: data, updatedAt: DateTime.now());
    _checklistRecords[type] = records;
    await _persistChecklistRecords(type);
    notifyListeners();
  }

  Future<void> updateChecklistRowInRecord(
    ChecklistType type,
    String recordId,
    String group,
    int index,
    ChecklistRow nextRow,
  ) async {
    final records = [...loadChecklistRecords(type)];
    final idx = records.indexWhere((e) => e.id == recordId);
    if (idx < 0) return;
    final record = records[idx];
    final data = record.rows;
    final rows = [...(data[group] ?? <ChecklistRow>[])];
    if (index < 0 || index >= rows.length) return;
    rows[index] = nextRow;
    data[group] = rows;
    records[idx] = record.copyWith(rows: data, updatedAt: DateTime.now());
    _checklistRecords[type] = records;
    await _persistChecklistRecords(type);
    notifyListeners();
  }

  Future<void> deleteChecklistRowFromRecord(
    ChecklistType type,
    String recordId,
    String group,
    int index,
  ) async {
    final records = [...loadChecklistRecords(type)];
    final idx = records.indexWhere((e) => e.id == recordId);
    if (idx < 0) return;
    final record = records[idx];
    final data = record.rows;
    final rows = [...(data[group] ?? <ChecklistRow>[])];
    if (index < 0 || index >= rows.length) return;
    rows.removeAt(index);
    data[group] = rows;
    records[idx] = record.copyWith(rows: data, updatedAt: DateTime.now());
    _checklistRecords[type] = records;
    await _persistChecklistRecords(type);
    notifyListeners();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _normalizeEventName(String raw) => raw.trim().toLowerCase();

  bool _isSameEventMeta(ChecklistRecord r, String eventName, DateTime eventDate) {
    return _normalizeEventName(r.eventName) == _normalizeEventName(eventName) &&
        _dateOnly(r.eventDate) == _dateOnly(eventDate);
  }

  ChecklistRecord? findChecklistRecordByEventAndType(
    ChecklistType type,
    String eventName,
    DateTime eventDate,
  ) {
    final records = loadChecklistRecords(type);
    for (final r in records) {
      if (_isSameEventMeta(r, eventName, eventDate)) return r;
    }
    return null;
  }

  Future<String> getOrCreateChecklistRecordForEventType({
    required ChecklistType type,
    required String eventName,
    required DateTime eventDate,
  }) async {
    final existing = findChecklistRecordByEventAndType(type, eventName, eventDate);
    if (existing != null) return existing.id;
    return createChecklistRecord(
      type: type,
      eventName: eventName,
      eventDate: eventDate,
    );
  }

  List<ChecklistEventSummary> loadChecklistEventSummaries() {
    final byKey = <String, ChecklistEventSummary>{};

    for (final type in ChecklistType.values) {
      final records = loadChecklistRecords(type);
      for (final r in records) {
        final name = r.eventName.trim();
        final date = _dateOnly(r.eventDate);
        final key = '${date.toIso8601String().split('T').first}::${_normalizeEventName(name)}';
        final prev = byKey[key];

        if (prev == null) {
          byKey[key] = ChecklistEventSummary(
            eventName: name,
            eventDate: date,
            updatedAt: r.updatedAt,
            recordIds: {type: r.id},
          );
        } else {
          final nextIds = <ChecklistType, String>{...prev.recordIds, type: r.id};
          final nextUpdated = r.updatedAt.isAfter(prev.updatedAt) ? r.updatedAt : prev.updatedAt;
          byKey[key] = prev.copyWith(
            updatedAt: nextUpdated,
            recordIds: nextIds,
          );
        }
      }
    }

    final out = byKey.values.toList()
      ..sort((a, b) {
        final d = b.eventDate.compareTo(a.eventDate);
        if (d != 0) return d;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return out;
  }

  ChecklistEventSummary? findChecklistEventSummaryByNameDate(
    String eventName,
    DateTime eventDate,
  ) {
    final targetName = _normalizeEventName(eventName);
    final targetDate = _dateOnly(eventDate);
    for (final e in loadChecklistEventSummaries()) {
      if (_normalizeEventName(e.eventName) == targetName && _dateOnly(e.eventDate) == targetDate) {
        return e;
      }
    }
    return null;
  }

  ChecklistEventProgress summarizeChecklistEvent(ChecklistEventSummary summary) {
    int ok = 0;
    int verifying = 0;
    int fail = 0;

    for (final entry in summary.recordIds.entries) {
      final type = entry.key;
      final recordId = entry.value;
      final r = getChecklistRecord(type, recordId);
      if (r == null) continue;
      for (final rows in r.rows.values) {
        for (final row in rows) {
          switch (row.status) {
            case ChecklistStatus.ok:
              ok += 1;
              break;
            case ChecklistStatus.verifying:
              verifying += 1;
              break;
            case ChecklistStatus.fail:
              fail += 1;
              break;
          }
        }
      }
    }

    return ChecklistEventProgress(
      ok: ok,
      verifying: verifying,
      fail: fail,
    );
  }

  Future<void> updateChecklistEventAcrossTypes({
    required ChecklistEventSummary summary,
    required String eventName,
    required DateTime eventDate,
  }) async {
    final normalizedDate = _dateOnly(eventDate);
    final touched = <ChecklistType>{};

    for (final entry in summary.recordIds.entries) {
      final type = entry.key;
      final recordId = entry.value;
      final records = [...loadChecklistRecords(type)];
      final idx = records.indexWhere((e) => e.id == recordId);
      if (idx < 0) continue;

      final cur = records[idx];
      records[idx] = cur.copyWith(
        eventName: eventName,
        eventDate: normalizedDate,
        updatedAt: DateTime.now(),
      );
      records.sort((a, b) => b.eventDate.compareTo(a.eventDate));
      _checklistRecords[type] = records;
      touched.add(type);
    }

    for (final t in touched) {
      await _persistChecklistRecords(t);
    }
    if (touched.isNotEmpty) notifyListeners();
  }

  Future<List<ChecklistRecord>> deleteChecklistEventAcrossTypes(ChecklistEventSummary summary) async {
    final touched = <ChecklistType>{};
    final removed = <ChecklistRecord>[];
    for (final entry in summary.recordIds.entries) {
      final type = entry.key;
      final recordId = entry.value;
      final records = [...loadChecklistRecords(type)];
      final idx = records.indexWhere((e) => e.id == recordId);
      if (idx < 0) continue;
      removed.add(records[idx]);
      records.removeAt(idx);
      _checklistRecords[type] = records;
      touched.add(type);
    }

    for (final t in touched) {
      await _persistChecklistRecords(t);
    }
    if (touched.isNotEmpty) notifyListeners();
    return removed;
  }

  Future<void> restoreChecklistRecords(List<ChecklistRecord> records) async {
    if (records.isEmpty) return;
    final touched = <ChecklistType>{};
    for (final rec in records) {
      final type = rec.type;
      final list = [...loadChecklistRecords(type)];
      final exists = list.any((e) => e.id == rec.id);
      if (exists) continue;
      list.add(rec);
      list.sort((a, b) => b.eventDate.compareTo(a.eventDate));
      _checklistRecords[type] = list;
      touched.add(type);
    }
    for (final t in touched) {
      await _persistChecklistRecords(t);
    }
    if (touched.isNotEmpty) notifyListeners();
  }

  // filters
  String filterModel = 'ALL';
  String filterGaUsage = 'ALL'; // ALL/YES/NO
  String filterGaBoard = 'ALL';
  Set<String> filterTags = {};
  String query = '';

  Future<List<GuideSection>> _loadGuideSections({
    required String hiveKey,
    required String assetPath,
  }) async {
    final seedSections = await _loadGuideSectionsFromAsset(assetPath);

    Future<List<GuideSection>> loadFromSeedAndPersist() async {
      await _box.put(
        hiveKey,
        jsonEncode(seedSections.map((e) => e.toJson()).toList()),
      );
      return seedSections;
    }

    // 1) Hive에서 먼저 가져오기
    final raw = _box.get(hiveKey) ?? '';

    // 2) 없으면 assets seed 로드 후 Hive에 저장
    if (raw.trim().isEmpty) {
      return loadFromSeedAndPersist();
    }

    // 3) 파싱 실패/스키마 불일치 시 seed로 자동 복구 (웹 캐시 손상 대응)
    final loaded = _parseGuideSections(raw);
    if (loaded == null) {
      return loadFromSeedAndPersist();
    }

    // 4) 기존 Hive 데이터에 EN 필드가 비어 있으면 seed에서 보강
    final merged = _mergeGuideSectionsWithSeed(loaded, seedSections);
    if (!_guideSectionsEqual(loaded, merged)) {
      await _box.put(
        hiveKey,
        jsonEncode(merged.map((e) => e.toJson()).toList()),
      );
    }
    return merged;
  }

  Future<List<GuideSection>> _loadGuideSectionsFromAsset(String assetPath) async {
    final seededRaw = await rootBundle.loadString(assetPath);
    final parsed = _parseGuideSections(seededRaw);
    return parsed ?? const <GuideSection>[];
  }

  List<GuideSection>? _parseGuideSections(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .map((e) => GuideSection.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return null;
    }
  }

  List<GuideSection> _mergeGuideSectionsWithSeed(
    List<GuideSection> current,
    List<GuideSection> seed,
  ) {
    final seedById = <String, GuideSection>{
      for (final section in seed) section.id: section,
    };

    return current.map((section) {
      final seedSection = seedById[section.id];
      if (seedSection == null) return section;

      final mergedSteps = <GuideStep>[];
      for (int i = 0; i < section.steps.length; i++) {
        final seedStep = (i < seedSection.steps.length) ? seedSection.steps[i] : null;
        mergedSteps.add(_mergeGuideStepWithSeed(section.steps[i], seedStep));
      }

      return GuideSection(
        id: section.id,
        title: section.title,
        titleEn: _pickNonEmpty(section.titleEn, seedSection.titleEn),
        steps: mergedSteps.isEmpty ? seedSection.steps : mergedSteps,
      );
    }).toList();
  }

  GuideStep _mergeGuideStepWithSeed(GuideStep current, GuideStep? seed) {
    if (seed == null) {
      final mergedImages = current.images
          .map((img) => _mergeGuideImageWithSeed(img, null))
          .toList();
      return GuideStep(
        title: current.title,
        titleEn: current.titleEn,
        images: mergedImages,
        paragraphs: current.paragraphs,
        bullets: current.bullets,
        tables: current.tables,
        paragraphsEn: current.paragraphsEn,
        bulletsEn: current.bulletsEn,
      );
    }

    final mergedImages = <GuideImageItem>[];
    for (int i = 0; i < current.images.length; i++) {
      final seedImage = (i < seed.images.length) ? seed.images[i] : null;
      mergedImages.add(_mergeGuideImageWithSeed(current.images[i], seedImage));
    }

    final mergedTables = <GuideTable>[];
    for (int i = 0; i < current.tables.length; i++) {
      final seedTable = (i < seed.tables.length) ? seed.tables[i] : null;
      mergedTables.add(_mergeGuideTableWithSeed(current.tables[i], seedTable));
    }

    return GuideStep(
      title: current.title,
      titleEn: _pickNonEmpty(current.titleEn ?? '', seed.titleEn ?? ''),
      images: mergedImages,
      paragraphs: current.paragraphs,
      bullets: current.bullets,
      tables: mergedTables,
      paragraphsEn: (current.paragraphsEn?.isNotEmpty ?? false)
          ? current.paragraphsEn
          : seed.paragraphsEn,
      bulletsEn: (current.bulletsEn?.isNotEmpty ?? false)
          ? current.bulletsEn
          : seed.bulletsEn,
    );
  }

  GuideImageItem _mergeGuideImageWithSeed(GuideImageItem current, GuideImageItem? seed) {
    final currentAsset = GuideAssetPath.sanitize(current.asset);
    if (seed == null) {
      return GuideImageItem(
        asset: currentAsset,
        caption: current.caption,
        captionEn: current.captionEn,
      );
    }

    final seedAsset = GuideAssetPath.sanitize(seed.asset);
    final captionEn = _pickNonEmpty(current.captionEn ?? '', seed.captionEn ?? '');

    return GuideImageItem(
      asset: currentAsset.isNotEmpty ? currentAsset : seedAsset,
      caption: current.caption,
      captionEn: captionEn.isEmpty ? null : captionEn,
    );
  }

  GuideTable _mergeGuideTableWithSeed(GuideTable current, GuideTable? seed) {
    if (seed == null) return current;
    return GuideTable(
      headers: current.headers,
      rows: current.rows,
      headersEn: (current.headersEn?.isNotEmpty ?? false) ? current.headersEn : seed.headersEn,
      rowsEn: (current.rowsEn?.isNotEmpty ?? false) ? current.rowsEn : seed.rowsEn,
    );
  }

  bool _guideSectionsEqual(List<GuideSection> a, List<GuideSection> b) {
    final aj = jsonEncode(a.map((e) => e.toJson()).toList());
    final bj = jsonEncode(b.map((e) => e.toJson()).toList());
    return aj == bj;
  }

  String _pickNonEmpty(String current, String fallback) {
    return current.trim().isNotEmpty ? current : fallback;
  }


  Future<void> persistInstallGuides() async {
    await _box.put(StoreKeys.installGuides, jsonEncode(installSections.map((e) => e.toJson()).toList()));
  }

  Future<void> persistOperationGuides() async {
    await _box.put(StoreKeys.operationGuides, jsonEncode(operationSections.map((e) => e.toJson()).toList()));
  }

  // ---- CRUD: install
  Future<void> addInstallSection(GuideSection sec) async {
    installSections = [...installSections, sec];
    await persistInstallGuides();
    notifyListeners();
  }

  Future<void> updateInstallSection(GuideSection sec) async {
    installSections = installSections.map((e) => e.id == sec.id ? sec : e).toList();
    await persistInstallGuides();
    notifyListeners();
  }

  Future<void> deleteInstallSection(String id) async {
    installSections = installSections.where((e) => e.id != id).toList();
    await persistInstallGuides();
    notifyListeners();
  }

  // ---- CRUD: operation
  Future<void> addOperationSection(GuideSection sec) async {
    operationSections = [...operationSections, sec];
    await persistOperationGuides();
    notifyListeners();
  }

  Future<void> updateOperationSection(GuideSection sec) async {
    operationSections = operationSections.map((e) => e.id == sec.id ? sec : e).toList();
    await persistOperationGuides();
    notifyListeners();
  }

  Future<void> deleteOperationSection(String id) async {
    operationSections = operationSections.where((e) => e.id != id).toList();
    await persistOperationGuides();
    notifyListeners();
  }

  void debugDumpHive() {
    debugPrint('===== Hive Dump =====');
    for (final k in _box.keys) {
      debugPrint('[$k]');
      debugPrint(_box.get(k));
      debugPrint('---------------------');
    }
  }
    
  Future<void> init() async {

    final settings = await _loadSettingsFromAssets();
    _checklistSeedJson = await _loadChecklistSeedFromAssets();

    allModels = (settings['models'] as List? ?? const []).map((e) => e.toString()).toList();
    allGaBoardTypes = (settings['ga_board_types'] as List?
          ?? settings['deepeye_board_types'] as List?
          ?? const [])
      .map((e) => e.toString())
      .toList();
    allTags = (settings['tags'] as List? ?? const []).map((e) => e.toString()).toList();

    final modelsEn = (settings['models_en'] as List? ?? const []).map((e) => e.toString()).toList();
    for (int i = 0; i < allModels.length; i++) {
      final en = (i < modelsEn.length) ? modelsEn[i] : '';
      if (en.trim().isNotEmpty) modelLabelsEn[allModels[i]] = en;
    }
    final tagsEn = (settings['tags_en'] as List? ?? const []).map((e) => e.toString()).toList();
    for (int i = 0; i < allTags.length; i++) {
      final en = (i < tagsEn.length) ? tagsEn[i] : '';
      if (en.trim().isNotEmpty) tagLabelsEn[allTags[i]] = en;
    }

    final defaultLang = settings['language']?.toString() ?? 'ko';
    lang = _box.get(StoreKeys.language) ?? defaultLang;
    
    if (!kIsWeb) {
      await _initTroublesBackupFile();
      await _backupTroublesToDisk(); // 선택
    }

    // ✅ 1) Hive에 troubles가 "없으면" seed를 만들고 저장
    String raw = _box.get(StoreKeys.troubles) ?? '';
    if (raw.isEmpty) {
      final seeded = await _loadTroublesSeedFromAssets();

      for (int i = 0; i < seeded.length; i++) {
        seeded[i]['id'] ??= 'T${DateTime.now().microsecondsSinceEpoch}_$i';
      }

      raw = jsonEncode(seeded);
      await _box.put(StoreKeys.troubles, raw);
    }

    // ✅ 2) Hive에 있는 raw로 troubles 로딩
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    troubles = list.map((m) => TroubleItem.fromJson(m)).toList();

    // ✅ install/operation guides (기존 그대로)
    installSections = await _loadGuideSections(
      hiveKey: StoreKeys.installGuides,
      assetPath: 'assets/data/install_guides_v1.json',
    );

    operationSections = await _loadGuideSections(
      hiveKey: StoreKeys.operationGuides,
      assetPath: 'assets/data/operation_guides_v1.json',
    );

    // ✅ 3) seed version 업그레이드
    final v = int.tryParse(_box.get('trouble_seed_version') ?? '0') ?? 0;
    if (v < trubleSeedVersion) {
      final seeded = await _loadTroublesSeedFromAssets();

      for (int i = 0; i < seeded.length; i++) {
        seeded[i]['id'] ??= 'T${DateTime.now().microsecondsSinceEpoch}_$i';
      }

      final upgradedRaw = jsonEncode(seeded);
      await _box.put(StoreKeys.troubles, upgradedRaw);
      await _box.put('trouble_seed_version', '$trubleSeedVersion');

      troubles = seeded.map((m) => TroubleItem.fromJson(m)).toList();
    }

    notifyListeners();
  }

  Future<void> _initTroublesBackupFile() async {
    // Windows: C:\Users\...\Documents\FieldServiceMVP\troubles_autosave.json
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}${Platform.pathSeparator}FieldServiceMVP');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    _troublesBackupFile = File('${folder.path}${Platform.pathSeparator}troubles_autosave.json');
  }

  ReportMeta loadReportMetaOrDefault(TroubleItem t) {
    final key = StoreKeys.reportMetaKey(t.id);
    final raw = _box.get(key);
    if (raw == null) {
      return ReportMeta(
        symptom: t.symptom,
        cause: t.cause,
      );
    }
    final meta = ReportMeta.fromJson(jsonDecode(raw));
    // 기본 현상/원인이 비어있으면 trouble에서 채움
    if (meta.symptom.trim().isEmpty) meta.symptom = t.symptom;
    if (meta.cause.trim().isEmpty) meta.cause = t.cause;
    return meta;
  }

  Future<void> saveReportMeta(String troubleId, ReportMeta meta) async {
    final key = StoreKeys.reportMetaKey(troubleId);
    await _box.put(key, jsonEncode(meta.toJson()));
  }

  Future<void> setLang(String newLang) async {
    lang = newLang;
    await _box.put(StoreKeys.language, newLang);
    notifyListeners();
  }

  void setFilters({
    String? model,
    String? gaUsage,
    String? gaBoard,
    Set<String>? tags,
    String? q,
  }) {
    if (model != null) filterModel = model;
    if (gaUsage != null) filterGaUsage = gaUsage;
    if (gaBoard != null) filterGaBoard = gaBoard;
    if (tags != null) filterTags = tags;
    if (q != null) query = q;
    notifyListeners();
  }

  void resetFilters() {
    filterModel = 'ALL';
    filterGaUsage = 'ALL';
    filterGaBoard = 'ALL';
    filterTags = {};
    query = '';
    notifyListeners();
  }

  List<TroubleItem> get filteredTroubles {
    bool matchesApplicability(TroubleItem t) {
      final modelOk = filterModel == 'ALL'
          ? true
          : (t.applicability.models.contains('ALL') || t.applicability.models.contains(filterModel));

      final gaOk = filterGaUsage == 'ALL'
          ? true
          : (t.applicability.gaUsage == 'ALL' || t.applicability.gaUsage == filterGaUsage);

      final boardOk = filterGaBoard == 'ALL'
          ? true
          : (t.applicability.gaBoardTypes.contains('ALL') ||
              t.applicability.gaBoardTypes.contains(filterGaBoard));

      return modelOk && gaOk && boardOk;
    }

    bool matchesTags(TroubleItem t) {
      if (filterTags.isEmpty) return true;
      final set = t.tags.toSet();
      return filterTags.every(set.contains);
    }

    bool matchesQuery(TroubleItem t) {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) return true;
      final hay = '${t.symptom}\n${t.cause}\n${t.tags.join(' ')}'.toLowerCase();
      return hay.contains(q);
    }




    return troubles.where((t) => matchesApplicability(t) && matchesTags(t) && matchesQuery(t)).toList();
  }

  Future<void> addTrouble(TroubleItem item) async {
    troubles = [...troubles, item];
    await _persistTroubles();
    notifyListeners();
  }

  Future<void> updateTrouble(TroubleItem updated) async {
    troubles = troubles.map((t) => t.id == updated.id ? updated : t).toList();
    await _persistTroubles();
    notifyListeners();
  }

  Future<void> deleteTrouble(String id) async {
    troubles = troubles.where((t) => t.id != id).toList();
    await _persistTroubles();

    // 관련 progress/meta도 정리(선택)
    await _box.delete(StoreKeys.reportMetaKey(id));
    // 솔루션 개수만큼 progress키 삭제하려면 troubles에서 찾아서 반복 삭제

    notifyListeners();
  }

  Future<void> _backupTroublesToDisk({String? jsonStr}) async {
    final f = _troublesBackupFile;
    if (f == null) return;

    final data = jsonStr ?? jsonEncode(troubles.map((e) => e.toJson()).toList());

    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    await tmp.rename(f.path);
  }

  Future<void> _persistTroubles() async {
  
    final jsonStr = jsonEncode(troubles.map((e) => e.toJson()).toList());
    // 1) Hive 저장
    await _box.put(StoreKeys.troubles, jsonStr);

    if (kIsWeb) return; // ✅ 웹은 파일 백업 없음

    // 2) 파일 자동 백업 (디바운스: 너무 자주 쓰기 방지)
    _backupDebounce?.cancel();
    _backupDebounce = Timer(const Duration(milliseconds: 350), () async {
      await _backupTroublesToDisk(jsonStr: jsonStr);
    });
    // await _box.put(StoreKeys.troubles, jsonEncode(troubles.map((e) => e.toJson()).toList()));
  }

  /// --- Progress persistence (done + images) per trouble/solution
  Map<String, dynamic>? loadProgress(String troubleId, int solutionIndex) {
    final key = StoreKeys.progressKey(troubleId, solutionIndex);
    final raw = _box.get(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveProgress(String troubleId, int solutionIndex, SolutionItem solution) async {
    final key = StoreKeys.progressKey(troubleId, solutionIndex);
    final raw = jsonEncode(solution.toJson()); // includes image_b64
    await _box.put(key, raw);
  }

  Future<void> clearProgress(String troubleId, int solutionIndex) async {
    final key = StoreKeys.progressKey(troubleId, solutionIndex);
    await _box.delete(key);
  }
}

/// -------------------------
/// App UI
/// -------------------------
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: I18n.tr(s.lang, 'appTitle'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E), // Indigo 900
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0F1A), // Navy-Black
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111936),
          foregroundColor: Colors.white,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF161B33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _hidePw = true;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  void _login() {
    final id = _idCtrl.text.trim();
    final pw = _pwCtrl.text.trim();

    if (id == 'a' && pw == 'a') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.tr(context.read<AppState>().lang, 'loginFailed'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.tr(lang, 'login')),
        actions: [
          const _LanguageToggleButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 56),
                const SizedBox(height: 16),
                
                TextField(
                  controller: _idCtrl,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: I18n.tr(lang, 'loginId'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _pwCtrl,
                  obscureText: _hidePw,
                  onSubmitted: (_) => _login(),
                  decoration: InputDecoration(
                    labelText: I18n.tr(context.watch<AppState>().lang, 'loginPassword'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _hidePw = !_hidePw),
                      icon: Icon(_hidePw ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _login,
                    child: Text(I18n.tr(context.watch<AppState>().lang, 'login')),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  I18n.tr(lang, 'mvpAccountHint'),
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _LanguageToggleButton extends StatelessWidget {
  const _LanguageToggleButton();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return PopupMenuButton<String>(
      tooltip: I18n.tr(s.lang, 'switchLanguage'),
      icon: const Icon(Icons.language),
      initialValue: s.lang,
      onSelected: (v) => context.read<AppState>().setLang(v),
      itemBuilder: (_) => I18n.supported
          .map((e) => PopupMenuItem(value: e, child: Text(e.toUpperCase())))
          .toList(),
    );
  }
}

String checklistTypeLabel(String lang, ChecklistType type) {
  switch (type) {
    case ChecklistType.exhibition:
      return I18n.tr(lang, 'exhibition');
    case ChecklistType.demo:
      return I18n.tr(lang, 'demo');
    case ChecklistType.clinical:
      return I18n.tr(lang, 'clinical');
  }
}

// -------------------------
// Checklist seed (from assets)
// -------------------------
Map<String, dynamic>? _checklistSeedJson;

Future<Map<String, dynamic>> _loadChecklistSeedFromAssets() async {
  final raw = await _loadAssetString('assets/data/checklist_seed_v1.json');
  final decoded = jsonDecode(raw);
  if (decoded is! Map) return <String, dynamic>{};
  return decoded.cast<String, dynamic>();
}

Map<String, List<String>> _templateFromSeed(Map<String, dynamic> seed) {
  final t = seed['template'];
  if (t is! Map) return {};
  final out = <String, List<String>>{};
  for (final e in t.entries) {
    final k = e.key.toString();
    final v = e.value;
    if (v is List) out[k] = v.map((x) => x.toString()).toList();
  }
  return out;
}

Map<String, dynamic> _typeRulesFromSeed(Map<String, dynamic> seed, ChecklistType type) {
  final rules = seed['type_rules'];
  if (rules is! Map) return {};
  final key = type.name; // exhibition/demo/clinical
  final r = rules[key];
  if (r is Map) return r.cast<String, dynamic>();
  return {};
}


const Map<String, String> checklistImageMap = {
  '내시경 광원장치': 'assets/images/checklists/checklists_me470.jpg',
  '내시경 스코프': 'assets/images/checklists/checklists_scope.jpg',
  '모니터': 'assets/images/checklists/checklists_monitor.jpg',
  '모니터 거치대': 'assets/images/checklists/checklists_monitor_arm.jpg',
  'DEEPEYE': 'assets/images/checklists/checklists_deepeye_exhibition.jpg',
  '노트북+전원(타입확인)': 'assets/images/checklists/checklists_notebook.jpg',
  '카트': 'assets/images/checklists/checklists_cart_gosan.jpg',
  '시뮬레이터': 'assets/images/checklists/checklists_medicalip.jpg',
  '석션펌프': 'assets/images/checklists/checklists_suction_pump.jpg',
  '워터젯': 'assets/images/checklists/checklists_waterjet.jpg',
  '함체/딥아이 전원': 'assets/images/checklists/checklists_main_power.jpg',
  '모니터 전원': 'assets/images/checklists/checklists_monitor_power.jpg',
  '물병': 'assets/images/checklists/checklists_water_bottle.jpg',
  '석션튜브': 'assets/images/checklists/checklists_suction_tube.jpg',
  '이리게이션튜브': 'assets/images/checklists/checklists_irrigation_tube.jpg',
  '키보드 및 마우스': 'assets/images/checklists/checklists_keyboard_mouse.jpg',
  '캠링크': 'assets/images/checklists/checklists_camlink.jpg',
  'HDMI 캡쳐카드': 'assets/images/checklists/checklists_hdmi_capture.jpg',
  'DVI 캡쳐카드': 'assets/images/checklists/checklists_dvi_capture.jpg',
  '업데이트 USB': 'assets/images/checklists/checklists_usb.jpg',
  'HDMI to DVI 케이블': 'assets/images/checklists/checklists_hdmi-dvi.jpg',
  'DVI to DVI 케이블': 'assets/images/checklists/checklists_dvi-dvi.jpg',
  'HDMI to HDMI 케이블': 'assets/images/checklists/checklists_hdmi-hdmi.jpg',
  'SDI to SDI 케이블': 'assets/images/checklists/checklists_bnc-cable.jpg',
  'SDI to HDMI 컨버터': 'assets/images/checklists/checklists_sdi2hdmi.jpg',
  'HDMI to SDI 컨버터': 'assets/images/checklists/checklists_hdmi2sdi.jpg',
  'usb 허브': 'assets/images/checklists/checklists_usb_hub.jpg',
  'BNC to RCA': 'assets/images/checklists/checklists_bnc-to-rca.jpg',
  'ypbpr-to-hdmi': 'assets/images/checklists/checklists_ypbpr-to-hdmi.jpg',
  'HDMI 스플리터': 'assets/images/checklists/checklists_HDMI-splitter.jpg',
  'DVI 스플리터': 'assets/images/checklists/checklists_dvi-splitter.jpg',
  'HDMI 스위치': 'assets/images/checklists/checklists_hdmi-switch.jpg',
  'DVI 스위치': 'assets/images/checklists/checklists_dvi_switch.jpg',
  '멀티탭': 'assets/images/checklists/checklists_multitab.jpg',
  '석션실린터': 'assets/images/checklists/checklists_suction_cylinder.jpg',
  '스피커': 'assets/images/checklists/checklists_speaker.jpg',
  '화밸캡': 'assets/images/checklists/checklists_wb.jpg',
  'Wifi 동글': 'assets/images/checklists/checklists_wifi_dongle.jpg',
  '시뮬레이터 테이블': 'assets/images/checklists/checklists_simul-table.jpg',
  '테이블 천': 'assets/images/checklists/checklists_exhibit_cloth.jpg',
  '풋페달': 'assets/images/checklists/checklists_foot_orange2.jpg',
  '꽃지킴이': 'assets/images/checklists/checklists_lens_protector.jpg',
  '워터젯튜브+어답터': 'assets/images/checklists/checklists_waterjet_tube.jpg',
  '해외 전력 어답터': 'assets/images/checklists/checklists_power_adapter.jpg',
  '루브리컨트': 'assets/images/checklists/checklists_lubricant.jpg',
  '자이스': 'assets/images/checklists/checklists_zeiss.jpg',
  '안티포그': 'assets/images/checklists/checklists_antifog.jpg',
  '키친타월': 'assets/images/checklists/checklists_kitchentower.jpg',
  '장갑': 'assets/images/checklists/checklists_glove.jpg',
  '인스트루먼츠(포셉, 스네어 등)': 'assets/images/checklists/checklists_forceps.jpg',
  '물티슈': 'assets/images/checklists/checklists_tissue.jpg',
  '공구(드라이버, 렌치, 니퍼 등)': 'assets/images/checklists/checklists_tools.jpg',
  'P4 오링': 'assets/images/checklists/checklists_P4_oring.jpg',
  '여분 키마 배터리': 'assets/images/checklists/checklists_battery.jpg',
  '제품 카타로그': 'assets/images/checklists/checklists_me_brochure.jpg',
  '소프트웨어 카다로그': 'assets/images/checklists/checklists_ga_brochure.jpg',
  '볼펜': 'assets/images/checklists/checklists_pen.jpg',
  '방명록': 'assets/images/checklists/checklists_guestbook.jpg',
  '가방': 'assets/images/checklists/checklists_cloth_bag.jpg',
  '스테이플러': 'assets/images/checklists/checklists_stapler.jpg',
  '본부장님 명함': 'assets/images/checklists/checklists_business_card.jpg',
  '메디인테크 명찰 랜야드': 'assets/images/checklists/checklists_lenyard.jpg',
  '설문지': 'assets/images/checklists/checklists_surveys.jpg',
  '방수캡': 'assets/images/checklists/checklists_waterproof_cap.jpg',
  '에어러버': 'assets/images/checklists/checklists_air_rubber.jpg',
  '세척솔 롱': 'assets/images/checklists/checklists_brush_long.jpg',
  '세척솔 숏': 'assets/images/checklists/checklists_brush_short.jpg',
  '세척기 어답터': 'assets/images/checklists/checklists_adaptor_oly.jpg',
  '푸시기 (릭테스터기)': 'assets/images/checklists/checklists_leak_tester.jpg',
};




const Map<String, List<String>> kChecklistVariants = {
  'DEEPEYE': ['전시용', '제품용'], 
  '내시경 광원장치': ['ME-400', 'ME-470'],
  '모니터': ['510S', '710S', '32" 4K'],
  '시뮬레이터': ['코켄', '메디컬IP'],
  '카트': ['고산', 'ITD'],
  '모니터 거치대': ['소형 스탠드', '대형 스탠드', '암', '수직암'],
  '물병': ['데모', '전시'],
  '세척기 어답터': ['올림푸스', '휴온스', 'ASAP'],
  '풋페달':['주황2', '주황1', '헤르가1', '헤르가2'],

};

String? assetForChecklistItem(String name, String? variant) {
  // variant 없으면 기본 이미지(원하면 지정)
  // return 'assets/images/checklists/default_$name.jpg' 같은 방식도 가능

  if (name == '내시경 광원장치') {
    if (variant == 'ME-400') return 'assets/images/checklists/checklists_me400.png';
    if (variant == 'ME-470') return 'assets/images/checklists/checklists_me470.png';
  }

  if (name == 'DEEPEYE') {
    if (variant == '전시용') return 'assets/images/checklists/checklists_deepeye_exhibition.jpg';
    if (variant == '제품용') return 'assets/images/checklists/checklists_deepeye_product.jpg';
  }

  if (name == '모니터') {
    if (variant == '510S') return 'assets/images/checklists/checklists_monitor_510s.jpg';
    if (variant == '710S') return 'assets/images/checklists/checklists_monitor_710s.jpg';
    if (variant == '32" 4K')   return 'assets/images/checklists/checklists_monitor_4k32.jpg';
  }

  if (name == '시뮬레이터') {
    if (variant == '코켄')     return 'assets/images/checklists/checklists_koken.jpg';
    if (variant == '메디컬IP') return 'assets/images/checklists/checklists_medicalip.jpg';
  }

  if (name == '카트') {
    if (variant == '고산') return 'assets/images/checklists/checklists_cart_gosan.jpg';
    if (variant == 'ITD')  return 'assets/images/checklists/checklists_cart_itd.jpg';
  }

  if (name == '모니터 거치대') {
    if (variant == '소형 스탠드') return 'assets/images/checklists/';
    if (variant == '대형 스탠드') return 'assets/images/checklists/';
    if (variant == '암') return 'assets/images/checklists/';
    if (variant == '수직암') return 'assets/images/checklists/';
  }

  if (name == '물병') {
    if (variant == '데모') return 'assets/images/checklists/checklists_waterbottle_exhibit.jpg';
    if (variant == '전시') return 'assets/images/checklists/checklists_waterbottle.jpg';
  }

  if (name == '세척기 어답터') {
    if (variant == '올림푸스') return 'assets/images/checklists/checklists_adaptor_oly.jpg';
    if (variant == '휴온스/ASAP')     return 'assets/images/checklists/checklists_adaptor.jpg';
  }

  if (name == '풋페달') {
    if (variant == '주황2') return 'assets/images/checklists/checklists_foot_orange2.jpg';
    if (variant == '주황1') return 'assets/images/checklists/checklists_foot_orange1.png';
    if (variant == '헤르가2') return 'assets/images/checklists/checklists_foot_herga2.jpg';
    if (variant == '헤르가3') return 'assets/images/checklists/';
  }

  return null;
}


Map<String, List<ChecklistRow>> _seedChecklistRowsFromTemplate(Map<String, List<String>> template) {
  return template.map((group, names) {
    return MapEntry(
      group,
      names.map((n) {
        return ChecklistRow(
          name: n,
          imageAssetPath: checklistImageMap[n], // 기존 매핑 그대로 사용
        );
      }).toList(),
    );
  });
}


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.tr(s.lang, 'appTitle')),
        actions: const [
          _LanguageToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                // 기존 버튼 3개
                Expanded(
                  flex:4,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _MainBtn(
                            label: I18n.tr(s.lang, 'checklist'),
                            icon: Icons.checklist_outlined,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ChecklistTypeSelectScreen()),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _MainBtn(
                            label: I18n.tr(s.lang, 'installation'),
                            icon: Icons.construction,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const InstallTypeSelectScreen()),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _MainBtn(
                            label: I18n.tr(s.lang, 'operation'),
                            icon: Icons.play_circle_outline,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const OperationGuideScreen()),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _MainBtn(
                            label: I18n.tr(s.lang, 'troubleshoot'),
                            icon: Icons.search,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TroubleListScreen()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MainBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MainBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      width: double.infinity,
      child: FilledButton.tonalIcon(
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        onPressed: onTap,
      ),
    );
  }
}


Future<List<String>> listAssetImagesInFolder(String folderPrefix) async {
  // folderPrefix: 'assets/images/'
  final manifestJson = await rootBundle.loadString('AssetManifest.json');
  final Map<String, dynamic> manifest = jsonDecode(manifestJson);

  final keys = manifest.keys
      .where((k) => k.startsWith(folderPrefix))
      .where((k) {
        final lower = k.toLowerCase();
        return lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp');
      })
      .toList()
    ..sort();

  return keys;
}

Future<String?> pickAssetImageDialog(BuildContext context) async {
  final images = await listAssetImagesInFolder('assets/images/checklists/');

  if (!context.mounted) return null;

  return showDialog<String>(
    context: context,
    builder: (_) => Consumer<AppState>(
    builder: (ctx, st, _) {
      final lang = st.lang;
      return AlertDialog(
        title: Text(I18n.tr(lang, 'selectImageFromAssets')),
          content: SizedBox(
            width: 720,
            height: 520,
            child: images.isEmpty
                ? Center(child: Text(I18n.tr(context.watch<AppState>().lang, 'noImagesInAssets')))
                : GridView.builder(
                    itemCount: images.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (_, i) {
                      final path = images[i];
                      return InkWell(
                        onTap: () => Navigator.pop(context, path),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(path, fit: BoxFit.cover),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  color: Colors.black54,
                                  child: Text(
                                    path.split('/').last,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
            actions: [
              TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(I18n.tr(lang, 'cancel')),
            ),
          ],
        );
      },
    ),
  );
}


/// -------------------------
/// Troubleshooting list + filters + search
/// -------------------------
class TroubleListScreen extends StatelessWidget {
  const TroubleListScreen({super.key});

  Future<void> exportFullBackup(BuildContext context) async {
    final st = context.read<AppState>();
    final box = Hive.box<String>('app_store');

    // 백업에 포함할 keys (필요 시 추가)
    final keys = <String>[
      StoreKeys.troubles,
      StoreKeys.settings,
      StoreKeys.language,

      // guides
      StoreKeys.installGuides,
      StoreKeys.operationGuides,

      // checklist meta
      StoreKeys.checklistType,

      // checklist per type
      StoreKeys.checklistKey(ChecklistType.exhibition),
      StoreKeys.checklistKey(ChecklistType.demo),
      StoreKeys.checklistKey(ChecklistType.clinical),

      // checklist records per type (event-based)
      StoreKeys.checklistRecordsKey(ChecklistType.exhibition),
      StoreKeys.checklistRecordsKey(ChecklistType.demo),
      StoreKeys.checklistRecordsKey(ChecklistType.clinical),

      // seed version
      'trouble_seed_version',
    ];

    // ✅ progress / report meta는 prefix로 전부 포함
    final extraKeys = box.keys
        .whereType<String>()
        .where((k) =>
            k.startsWith('progress::') ||
            k.startsWith('report_meta::'))
        .toList();

    final allKeys = {...keys, ...extraKeys}.toList();

    final data = <String, dynamic>{
      'schema': 'fs_full_backup_v1',
      'created_at': DateTime.now().toIso8601String(),
      'app': 'Field Service MVP',
      'kv': <String, String?>{},
    };

    final kv = (data['kv'] as Map<String, String?>);
    for (final k in allKeys) {
      kv[k] = box.get(k);
    }

    final jsonStr = jsonEncode(data);

    final location = await getSaveLocation (
      suggestedName: 'fs_full_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (location == null) return;

    final f = File(location.path);
    await f.writeAsString(jsonStr, flush: true);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.tr(st.lang, 'backupExported')}:\n$location')),
      );
    }
  }

  Future<void> importFullBackup(BuildContext context) async {
    final st = context.read<AppState>();
    final box = Hive.box<String>('app_store');

    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (file == null) return;

    final raw = await File(file.path).readAsString();
    final decoded = jsonDecode(raw);

    if (decoded is! Map || decoded['schema'] != 'fs_full_backup_v1') {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(I18n.tr(st.lang, 'invalidBackupSchema'))),
        );
      }
      return;
    }

    final kv = decoded['kv'];
    if (kv is! Map) return;

    // ✅ 덮어쓰기 전에 확인
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(I18n.tr(st.lang, 'fullRestore')),
        content: Text(I18n.tr(st.lang, 'fullRestoreConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(I18n.tr(st.lang, 'cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(I18n.tr(st.lang, 'restore'))),
        ],
      ),
    );
    if (ok != true) return;

    // ✅ Hive 덮어쓰기
    for (final entry in kv.entries) {
      final key = entry.key.toString();
      final val = entry.value;
      if (val == null) {
        await box.delete(key);
      } else {
        await box.put(key, val.toString());
      }
    }

    // ✅ AppState 메모리 재로딩
    await st.init();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${I18n.tr(st.lang, 'backupImported')}:\n${file.path}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final items = s.filteredTroubles;

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.tr(s.lang, 'troubleshoot')),
        actions: [
          const _LanguageToggleButton(),
          IconButton(
            tooltip: I18n.tr(s.lang, 'addIssue'),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AddIssueDialog(),
            ),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: I18n.tr(s.lang, 'exportFullBackup'),
            icon: const Icon(Icons.cloud_download_outlined),
            onPressed: () => exportFullBackup(context),
          ),
          IconButton(
            tooltip: I18n.tr(s.lang, 'importFullBackup'),
            icon: const Icon(Icons.cloud_upload_outlined),
            onPressed: () => importFullBackup(context),
          ),
          IconButton(
            tooltip: I18n.tr(s.lang, 'reset'),
            onPressed: () => context.read<AppState>().resetFilters(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterPanel(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: I18n.tr(s.lang, 'searchHint'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => context.read<AppState>().setFilters(q: v),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final t = items[i];
                return ListTile(
                  title: Text(t.symptom),
                  subtitle: Text(t.cause, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: _Badge(
                    text: '${t.solutions.length} ${I18n.tr(s.lang, 'solutionCount')}',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TroubleDetailScreen(item: t)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    final models = ['ALL', ...s.allModels];
    final gaUsage = ['ALL', 'YES', 'NO'];
    final boards = ['ALL', ...s.allGaBoardTypes];

    return ExpansionTile(
      title: Text(I18n.tr(s.lang, 'filters')),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: s.filterModel,
                decoration: InputDecoration(labelText: I18n.tr(s.lang, 'model')),
                items: models.map((e) => DropdownMenuItem(value: e, child: Text(e == 'ALL' ? e : s.labelOf(e)))).toList(),
                onChanged: (v) => context.read<AppState>().setFilters(model: v ?? 'ALL'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: s.filterGaUsage,
                decoration: InputDecoration(labelText: I18n.tr(s.lang, 'gaUsage')),
                items: gaUsage.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => context.read<AppState>().setFilters(gaUsage: v ?? 'ALL'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: s.filterGaBoard,
          decoration: InputDecoration(labelText: I18n.tr(s.lang, 'gaBoard')),
          items: boards.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) => context.read<AppState>().setFilters(gaBoard: v ?? 'ALL'),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('${I18n.tr(s.lang, 'tags')} (${I18n.tr(s.lang, 'multiSelect')})'),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: s.allTags.take(40).map((tag) {
            final selected = s.filterTags.contains(tag);
            return FilterChip(
              label: Text(s.labelOf(tag)),
              selected: selected,
              onSelected: (v) {
                final next = {...s.filterTags};
                if (v) {
                  next.add(tag);
                } else {
                  next.remove(tag);
                }
                context.read<AppState>().setFilters(tags: next);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// -------------------------
/// Detail: solution N + step checkbox + photo attach + progress save + PDF report
/// -------------------------
class TroubleDetailScreen extends StatefulWidget {
  final TroubleItem item;
  const TroubleDetailScreen({super.key, required this.item});

  @override
  State<TroubleDetailScreen> createState() => _TroubleDetailScreenState();
}

class _TroubleDetailScreenState extends State<TroubleDetailScreen> {
  int selectedSolution = 0;
  bool _loadedProgress = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedProgress) {
      _applySavedProgressIfAny();
      _loadedProgress = true;
    }
  }

  void _applySavedProgressIfAny() {
    final st = context.read<AppState>();
    final saved = st.loadProgress(widget.item.id, selectedSolution);
    if (saved == null) return;

    final savedSol = SolutionItem.fromJsonWithImage(saved);
    // 길이 다르면: saved 기준으로 덮어쓰기 (MVP)
    widget.item.solutions[selectedSolution].title = savedSol.title;
    widget.item.solutions[selectedSolution].steps
      ..clear()
      ..addAll(savedSol.steps);
  }

  Future<void> _generatePdfReportWithMetaNoContext({
    required String lang,
    required TroubleItem trouble,
    required SolutionItem sol,
    required ReportMeta meta,
  }) async {
    final now = DateTime.now();
    final createdAtStr = DateFormat('yyyy-MM-dd HH:mm').format(now);
    final actionDateStr = DateFormat('yyyy-MM-dd').format(meta.actionDate);

    final fontData = await rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    final boldData = await rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf');
    final ttfBold = pw.Font.ttf(boldData);

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
    );

    pw.ImageProvider? imgFromBytes(Uint8List? b) {
      if (b == null) return null;
      return pw.MemoryImage(b);
    }

    pw.Widget kv(String k, String v) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 110,
              child: pw.Text(
                k,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Expanded(child: pw.Text(v)),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(
            I18n.tr(lang, 'reportTitle'),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),

          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 0.8),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(I18n.tr(lang, 'basicInfo'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                kv(I18n.tr(lang, 'hospital'), meta.hospital),
                kv(I18n.tr(lang, 'serial'), meta.serial),
                kv(I18n.tr(lang, 'contactPerson'), meta.contact),
                kv(I18n.tr(lang, 'actionDate'), actionDateStr),
                kv(I18n.tr(lang, 'reportCreatedAt'), createdAtStr),

                pw.SizedBox(height: 10),
                pw.Text(I18n.tr(lang, 'setupConfig'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                kv(I18n.tr(lang, 'modelLabel'), meta.model),
                kv(I18n.tr(lang, 'gaLabel'), meta.gaUsage),
                kv(I18n.tr(lang, 'boardLabel'), meta.gaBoard),

                pw.SizedBox(height: 10),
                pw.Text(I18n.tr(lang, 'issue'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                kv(I18n.tr(lang, 'symptomLabel'), meta.symptom.trim().isEmpty ? trouble.symptom : meta.symptom),
                kv(I18n.tr(lang, 'causeLabel'), meta.cause.trim().isEmpty ? trouble.cause : meta.cause),
                kv(I18n.tr(lang, 'actionMethod'), meta.action),
                kv(I18n.tr(lang, 'appliedSolution'), sol.title),
              ],
            ),
          ),

          pw.SizedBox(height: 14),
          pw.Text(I18n.tr(lang, 'checklist'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),

          ...sol.steps.asMap().entries.map((e) {
            final idx = e.key + 1;
            final stp = e.value;
            final mark = stp.done ? '[x]' : '[ ]';
            final img = imgFromBytes(stp.imageBytes);

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('$mark  $idx. ${stp.text}'),
                if (img != null) ...[
                  pw.SizedBox(height: 6),
                  pw.Container(
                    width: double.infinity,
                    child: pw.Image(img, fit: pw.BoxFit.contain),
                  ),
                ],
                pw.SizedBox(height: 10),
              ],
            );
          }),
        ],
      ),
    );
    final pdfBytes = await doc.save();

    // ✅ 레이아웃(프린트/프리뷰)
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'report_${(meta.hospital.isEmpty ? "site" : meta.hospital)}_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf',
    );

    // (옵션) 프린트 UI 대신 “공유/저장”이 더 안정적인 플랫폼도 있음:
    // await Printing.sharePdf(bytes: pdfBytes, filename: 'report_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf');
  }


  

  Future<void> _saveProgress() async {
    final st = context.read<AppState>();
    final sol = widget.item.solutions[selectedSolution];
    await st.saveProgress(widget.item.id, selectedSolution, sol);
    if (mounted) {
      final s = context.read<AppState>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.tr(s.lang, 'saveProgress'))),
      );
    }
  }

  Future<void> _clearProgress() async {
    final st = context.read<AppState>();
    await st.clearProgress(widget.item.id, selectedSolution);

    // UI도 초기화: 원본 trouble 정의로 리셋하기(저장 안된 기준)
    // -> 여기서는 "해당 trouble의 기본 steps done=false, image=null"로만 리셋
    final sol = widget.item.solutions[selectedSolution];
    for (final step in sol.steps) {
      step.done = false;
      step.imageBytes = null;
    }

    if (mounted) {
      final s = context.read<AppState>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.tr(s.lang, 'clearProgress'))),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = widget.item;

    final sol = t.solutions[selectedSolution];

    return Scaffold(
      appBar: AppBar(
        title: Text('${I18n.tr(s.lang, 'solutions')}: ${t.solutions.length}'),
        actions: [
          IconButton(
            tooltip: I18n.tr(s.lang, 'generateReport'),
            onPressed: () async {
              final st = context.read<AppState>();
              final lang = st.lang;

              // 1) 템플릿 로드(없으면 default)
              final meta = st.loadReportMetaOrDefault(t);

              // 2) 사용자 입력 폼
              final edited = await showDialog<ReportMeta>(
                context: context,
                builder: (_) => ReportTemplateDialog(
                  trouble: t,
                  meta: meta,
                  allModels: st.allModels,
                  allBoards: st.allGaBoardTypes,
                ),
              );

              if (!mounted || edited == null) return; 

              // 3) 저장
              await st.saveReportMeta(t.id, edited);

              if (!mounted) return;

              final solutionSnapshot = t.solutions[selectedSolution];
              // 4) PDF 생성 (meta 포함)
              await _generatePdfReportWithMetaNoContext(
                lang: lang,
                trouble: t,
                sol: solutionSnapshot,
                meta: edited,
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
          ),
          IconButton(
            tooltip: I18n.tr(s.lang, 'save'),
            onPressed: _saveProgress,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: I18n.tr(s.lang, 'clear'),
            onPressed: _clearProgress,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(t.symptom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('${I18n.tr(s.lang, 'cause')}: ${t.cause}'),
          const SizedBox(height: 10),

          Text(I18n.tr(s.lang, 'selectSolution'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < t.solutions.length; i++)
                ChoiceChip(
                  label: Text(t.solutions[i].title),
                  selected: i == selectedSolution,
                  onSelected: (_) async {
                    // 솔루션 바꿀 때 현재 진행 저장(선호에 따라 끄기 가능)
                    await _saveProgress();
                    setState(() {
                      selectedSolution = i;
                    });
                    _applySavedProgressIfAny(); // 
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),

          Text(I18n.tr(s.lang, 'steps'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),

          for (int i = 0; i < sol.steps.length; i++)
            _StepCard(
              stepIndex: i,
              step: sol.steps[i],
              onChanged: () async {
                setState(() {});
                await _saveProgress(); // MVP: 변경 시 즉시 저장
              },
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

}

class GuideSection {
  final String id;
  final String title;
  final String titleEn;
  final List<GuideStep> steps;

  GuideSection({required this.id, required this.title, this.titleEn = '', required this.steps});

  String titleByLang(String lang) => (lang == 'en' && titleEn.trim().isNotEmpty) ? titleEn : title;

  factory GuideSection.fromJson(Map<String, dynamic> j) => GuideSection(
    id: (j['id'] ?? '').toString(),
    title: (j['title'] ?? '').toString(),
    titleEn: (j['title_en'] ?? j['titleEn'] ?? '').toString(), // ✅ 둘 다
    steps: (j['steps'] as List? ?? const [])
        .map((e) => GuideStep.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'title_en': titleEn,
        'steps': steps.map((e) => e.toJson()).toList(),
      };
}

class GuideImageItem {
  // final String asset;
  // final String caption;      // ko
  // final String? captionEn;   // en

  final String asset;
  final String caption;
  final String? captionEn;

  GuideImageItem({required this.asset, required this.caption, this.captionEn});

  String captionByLang(String lang) =>
      (lang == 'en' && (captionEn?.trim().isNotEmpty ?? false)) ? captionEn! : caption;

  factory GuideImageItem.fromJson(Map<String, dynamic> json) => GuideImageItem(
        asset: (json['asset'] ?? '') as String,
        caption: (json['caption'] ?? '') as String,
        captionEn: (json['caption_en'] ?? json['captionEn']) as String?, 
      );

  Map<String, dynamic> toJson() => {
        'asset': asset,
        'caption': caption,
        'caption_en': captionEn,
      };

  // String captionByLang(String lang) {
  //   if (lang == 'en') return (captionEn?.trim().isNotEmpty ?? false) ? captionEn! : caption;
  //   return caption;
  // }
}

class GuideAssetPath {
  static const Set<String> _invalidPaths = {
    'assets/images/install/-',
    'assets/images/install/reference__',
    'assets/images/install/intionS_01_cart.png',
    'assets/images/install/intionS_02_ports.png',
  };

  static String sanitize(String rawPath) {
    final path = rawPath.trim();
    if (path.isEmpty) return '';
    if (_invalidPaths.contains(path)) return '';
    return path;
  }

  static bool isRenderable(String rawPath) {
    final path = sanitize(rawPath);
    if (path.isEmpty) return false;
    if (!path.startsWith('assets/')) return false;
    return fileName(path).isNotEmpty;
  }

  static String fileName(String rawPath) {
    final path = sanitize(rawPath);
    if (path.isEmpty) return '';
    return path.split('/').last;
  }
}

class GuideTable {
  final List<String> headers;        // ko
  final List<List<String>> rows;     // ko
  final List<String>? headersEn;     // en
  final List<List<String>>? rowsEn;  // en

  GuideTable({
    required this.headers,
    required this.rows,
    this.headersEn,
    this.rowsEn,
  });

  List<String> headersByLang(String lang) =>
      (lang == 'en' && (headersEn?.isNotEmpty ?? false)) ? headersEn! : headers;

  List<List<String>> rowsByLang(String lang) =>
      (lang == 'en' && (rowsEn?.isNotEmpty ?? false)) ? rowsEn! : rows;

  factory GuideTable.fromJson(Map<String, dynamic> json) => GuideTable(
        headers: (json['headers'] as List? ?? []).map((e) => e.toString()).toList(),
        rows: (json['rows'] as List? ?? [])
            .map((r) => (r as List).map((e) => e.toString()).toList())
            .toList(),
        headersEn: (json['headers_en'] as List?)?.map((e) => e.toString()).toList(),
        rowsEn: (json['rows_en'] as List?)
            ?.map((r) => (r as List).map((e) => e.toString()).toList())
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'headers': headers,
        'rows': rows,
        'headers_en': headersEn,
        'rows_en': rowsEn,
      };

  // List<String> headersByLang(String lang) {
  //   if (lang == 'en' && (headersEn?.isNotEmpty ?? false)) return headersEn!;
  //   return headers;
  // }

  // List<List<String>> rowsByLang(String lang) {
  //   if (lang == 'en' && (rowsEn?.isNotEmpty ?? false)) return rowsEn!;
  //   return rows;
  // }
}

class GuideStep {
  final String title;
  final String? titleEn;

  final List<GuideImageItem> images;
  final List<String> paragraphs;
  final List<String> bullets;
  final List<GuideTable> tables;

  final List<String>? paragraphsEn;
  final List<String>? bulletsEn;

  GuideStep({
    required this.title,
    this.titleEn,
    required this.images,
    required this.paragraphs,
    required this.bullets,
    required this.tables,
    this.paragraphsEn,
    this.bulletsEn,
  });

  String titleByLang(String lang) =>
      (lang == 'en' && (titleEn?.trim().isNotEmpty ?? false)) ? titleEn! : title;

  List<String> paragraphsByLang(String lang) =>
      (lang == 'en' && (paragraphsEn?.isNotEmpty ?? false)) ? paragraphsEn! : paragraphs;

  List<String> bulletsByLang(String lang) =>
      (lang == 'en' && (bulletsEn?.isNotEmpty ?? false)) ? bulletsEn! : bullets;


  factory GuideStep.fromJson(Map<String, dynamic> json) => GuideStep(
        title: (json['title'] ?? '') as String,
        titleEn: (json['title_en'] ?? json['titleEn'] ?? '').toString(), 
        images: (json['images'] as List? ?? [])
            .map((e) => GuideImageItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        paragraphs: (json['paragraphs'] as List? ?? []).map((e) => e.toString()).toList(),
        bullets: (json['bullets'] as List? ?? []).map((e) => e.toString()).toList(),
        tables: (json['tables'] as List? ?? [])
            .map((e) => GuideTable.fromJson(e as Map<String, dynamic>))
            .toList(),
        paragraphsEn: (json['paragraphs_en'] as List?)?.map((e) => e.toString()).toList(),
        bulletsEn: (json['bullets_en'] as List?)?.map((e) => e.toString()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'title_en': titleEn,
        'images': images.map((e) => e.toJson()).toList(),
        'paragraphs': paragraphs,
        'bullets': bullets,
        'tables': tables.map((e) => e.toJson()).toList(),
        'paragraphs_en': paragraphsEn,
        'bullets_en': bulletsEn,
      };
}

class GuideDoc {
  final String id;
  final String title;
  final String? titleEn;
  final List<GuideStep> steps;

  GuideDoc({
    required this.id,
    required this.title,
    this.titleEn,
    required this.steps,
  });

  factory GuideDoc.fromJson(Map<String, dynamic> json) => GuideDoc(
        id: (json['id'] ?? '') as String,
        title: (json['title'] ?? '') as String,
        titleEn: json['title_en'] as String?,
        steps: (json['steps'] as List? ?? [])
            .map((e) => GuideStep.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'title_en': titleEn,
        'steps': steps.map((e) => e.toJson()).toList(),
      };
}

class _StepCard extends StatefulWidget {
  final int stepIndex;
  final StepItem step;
  final VoidCallback onChanged;

  const _StepCard({required this.stepIndex, required this.step, required this.onChanged});

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  final picker = ImagePicker();

  Future<void> _pickPhoto() async {
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      widget.step.imageBytes = bytes;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final step = widget.step;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: step.done,
                  onChanged: (v) {
                    setState(() => step.done = v ?? false);
                    widget.onChanged();
                  },
                ),
                Expanded(child: Text('${widget.stepIndex + 1}. ${step.text}')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.photo),
                  label: Text(I18n.tr(s.lang, 'attachPhoto')),
                ),
                const SizedBox(width: 10),
                if (step.imageBytes != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => step.imageBytes = null);
                      widget.onChanged();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(I18n.tr(s.lang, 'removePhoto')),
                  ),
              ],
            ),
            if (step.imageBytes != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(step.imageBytes!, height: 180, fit: BoxFit.cover),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// -------------------------
/// Add Issue (2번: 확장 버전)
/// - 태그 멀티선택 + 검색
/// - 솔루션 N개
/// - 솔루션별 스텝 추가/삭제
/// -------------------------
class AddIssueDialog extends StatefulWidget {
  const AddIssueDialog({super.key});

  @override
  State<AddIssueDialog> createState() => _AddIssueDialogState();
}

class ReportTemplateDialog extends StatefulWidget {
  final TroubleItem trouble;
  final ReportMeta meta;
  final List<String> allModels;
  final List<String> allBoards;

  const ReportTemplateDialog({
    super.key,
    required this.trouble,
    required this.meta,
    required this.allModels,
    required this.allBoards,
  });

  @override
  State<ReportTemplateDialog> createState() => _ReportTemplateDialogState();
}

class _ReportTemplateDialogState extends State<ReportTemplateDialog> {
  late ReportMeta m;

  late final TextEditingController hospitalCtrl;
  late final TextEditingController serialCtrl;
  late final TextEditingController contactCtrl;
  late final TextEditingController symptomCtrl;
  late final TextEditingController causeCtrl;
  late final TextEditingController actionCtrl;

  @override
  void initState() {
    super.initState();
    m = widget.meta;

    hospitalCtrl = TextEditingController(text: m.hospital);
    serialCtrl = TextEditingController(text: m.serial);
    contactCtrl = TextEditingController(text: m.contact);
    symptomCtrl = TextEditingController(text: m.symptom);
    causeCtrl = TextEditingController(text: m.cause);
    actionCtrl = TextEditingController(text: m.action);
  }

  @override
  void dispose() {
    hospitalCtrl.dispose();
    serialCtrl.dispose();
    contactCtrl.dispose();
    symptomCtrl.dispose();
    causeCtrl.dispose();
    actionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang; 
    final models = ['ALL', ...widget.allModels];
    final boards = ['ALL', ...widget.allBoards];
    const gaUsages = ['ALL', 'YES', 'NO'];

    return AlertDialog(
      title: Text(I18n.tr(lang, 'reportTemplate')),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _textField(hospitalCtrl, I18n.tr(lang, 'hospital')),
              const SizedBox(height: 8),
              _textField(serialCtrl, I18n.tr(lang, 'serial')),
              const SizedBox(height: 8),
              _textField(contactCtrl, I18n.tr(lang, 'contactPerson')),
              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(I18n.tr(lang, 'setupConfig'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: m.model,
                      decoration: InputDecoration(labelText: I18n.tr(lang, 'model'), border: const OutlineInputBorder(), isDense: true),
                      items: models.map((e) => DropdownMenuItem(value: e, child: Text(e == 'ALL' ? e : context.read<AppState>().labelOf(e)))).toList(),
                      onChanged: (v) => setState(() => m.model = v ?? 'ALL'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: m.gaUsage,
                      decoration: InputDecoration(labelText: I18n.tr(lang, 'gaUsage'), border: const OutlineInputBorder(), isDense: true),
                      items: gaUsages.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => m.gaUsage = v ?? 'ALL'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: m.gaBoard,
                decoration: InputDecoration(labelText: I18n.tr(lang, 'board'), border: const OutlineInputBorder(), isDense: true),
                items: boards.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => m.gaBoard = v ?? 'ALL'),
              ),

              const SizedBox(height: 14),
              _textField(symptomCtrl, I18n.tr(lang, 'symptomLabel')),
              const SizedBox(height: 8),
              _textField(causeCtrl, I18n.tr(lang, 'causeLabel')),
              const SizedBox(height: 8),
              _textField(actionCtrl, I18n.tr(lang, 'actionMethod'), maxLines: 3),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: I18n.tr(lang, 'actionDate'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(DateFormat('yyyy-MM-dd').format(m.actionDate)),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: m.actionDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) setState(() => m.actionDate = picked);
                            },
                            icon: const Icon(Icons.calendar_month),
                            label: Text(I18n.tr(lang, 'select')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  lang == 'ko'
                      ? I18n.tr(lang, 'savedPerTrouble')
                      : I18n.tr(lang, 'savedPerTrouble'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(I18n.tr(lang, 'cancel')),
        ),
        FilledButton(
          onPressed: () {
            m.hospital = hospitalCtrl.text.trim();
            m.serial = serialCtrl.text.trim();
            m.contact = contactCtrl.text.trim();
            m.symptom = symptomCtrl.text.trim();
            m.cause = causeCtrl.text.trim();
            m.action = actionCtrl.text.trim();
            Navigator.pop(context, m);
          },
          child: Text(I18n.tr(lang, 'save')),
        ),
      ],
    );
  }

  Widget _textField(TextEditingController c, String label, {int maxLines = 3}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}


class _AddIssueDialogState extends State<AddIssueDialog> {
  final symptomCtrl = TextEditingController();
  final causeCtrl = TextEditingController();

  String model = 'ALL';
  String gaUsage = 'ALL';
  String gaBoard = 'ALL';

  @override
  void dispose() {
    symptomCtrl.dispose();
    causeCtrl.dispose();
    super.dispose();
  }

  final Set<String> selectedTags = {};
  String tagQuery = '';

  final List<_DraftSolution> draftSolutions = [
    _DraftSolution(title: 'Try 1: ', steps: ['Step 1: ', 'Step 2: ']),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    final models = ['ALL', ...s.allModels];
    final boards = ['ALL', ...s.allGaBoardTypes];
    final usages = const ['ALL', 'YES', 'NO'];
    final lang = context.watch<AppState>().lang;
    final filteredTags = s.allTags
        .where((t) => tagQuery.trim().isEmpty ? true : t.toLowerCase().contains(tagQuery.toLowerCase()))
        .toList();

    return AlertDialog(
      title: Text(I18n.tr(lang, 'addIssue')),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: symptomCtrl,
                decoration: InputDecoration(labelText: I18n.tr(s.lang, 'symptom')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: causeCtrl,
                decoration: InputDecoration(labelText: I18n.tr(s.lang, 'cause')),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: model,
                      decoration: InputDecoration(labelText: I18n.tr(s.lang, 'model')),
                      items: models.map((e) => DropdownMenuItem(value: e, child: Text(e == 'ALL' ? e : s.labelOf(e)))).toList(),
                      onChanged: (v) => setState(() => model = v ?? 'ALL'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: gaUsage,
                      decoration: InputDecoration(labelText: I18n.tr(s.lang, 'gaUsage')),
                      items: usages.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => gaUsage = v ?? 'ALL'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: gaBoard,
                decoration: InputDecoration(labelText: I18n.tr(s.lang, 'gaBoard')),
                items: boards.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => gaBoard = v ?? 'ALL'),
              ),

              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('${I18n.tr(s.lang, 'tags')} (${I18n.tr(s.lang, 'multiSelect')})',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 6),
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: I18n.tr(s.lang, 'tagSearch'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => tagQuery = v),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: filteredTags.take(80).map((tag) {
                    final sel = selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(s.labelOf(tag)),
                      selected: sel,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            selectedTags.add(tag);
                          } else {
                            selectedTags.remove(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(I18n.tr(s.lang, 'solutions'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      setState(() {
                        draftSolutions.add(_DraftSolution(title: 'Try ${draftSolutions.length + 1}', steps: ['Step 1']));
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: Text(I18n.tr(s.lang, 'addSolution')),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              for (int si = 0; si < draftSolutions.length; si++) ...[
                _SolutionEditorCard(
                  lang: s.lang,
                  index: si,
                  solution: draftSolutions[si],
                  onDelete: draftSolutions.length <= 1
                      ? null
                      : () => setState(() => draftSolutions.removeAt(si)),
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(I18n.tr(s.lang, 'cancel')),
        ),
        FilledButton(
          onPressed: () async {
            if (symptomCtrl.text.trim().isEmpty || causeCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(I18n.tr(s.lang, 'required'))),
              );
              return;
            }
            // validate: all solution titles + step texts non-empty
            for (final sol in draftSolutions) {
              if (sol.title.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${I18n.tr(s.lang, "required")}: ${I18n.tr(s.lang, "solutionTitle")}')),
                );
                return;
              }
              for (final st in sol.steps) {
                if (st.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${I18n.tr(s.lang, "required")}: ${I18n.tr(s.lang, "stepText")}')),
                  );
                  return;
                }
              }
            }

            final newId = 'T${DateTime.now().microsecondsSinceEpoch}';
            final newItem = TroubleItem(
              id: newId,
              symptom: symptomCtrl.text.trim(),
              cause: causeCtrl.text.trim(),
              tags: selectedTags.toList(),
              applicability: Applicability(
                models: [model],
                gaUsage: gaUsage,
                gaBoardTypes: [gaBoard],
              ),
              solutions: draftSolutions
                  .map(
                    (d) => SolutionItem(
                      title: d.title.trim(),
                      steps: d.steps.map((t) => StepItem(text: t.trim())).toList(),
                    ),
                  )
                  .toList(),
            );
            final nav = Navigator.of(context);
            final st = context.read<AppState>();

            await st.addTrouble(newItem);
            if (!mounted) return;
            nav.pop();
          },
          child: Text(I18n.tr(s.lang, 'save')),
        ),
      ],
    );
  }
}




class _DraftSolution {
  String title;
  final List<String> steps;
  _DraftSolution({required this.title, required this.steps});
}

class _SolutionEditorCard extends StatelessWidget {
  final String lang;
  final int index;
  final _DraftSolution solution;
  final VoidCallback? onDelete;
  final VoidCallback onChanged;

  const _SolutionEditorCard({
    required this.lang,
    required this.index,
    required this.solution,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: solution.title,
                    decoration: InputDecoration(
                      labelText: '${I18n.tr(lang, "solutionTitle")} #${index + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      solution.title = v;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                if (onDelete != null)
                  IconButton(
                    tooltip: I18n.tr(lang, 'removeSolution'),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(child: Text(I18n.tr(lang, 'steps'), style: const TextStyle(fontWeight: FontWeight.w700))),
                FilledButton.tonalIcon(
                  onPressed: () {
                    solution.steps.add('Step ${solution.steps.length + 1}');
                    onChanged();
                  },
                  icon: const Icon(Icons.add),
                  label: Text(I18n.tr(lang, 'addStep')),
                ),
              ],
            ),
            const SizedBox(height: 8),

            for (int i = 0; i < solution.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: solution.steps[i],
                        decoration: InputDecoration(
                          labelText: '${I18n.tr(lang, "stepText")} ${i + 1}',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          solution.steps[i] = v;
                          onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: I18n.tr(lang, 'removeStep'),
                      onPressed: solution.steps.length <= 1
                          ? null
                          : () {
                              solution.steps.removeAt(i);
                              onChanged();
                            },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GuideSectionScreen extends StatelessWidget {
  final GuideSection section;
  final String appBarTitle;
  final bool preferImageCaptionLayout;

  const GuideSectionScreen({
    super.key,
    required this.section,
    required this.appBarTitle,
    this.preferImageCaptionLayout = false,
  });

  List<GuideImageItem> _buildCaptionItemsFromStep(GuideStep step) {
    final koLines = <String>[
      ...step.paragraphs.where((e) => e.trim().isNotEmpty),
      ...step.bullets.where((e) => e.trim().isNotEmpty).map((e) => '• $e'),
    ];
    final enLines = <String>[
      ...?step.paragraphsEn?.where((e) => e.trim().isNotEmpty),
      ...?step.bulletsEn?.where((e) => e.trim().isNotEmpty).map((e) => '• $e'),
    ];

    final imagesWithAsset = step.images
        .map((img) => GuideImageItem(
              asset: GuideAssetPath.sanitize(img.asset),
              caption: img.caption,
              captionEn: img.captionEn,
            ))
        .where((img) => GuideAssetPath.isRenderable(img.asset))
        .toList();

    final out = <GuideImageItem>[];
    for (int i = 0; i < koLines.length; i++) {
      final mappedAsset = (i < imagesWithAsset.length) ? imagesWithAsset[i].asset : '';
      out.add(
        GuideImageItem(
          asset: mappedAsset,
          caption: koLines[i],
          captionEn: i < enLines.length ? enLines[i] : null,
        ),
      );
    }

    // Keep non-placeholder image captions that are not already represented.
    for (final img in step.images) {
      final ko = img.caption.trim();
      final en = (img.captionEn ?? '').trim();
      final norm = ko.toLowerCase();
      final isTodo = norm == 'todo' || norm == 'todo2' || norm == 'todo:';
      if (ko.isEmpty || isTodo || koLines.contains(ko)) continue;
      out.add(
        GuideImageItem(
          asset: GuideAssetPath.sanitize(img.asset),
          caption: ko,
          captionEn: en.isEmpty ? null : en,
        ),
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle), 
        actions: const [
          _LanguageToggleButton(),
          SizedBox(width: 8),
        ],),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: section.steps.map((step) {
          return Card(
            child: ExpansionTile(
              title: Align(
                alignment: Alignment.centerLeft,
                child: Text(step.titleByLang(lang), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              children: [
                if (!preferImageCaptionLayout) ...[
                  // ✅ 글(가이드)은 기본으로 항상 보이게 (왼쪽 정렬)
                  ...step.paragraphsByLang(lang).map((p) => _paragraphLeft(p)),
                  ...step.bulletsByLang(lang).map((b) => _bulletLeft(b)),
                ],

                // ✅ 표는 글 성격이니 기본 영역에 그대로
                ...step.tables.map((t) => _table(t, lang)),

                const SizedBox(height: 8),
                if (preferImageCaptionLayout)
                  ..._buildCaptionItemsFromStep(step).map((gi) => _imageDropdown(context, gi, lang))
                else
                  ...step.images.map((gi) => _imageDropdown(context, gi, lang)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _paragraphLeft(String raw) {
    final isIndented = raw.startsWith('\t');
    final text = raw.replaceFirst('\t', '');
    return Padding(
      padding: EdgeInsets.only(left: isIndented ? 16 : 0, bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          textAlign: TextAlign.left,
        ),
      ),
    );
  }

  Widget _bulletLeft(String b) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 18, child: Text('•', textAlign: TextAlign.left)),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(b, textAlign: TextAlign.left),
              ),
            ),
          ],
        ),
      );

  Widget _table(GuideTable t, String lang) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: t.headersByLang(lang).map((h) => DataColumn(label: Text(h))).toList(),
          rows: t.rowsByLang(lang)
              .map((r) => DataRow(cells: r.map((c) => DataCell(Text(c))).toList()))
              .toList(),
        ),
      );
}

Widget _imageDropdown(BuildContext context, GuideImageItem gi, String lang) {
  final assetPath = GuideAssetPath.sanitize(gi.asset);
  final hasRenderableAsset = GuideAssetPath.isRenderable(assetPath);

  // ✅ 캡션이 가이드 문장(타이틀). 없으면 파일명이라도 표시
  final localizedCaption = gi.captionByLang(lang);
  final title = (localizedCaption.trim().isNotEmpty)
      ? localizedCaption.trim()
      : (hasRenderableAsset ? GuideAssetPath.fileName(assetPath) : '');
  if (title.isEmpty) return const SizedBox.shrink();

  // 카드 안에서 “적절한 너비”
  final maxW = MediaQuery.of(context).size.width;
  final targetW = (maxW > 560) ? 520.0 : (maxW - 48); // 바깥 padding/카드 padding 감안
  const maxH = 320.0;

  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Theme(
      // ExpansionTile 디바이더/여백 좀 깔끔하게
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            textAlign: TextAlign.left,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: targetW,
                  maxHeight: maxH,
                ),
                child: hasRenderableAsset
                    ? Image.asset(
                        assetPath,
                        width: targetW,
                        fit: BoxFit.contain, // ✅ 비율 유지 + 너비 기준
                        errorBuilder: (_, _, _) => Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            I18n.tr(lang, 'imageLoadFailed'),
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          I18n.tr(lang, 'imageLoadFailed'),
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


class InstallTypeSelectScreen extends StatelessWidget {
  const InstallTypeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final sections = s.installSections;

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.tr(context.watch<AppState>().lang, 'installTypeSelect')),
        actions: [
          const _LanguageToggleButton(),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: I18n.tr(s.lang, 'edit'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const GuideAdminScreen(mode: GuideMode.install),
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        itemBuilder: (_, i) {
          final sec = sections[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.tonalIcon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GuideSectionScreen(
                  section: sec,
                  appBarTitle: I18n.tr(context.watch<AppState>().lang, 'installGuide'),
                  preferImageCaptionLayout: false,
                ),),
              ),
              icon: const Icon(Icons.monitor),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(sec.titleByLang(s.lang), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum GuideMode { install, operation }

class GuideAdminScreen extends StatelessWidget {
  final GuideMode mode;
  const GuideAdminScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final sections = mode == GuideMode.install ? s.installSections : s.operationSections;

    return Scaffold(
      appBar: AppBar(
        title: Text(mode == GuideMode.install ? I18n.tr(s.lang, 'editInstallGuide') : I18n.tr(s.lang, 'editOperationGuide')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: I18n.tr(s.lang, 'addSection'),
            onPressed: () async {
              final st = context.read<AppState>();
              final created = await showDialog<GuideSection>(
                context: context,
                builder: (_) => GuideSectionDialog(mode: mode),
              );
              if (created == null) return;

              if (mode == GuideMode.install) {
                await st.addInstallSection(created);
              } else {
                await st.addOperationSection(created);
              }
            },
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final sec = sections[i];

          return ListTile(
            title: Text(sec.titleByLang(s.lang)),
            subtitle: Text(sec.id, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: I18n.tr(s.lang, 'edit'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final st = context.read<AppState>(); 
                    final updated = await Navigator.push<GuideSection>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GuideSectionEditScreen(mode: mode, section: sec),
                      ),
                    );
                    if (updated == null) return;

                    if (mode == GuideMode.install) {
                      await st.updateInstallSection(updated);
                    } else {
                      await st.updateOperationSection(updated);
                    }
                  },
                ),
                IconButton(
                  tooltip: I18n.tr(s.lang, 'delete'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final st = context.read<AppState>();
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(I18n.tr(s.lang, 'deleteQuestion')),
                        content: Text(I18n.trf(s.lang, 'sectionDeleteConfirm', {'title': sec.titleByLang(s.lang)})),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(I18n.tr(s.lang, 'cancel'))),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(I18n.tr(s.lang, 'delete'))),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    if (mode == GuideMode.install) {
                      await st.deleteInstallSection(sec.id);
                    } else {
                      await st.deleteOperationSection(sec.id);
                    }
                  },
                ),
              ],
            ),
            onTap: () async {
              final st = context.read<AppState>();
              final updated = await Navigator.push<GuideSection>(
                context,
                MaterialPageRoute(
                  builder: (_) => GuideSectionEditScreen(mode: mode, section: sec),
                ),
              );
              if (updated == null) return;

              if (mode == GuideMode.install) {
                await st.updateInstallSection(updated);
              } else {
                await st.updateOperationSection(updated);
              }
            },
          );
        },
      ),
    );
  }
}

class GuideSectionDialog extends StatefulWidget {
  final GuideMode mode;
  const GuideSectionDialog({super.key, required this.mode});

  @override
  State<GuideSectionDialog> createState() => _GuideSectionDialogState();
}

class _GuideSectionDialogState extends State<GuideSectionDialog> {
  final titleCtrl = TextEditingController();

  @override
  void dispose() {
    titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefix = widget.mode == GuideMode.install ? 'installation' : 'operation';
    final lang = context.watch<AppState>().lang;
    return AlertDialog(
      title: Text(I18n.tr(context.watch<AppState>().lang, 'addSection')),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: I18n.tr(lang, 'sectionTitleButton'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              I18n.trf(lang, 'idAutoGenerated', {'id': '$prefix:1700000000'}),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(I18n.tr(context.watch<AppState>().lang, 'cancel'))),
        FilledButton(
          onPressed: () {
            final title = titleCtrl.text.trim();
            if (title.isEmpty) return;

            final id = '$prefix:${DateTime.now().microsecondsSinceEpoch}';
            final sec = GuideSection(id: id, title: title, titleEn: '', steps: [
              GuideStep(
                title: 'Step 1. ',
                images: const [],
                paragraphs: const ['내용을 입력하세요'],
                bullets: const [],
                tables: const [],
              ),
            ]);

            Navigator.pop(context, sec);
          },
          child: Text(I18n.tr(context.watch<AppState>().lang, 'create')),
        ),
      ],
    );
  }
}

class GuideSectionEditScreen extends StatefulWidget {
  final GuideMode mode;
  final GuideSection section;
  
  const GuideSectionEditScreen({super.key, required this.mode, required this.section});

  @override
  State<GuideSectionEditScreen> createState() => _GuideSectionEditScreenState();
}

class _GuideSectionEditScreenState extends State<GuideSectionEditScreen> {
  late GuideSection draft;
  late TextEditingController titleCtrl;
  late TextEditingController titleEnCtrl;

  @override
  void initState() {
    super.initState();
    draft = GuideSection.fromJson(widget.section.toJson());
    titleCtrl = TextEditingController(text: draft.title);
    titleEnCtrl = TextEditingController(text: draft.titleEn); // ✅ 추가
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    titleEnCtrl.dispose(); // ✅ 추가
    super.dispose();
  }

  void _addStep() {
    setState(() {
      final n = draft.steps.length + 1;
      draft = GuideSection(
        id: draft.id,
        title: draft.title,
        titleEn: draft.titleEn,
        steps: [
          ...draft.steps,
          GuideStep(title: 'Step $n', paragraphs: const [''], bullets: const [], images: const [], tables: const []),
        ],
      );
    });
  }

  void _deleteStep(int index) {
    setState(() {
      final next = [...draft.steps]..removeAt(index);
      draft = GuideSection(id: draft.id, title: draft.title, titleEn: draft.titleEn, steps: next.isEmpty
  ? [
      GuideStep(
        title: 'Step 1',
        images: const [],
        paragraphs: const [''],
        bullets: const [],
        tables: const [],
      )
    ]
  : next);
    });
  }

  void _updateStep(int index, GuideStep step) {
    setState(() {
      final next = [...draft.steps];
      next[index] = step;
      draft = GuideSection(id: draft.id, title: draft.title, titleEn: draft.titleEn, steps: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.tr(lang, 'editSection')),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: I18n.tr(lang, 'save'),
            onPressed: () {
              final t = titleCtrl.text.trim();
              if (t.isEmpty) return;

              final tEn = titleEnCtrl.text.trim(); // ✅ 추가
              final saved = GuideSection(
                id: draft.id,
                title: t,
                titleEn: tEn,        // ✅ 반영
                steps: draft.steps,
              );
              Navigator.pop(context, saved);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: titleCtrl,
            decoration: InputDecoration(
              labelText: I18n.tr(lang, 'sectionTitle'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: titleEnCtrl,
            decoration: InputDecoration(
              labelText: '${I18n.tr(lang, 'sectionTitle')} (EN)',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Text(
                  I18n.tr(lang, 'stepsEn'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _addStep,
                icon: const Icon(Icons.add),
                label: Text(I18n.tr(lang, 'addStepItem')),
              ),
            ],
          ),
          const SizedBox(height: 10),

          for (int i = 0; i < draft.steps.length; i++) ...[
            GuideStepEditCard(
              index: i,
              step: draft.steps[i],
              onChanged: (st) => _updateStep(i, st),
              onDelete: draft.steps.length <= 1 ? null : () => _deleteStep(i),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class GuideStepEditCard extends StatefulWidget {
  final int index;
  final GuideStep step;
  final ValueChanged<GuideStep> onChanged;
  final VoidCallback? onDelete;

  const GuideStepEditCard({
    super.key,
    required this.index,
    required this.step,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<GuideStepEditCard> createState() => _GuideStepEditCardState();
}

class _GuideStepEditCardState extends State<GuideStepEditCard> {
  late TextEditingController titleCtrl;

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.step.title);
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    super.dispose();
  }

  GuideStep _emit({
    String? title,
    String? titleEn,
    List<String>? paragraphs,
    List<String>? bullets,
    List<GuideImageItem>? images,
    List<String>? paragraphsEn,
    List<String>? bulletsEn,
    List<GuideTable>? tables,
  }) {
    final cur = widget.step;
    return GuideStep(
      title: title ?? cur.title,
      titleEn: titleEn ?? cur.titleEn,            // ✅ 보존
      paragraphs: paragraphs ?? cur.paragraphs,
      bullets: bullets ?? cur.bullets,
      images: images ?? cur.images,
      tables: tables ?? cur.tables,
      paragraphsEn: paragraphsEn ?? cur.paragraphsEn, // ✅ 보존
      bulletsEn: bulletsEn ?? cur.bulletsEn,           // ✅ 보존
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.step;
    final lang = context.watch<AppState>().lang;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: "${I18n.tr(context.watch<AppState>().lang, 'stepTitle')} #${widget.index + 1}",
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      widget.onChanged(_emit(title: v.trim().isEmpty ? st.title : v));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.onDelete != null)
                  IconButton(
                    tooltip: I18n.tr(context.watch<AppState>().lang, 'deleteStep'),
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            _ListEditor(
              label: I18n.tr(lang, 'paragraphs'),
              items: st.paragraphs,
              hint: I18n.tr(lang, 'hint_paragraph_example'),
              onChanged: (list) => widget.onChanged(_emit(paragraphs: list)),
            ),

            const SizedBox(height: 12),

            _ListEditor(
              label: I18n.tr(lang, 'bullets'),
              items: st.bullets,
              hint: I18n.tr(lang, 'hint_bullet_example'),
              onChanged: (list) => widget.onChanged(_emit(bullets: list)),
            ),

            const SizedBox(height: 12),

            _ImageListEditor(
              images: st.images,
              onChanged: (imgs) => widget.onChanged(_emit(images: imgs)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListEditor extends StatelessWidget {
  final String label;
  final List<String> items;
  final String hint;
  final ValueChanged<List<String>> onChanged;

  const _ListEditor({
    required this.label,
    required this.items,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
            FilledButton.tonalIcon(
              onPressed: () => onChanged([...items, '']),
              icon: const Icon(Icons.add),
              label: Text(I18n.tr(context.watch<AppState>().lang, 'add')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: items[i],
                    decoration: InputDecoration(
                      labelText: '$label ${i + 1}',
                      hintText: hint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final next = [...items];
                      next[i] = v;
                      onChanged(next);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: I18n.tr(context.watch<AppState>().lang, 'delete'),
                  onPressed: items.length <= 1
                      ? null
                      : () {
                          final next = [...items]..removeAt(i);
                          onChanged(next);
                        },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ImageListEditor extends StatelessWidget {
  final List<GuideImageItem> images;
  final ValueChanged<List<GuideImageItem>> onChanged;

  const _ImageListEditor({required this.images, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(I18n.tr(context.watch<AppState>().lang, 'images'), style: const TextStyle(fontWeight: FontWeight.w700))),
            FilledButton.tonalIcon(
              onPressed: () => onChanged([...images, GuideImageItem(asset: 'assets/images/xxx.png', caption: '')]),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(I18n.tr(context.watch<AppState>().lang, 'add')),
            ),
          ],
        ),
        const SizedBox(height: 8),

        for (int i = 0; i < images.length; i++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  TextFormField(
                    initialValue: images[i].asset,
                    decoration: InputDecoration(
                      labelText: I18n.tr(lang, 'assetPath'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final next = [...images];
                      next[i] = GuideImageItem(
                        asset: v.trim(),
                        caption: images[i].caption,
                        captionEn: images[i].captionEn,
                      );
                      onChanged(next);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: images[i].captionEn ?? '',
                    decoration: InputDecoration(
                      labelText: 'Caption (EN)', // 필요하면 i18n 키로 변경
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final next = [...images];
                      next[i] = GuideImageItem(
                        asset: images[i].asset,
                        caption: images[i].caption,
                        captionEn: v.trim().isEmpty ? null : v,
                      );
                      onChanged(next);
                    },
                  ),
                  const SizedBox(height: 8),

                  // 미리보기 (경로가 올바르고 pubspec에 등록돼 있으면 표시됨)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: images.length <= 1
                              ? null
                              : () {
                                  final next = [...images]..removeAt(i);
                                  onChanged(next);
                                },
                          icon: const Icon(Icons.delete_outline),
                          label: Text(I18n.tr(context.watch<AppState>().lang, 'delete')),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  _AssetPreview(path: images[i].asset),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AssetPreview extends StatelessWidget {
  final String path;
  const _AssetPreview({required this.path});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    if (!path.startsWith('assets/')) {
      return Text(I18n.tr(context.watch<AppState>().lang, 'previewNeedAssetPath'), style: const TextStyle(fontSize: 12, color: Colors.white70));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        path,
        height: 160,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Padding(
          padding: EdgeInsets.all(8),
          
          child: Text(I18n.tr(lang, 'imageLoadFailed'), style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ),
      ),
    );
  }
}


class OperationGuideScreen extends StatelessWidget {
  const OperationGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final sections = s.operationSections;

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.tr(context.watch<AppState>().lang, 'operationTypeSelect')),
        actions: [
          const _LanguageToggleButton(),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: I18n.tr(s.lang, 'edit'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const GuideAdminScreen(mode: GuideMode.operation),
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        itemBuilder: (_, i) {
          final sec = sections[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.tonalIcon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GuideSectionScreen(
                    section: sec,
                    appBarTitle: sec.titleByLang(s.lang),
                    preferImageCaptionLayout: true,
                  ),
                ),
              ),
              icon: const Icon(Icons.menu_book),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(sec.titleByLang(s.lang), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


enum ChecklistType { exhibition, demo, clinical }

class ChecklistTypeSelectScreen extends StatelessWidget {
  const ChecklistTypeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChecklistEventListScreen();
  }
}

class ChecklistEventInput {
  final String eventName;
  final DateTime eventDate;
  final ChecklistType? initialType;

  const ChecklistEventInput({
    required this.eventName,
    required this.eventDate,
    this.initialType,
  });
}

class ChecklistEventListScreen extends StatelessWidget {
  const ChecklistEventListScreen({super.key});

  Future<void> _openEvent(BuildContext context, ChecklistEventSummary event) async {
    final existing = event.recordIds;
    if (existing.length == 1) {
      final first = existing.entries.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChecklistScreen(type: first.key, recordId: first.value),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChecklistSelectedTypeListScreen(
          eventName: event.eventName,
          eventDate: event.eventDate,
          recordIds: existing,
        ),
      ),
    );
  }

  Future<void> _createEvent(BuildContext context) async {
    final lang = context.read<AppState>().lang;
    final input = await showDialog<ChecklistEventInput>(
      context: context,
      builder: (_) => _ChecklistEventDialog(
        title: I18n.tr(lang, 'addEvent'),
        submitLabel: I18n.tr(lang, 'create'),
        showTypeSelector: true,
        initialType: ChecklistType.exhibition,
      ),
    );
    if (!context.mounted || input == null || input.initialType == null) return;

    final st = context.read<AppState>();
    final duplicated = st.findChecklistEventSummaryByNameDate(input.eventName, input.eventDate);
    if (duplicated != null) {
      final goExisting = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(I18n.tr(lang, 'duplicateEventTitle')),
          content: Text(
            I18n.trf(
              lang,
              'duplicateEventMessage',
              {'name': duplicated.eventName},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(I18n.tr(lang, 'cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(I18n.tr(lang, 'openExisting')),
            ),
          ],
        ),
      );
      if (!context.mounted || goExisting != true) return;
      final recordId = await st.getOrCreateChecklistRecordForEventType(
        type: input.initialType!,
        eventName: duplicated.eventName,
        eventDate: duplicated.eventDate,
      );
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChecklistScreen(type: input.initialType!, recordId: recordId),
        ),
      );
      return;
    }

    final id = await st.createChecklistRecord(
      type: input.initialType!,
      eventName: input.eventName,
      eventDate: input.eventDate,
    );
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChecklistScreen(type: input.initialType!, recordId: id),
      ),
    );
  }

  Future<void> _editEvent(BuildContext context, ChecklistEventSummary event) async {
    final lang = context.read<AppState>().lang;
    final input = await showDialog<ChecklistEventInput>(
      context: context,
      builder: (_) => _ChecklistEventDialog(
        title: I18n.tr(lang, 'editEvent'),
        submitLabel: I18n.tr(lang, 'save'),
        initialName: event.eventName,
        initialDate: event.eventDate,
      ),
    );
    if (!context.mounted || input == null) return;
    await context.read<AppState>().updateChecklistEventAcrossTypes(
          summary: event,
          eventName: input.eventName,
          eventDate: input.eventDate,
        );
  }

  Future<void> _deleteEvent(BuildContext context, ChecklistEventSummary event) async {
    final lang = context.read<AppState>().lang;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(I18n.tr(lang, 'deleteQuestion')),
        content: Text(
          I18n.trf(
            lang,
            'eventDeleteConfirm',
            {'name': event.eventName},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(I18n.tr(lang, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(I18n.tr(lang, 'delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    final st = context.read<AppState>();
    final removed = await st.deleteChecklistEventAcrossTypes(event);
    if (!context.mounted || removed.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final action = await messenger.showSnackBar(
      SnackBar(
        content: Text(I18n.trf(lang, 'eventDeleted', {'name': event.eventName})),
        action: SnackBarAction(
          label: I18n.tr(lang, 'undo'),
          onPressed: () {},
        ),
      ),
    ).closed;
    if (!context.mounted) return;
    if (action == SnackBarClosedReason.action) {
      await st.restoreChecklistRecords(removed);
    }
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white70),
        ),
      );

  Widget _eventTile(BuildContext context, ChecklistEventSummary event, String lang) {
    final st = context.watch<AppState>();
    final date = DateFormat('yyyy-MM-dd').format(event.eventDate);
    final updated = DateFormat('yyyy-MM-dd HH:mm').format(event.updatedAt);
    final typesText = ChecklistType.values
        .where((t) => event.recordIds.containsKey(t))
        .map((t) => checklistTypeLabel(lang, t))
        .join(', ');
    final progress = st.summarizeChecklistEvent(event);
    return Card(
      child: ListTile(
        title: Text(event.eventName),
        subtitle: Text(
          '${I18n.tr(lang, 'eventDate')}: $date\n'
          '${I18n.tr(lang, 'eventTypesLabel')}: $typesText  •  ${I18n.tr(lang, 'updatedLabel')}: $updated\n'
          'O: ${progress.ok} · ${I18n.tr(lang, 'status_verifying')}: ${progress.verifying} · X: ${progress.fail}',
        ),
        onTap: () => _openEvent(context, event),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: I18n.tr(lang, 'editEvent'),
              onPressed: () => _editEvent(context, event),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: I18n.tr(lang, 'delete'),
              onPressed: () => _deleteEvent(context, event),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final lang = st.lang;
    final allEvents = [...st.loadChecklistEventSummaries()];
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    bool isSameDate(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    final todayEvents = allEvents.where((e) => isSameDate(e.eventDate, todayDate)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final upcomingEvents = allEvents.where((e) => e.eventDate.isAfter(todayDate)).toList()
      ..sort((a, b) {
        final d = a.eventDate.compareTo(b.eventDate);
        if (d != 0) return d;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    final pastEvents = allEvents.where((e) => e.eventDate.isBefore(todayDate)).toList()
      ..sort((a, b) {
        final d = b.eventDate.compareTo(a.eventDate);
        if (d != 0) return d;
        return b.updatedAt.compareTo(a.updatedAt);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.tr(lang, 'checklist')),
        actions: [
          const _LanguageToggleButton(),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: I18n.tr(lang, 'addEvent'),
            onPressed: () => _createEvent(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              I18n.tr(lang, 'selectEventFirst'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          if (allEvents.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(I18n.tr(lang, 'noEvents')),
                ),
              ),
            ),
          if (todayEvents.isNotEmpty) _sectionTitle(I18n.tr(lang, 'todayEvents')),
          ...todayEvents.map((e) => _eventTile(context, e, lang)),
          if (upcomingEvents.isNotEmpty) _sectionTitle(I18n.tr(lang, 'upcomingEvents')),
          ...upcomingEvents.map((e) => _eventTile(context, e, lang)),
          if (pastEvents.isNotEmpty) _sectionTitle(I18n.tr(lang, 'pastEvents')),
          ...pastEvents.map((e) => _eventTile(context, e, lang)),
        ],
      ),
    );
  }
}

class ChecklistSelectedTypeListScreen extends StatelessWidget {
  final String eventName;
  final DateTime eventDate;
  final Map<ChecklistType, String> recordIds;

  const ChecklistSelectedTypeListScreen({
    super.key,
    required this.eventName,
    required this.eventDate,
    required this.recordIds,
  });

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final lang = st.lang;
    final date = DateFormat('yyyy-MM-dd').format(eventDate);
    final summary = st.findChecklistEventSummaryByNameDate(eventName, eventDate);
    final liveRecordIds = summary?.recordIds ?? recordIds;
    final selectedTypes = ChecklistType.values.where((t) => liveRecordIds.containsKey(t)).toList();
    final missingTypes = ChecklistType.values.where((t) => !liveRecordIds.containsKey(t)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(eventName),
        actions: [
          const _LanguageToggleButton(),
          if (missingTypes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: I18n.tr(lang, 'add'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChecklistTypeByEventScreen(
                    eventName: eventName,
                    eventDate: eventDate,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${I18n.tr(lang, 'eventDate')}: $date',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 10),
          if (selectedTypes.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(I18n.tr(lang, 'noItems')),
                ),
              ),
            ),
          ...selectedTypes.map((type) {
            final id = liveRecordIds[type]!;
            return Card(
              child: ListTile(
                leading: Icon(
                  type == ChecklistType.exhibition
                      ? Icons.event
                      : (type == ChecklistType.demo ? Icons.play_circle_outline : Icons.local_hospital),
                ),
                title: Text(checklistTypeLabel(lang, type)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChecklistScreen(type: type, recordId: id),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class ChecklistTypeByEventScreen extends StatelessWidget {
  final String eventName;
  final DateTime eventDate;

  const ChecklistTypeByEventScreen({
    super.key,
    required this.eventName,
    required this.eventDate,
  });

  Future<void> _openType(BuildContext context, ChecklistType type) async {
    final st = context.read<AppState>();
    final id = await st.getOrCreateChecklistRecordForEventType(
      type: type,
      eventName: eventName,
      eventDate: eventDate,
    );
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChecklistScreen(type: type, recordId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final lang = st.lang;
    final date = DateFormat('yyyy-MM-dd').format(eventDate);

    Widget btn(ChecklistType t, String label, IconData icon) {
      final exists = st.findChecklistRecordByEventAndType(t, eventName, eventDate) != null;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SizedBox(
          width: double.infinity,
          height: 64,
          child: FilledButton.tonalIcon(
            onPressed: () => _openType(context, t),
            icon: Icon(icon),
            label: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                if (exists)
                  const Icon(Icons.check_circle_outline, size: 18),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(eventName),
        actions: const [
          _LanguageToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${I18n.tr(lang, 'eventDate')}: $date',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    I18n.tr(lang, 'selectChecklistType'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                btn(ChecklistType.exhibition, I18n.tr(lang, 'exhibition'), Icons.event),
                btn(ChecklistType.demo, I18n.tr(lang, 'demo'), Icons.play_circle_outline),
                btn(ChecklistType.clinical, I18n.tr(lang, 'clinical'), Icons.local_hospital),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChecklistEventDialog extends StatefulWidget {
  final String title;
  final String submitLabel;
  final String? initialName;
  final DateTime? initialDate;
  final bool showTypeSelector;
  final ChecklistType? initialType;

  const _ChecklistEventDialog({
    required this.title,
    required this.submitLabel,
    this.initialName,
    this.initialDate,
    this.showTypeSelector = false,
    this.initialType,
  });

  @override
  State<_ChecklistEventDialog> createState() => _ChecklistEventDialogState();
}

class _ChecklistEventDialogState extends State<_ChecklistEventDialog> {
  late final TextEditingController _nameCtrl;
  late DateTime _eventDate;
  ChecklistType? _type;
  bool _showNameError = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    final base = widget.initialDate ?? DateTime.now();
    _eventDate = DateTime(base.year, base.month, base.day);
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (selected == null) return;
    setState(() => _eventDate = DateTime(selected.year, selected.month, selected.day));
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;
    final dateText = DateFormat('yyyy-MM-dd').format(_eventDate);

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              onChanged: (_) {
                if (_showNameError && _nameCtrl.text.trim().isNotEmpty) {
                  setState(() => _showNameError = false);
                }
              },
              decoration: InputDecoration(
                labelText: I18n.tr(lang, 'eventName'),
                hintText: I18n.tr(lang, 'eventNameHint'),
                errorText: _showNameError ? I18n.tr(lang, 'required') : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: I18n.tr(lang, 'eventDate'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(dateText)),
                    const Icon(Icons.calendar_month_outlined, size: 18),
                  ],
                ),
              ),
            ),
            if (widget.showTypeSelector) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<ChecklistType>(
                initialValue: _type,
                decoration: InputDecoration(
                  labelText: I18n.tr(lang, 'type'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: ChecklistType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(checklistTypeLabel(lang, t)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _type = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(I18n.tr(lang, 'cancel')),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) {
              setState(() => _showNameError = true);
              return;
            }
            Navigator.pop(
              context,
              ChecklistEventInput(
                eventName: name,
                eventDate: _eventDate,
                initialType: _type,
              ),
            );
          },
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}

enum ChecklistStatus { ok, verifying, fail }

String statusLabel(String lang, ChecklistStatus s) {
  switch (s) {
    case ChecklistStatus.ok:
      return 'O'; // 심볼은 그대로 OK
    case ChecklistStatus.verifying:
      return I18n.tr(lang, 'status_verifying');
    case ChecklistStatus.fail:
      return 'X';
  }
}

ChecklistStatus statusFromLabel(String v) {
  if (v == 'O') return ChecklistStatus.ok;
  if (v == 'X') return ChecklistStatus.fail;
  return ChecklistStatus.verifying;
}

class ChecklistRow {
  String name;
  int qty;
  ChecklistStatus status;
  String note;
  Uint8List? imageBytes;
  String? imageAssetPath;
  String? variant;      

  ChecklistRow({
    required this.name,
    this.qty = 1,
    this.status = ChecklistStatus.verifying,
    this.note = '',
    this.imageBytes,
    this.imageAssetPath,
    this.variant,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'qty': qty,
    'status': status.name, // ✅ 언어 무관
    'note': note,
    'image_b64': imageBytes == null ? null : base64Encode(imageBytes!),
    'image_asset': imageAssetPath,
    'variant': variant,
  };

  factory ChecklistRow.fromJson(Map<String, dynamic> j) => ChecklistRow(
    name: (j['name'] ?? '').toString(),
    qty: int.tryParse((j['qty'] ?? 1).toString()) ?? 1,
    status: ChecklistStatus.values.firstWhere(
      (e) => e.name == (j['status'] ?? 'verifying').toString(),
      orElse: () => ChecklistStatus.verifying,
    ),
    note: (j['note'] ?? '').toString(),
    imageBytes: (j['image_b64'] == null) ? null : base64Decode(j['image_b64'] as String),
    imageAssetPath: (j['image_asset'] as String?)?.trim().isEmpty == true ? null : (j['image_asset'] as String?),
    variant: (j['variant'] as String?)?.trim().isEmpty == true ? null : (j['variant'] as String?),
  );
}

class ChecklistRecord {
  final String id;
  final ChecklistType type;
  final String eventName;
  final DateTime eventDate;
  final DateTime updatedAt;
  final Map<String, List<ChecklistRow>> rows;

  ChecklistRecord({
    required this.id,
    required this.type,
    required this.eventName,
    required this.eventDate,
    required this.updatedAt,
    required this.rows,
  });

  ChecklistRecord copyWith({
    String? id,
    ChecklistType? type,
    String? eventName,
    DateTime? eventDate,
    DateTime? updatedAt,
    Map<String, List<ChecklistRow>>? rows,
  }) {
    return ChecklistRecord(
      id: id ?? this.id,
      type: type ?? this.type,
      eventName: eventName ?? this.eventName,
      eventDate: eventDate ?? this.eventDate,
      updatedAt: updatedAt ?? this.updatedAt,
      rows: rows ?? this.rows,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'event_name': eventName,
        'event_date': eventDate.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'rows': rows.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
      };

  factory ChecklistRecord.fromJson(Map<String, dynamic> j) {
    ChecklistType parseType(String raw) {
      for (final t in ChecklistType.values) {
        if (t.name == raw) return t;
      }
      return ChecklistType.exhibition;
    }

    Map<String, List<ChecklistRow>> decodeRows(dynamic raw) {
      final out = <String, List<ChecklistRow>>{};
      if (raw is! Map) return out;
      final m = raw.cast<String, dynamic>();

      for (final group in AppState.checklistGroupNames) {
        final rawList = m[group];
        if (rawList is List) {
          out[group] = rawList
              .whereType<Map>()
              .map((e) => ChecklistRow.fromJson(e.cast<String, dynamic>()))
              .toList();
        } else {
          out[group] = <ChecklistRow>[];
        }
      }
      for (final entry in m.entries) {
        if (out.containsKey(entry.key)) continue;
        final rawList = entry.value;
        if (rawList is List) {
          out[entry.key] = rawList
              .whereType<Map>()
              .map((e) => ChecklistRow.fromJson(e.cast<String, dynamic>()))
              .toList();
        }
      }
      return out;
    }

    return ChecklistRecord(
      id: (j['id'] ?? '').toString(),
      type: parseType((j['type'] ?? '').toString()),
      eventName: (j['event_name'] ?? '').toString(),
      eventDate: DateTime.tryParse((j['event_date'] ?? '').toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((j['updated_at'] ?? '').toString()) ?? DateTime.now(),
      rows: decodeRows(j['rows']),
    );
  }
}

class ChecklistEventSummary {
  final String eventName;
  final DateTime eventDate;
  final DateTime updatedAt;
  final Map<ChecklistType, String> recordIds;

  ChecklistEventSummary({
    required this.eventName,
    required this.eventDate,
    required this.updatedAt,
    required this.recordIds,
  });

  ChecklistEventSummary copyWith({
    String? eventName,
    DateTime? eventDate,
    DateTime? updatedAt,
    Map<ChecklistType, String>? recordIds,
  }) {
    return ChecklistEventSummary(
      eventName: eventName ?? this.eventName,
      eventDate: eventDate ?? this.eventDate,
      updatedAt: updatedAt ?? this.updatedAt,
      recordIds: recordIds ?? this.recordIds,
    );
  }
}

class ChecklistEventProgress {
  final int ok;
  final int verifying;
  final int fail;

  const ChecklistEventProgress({
    required this.ok,
    required this.verifying,
    required this.fail,
  });
}

class ChecklistScreen extends StatefulWidget {
  final ChecklistType type;
  final String recordId;
  const ChecklistScreen({super.key, required this.type, required this.recordId});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final record = s.getChecklistRecord(widget.type, widget.recordId);
    final lang = context.watch<AppState>().lang;

    if (record == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(I18n.tr(lang, 'checklist')),
          actions: const [
            _LanguageToggleButton(),
            SizedBox(width: 8),
          ],
        ),
        body: Center(
          child: Text(I18n.tr(lang, 'checklistRecordNotFound')),
        ),
      );
    }

    final data = s.loadChecklistForRecord(widget.type, widget.recordId);
    final eventDate = DateFormat('yyyy-MM-dd').format(record.eventDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${record.eventName} ($eventDate)',
        ),
        actions: const [
          _LanguageToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: AppState.checklistGroupNames.map((group) {
          final rowsRaw = data[group] ?? <ChecklistRow>[];
          final rows = [...rowsRaw]..sort((a, b) {
            int priority(ChecklistRow e) {
              if (e.qty == 0) return 3; // 맨 아래
              if (e.status == ChecklistStatus.ok) return 2; // 그 위 (O)
              if (e.status == ChecklistStatus.verifying) return 1; // 그 위 (검증중)
              return 0; // 나머지 맨 위
            }

            final pa = priority(a);
            final pb = priority(b);

            if (pa != pb) return pa.compareTo(pb);

            return a.name.compareTo(b.name); // 동일 그룹 내 안정 정렬
          });

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(I18n.v(lang, group), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final st = context.read<AppState>();
                        final name = await showDialog<String>(
                          context: context,
                          builder: (_) => const _AddChecklistItemDialog(),
                        );
                        if (!context.mounted) return;
                        if (name == null || name.trim().isEmpty) return;
                        await st.addChecklistRowToRecord(
                          widget.type,
                          widget.recordId,
                          group,
                          ChecklistRow(name: name.trim()),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: Text(I18n.tr(context.watch<AppState>().lang, 'add')),
                    ),
                  ],
                ),
                childrenPadding: const EdgeInsets.only(top: 10),
                children: [
                  if (rows.isEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(I18n.tr(lang, 'noItems'), textAlign: TextAlign.left),
                    ),

                  ...rows.map((r) {
                    final originalIndex = rowsRaw.indexOf(r); // ✅ 원본 index
                    return _ChecklistRowEditor2(
                      key: ValueKey('${widget.recordId}::${widget.type.name}::$group::$originalIndex::${r.name}'),
                      type: widget.type,
                      recordId: widget.recordId,
                      group: group,
                      index: originalIndex, 
                      row: r,
                    );
                  }),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChecklistRowEditor2 extends StatefulWidget {
  final ChecklistType type;
  final String recordId;
  final String group;
  final int index;
  final ChecklistRow row;

  const _ChecklistRowEditor2({
    super.key,
    required this.type,
    required this.recordId,
    required this.group,
    required this.index,
    required this.row,
  });

  @override
  State<_ChecklistRowEditor2> createState() => _ChecklistRowEditor2State();
}

class _ChecklistRowEditor2State extends State<_ChecklistRowEditor2> {
  late final TextEditingController qtyCtrl;
  late final TextEditingController noteCtrl;
  final _picker = ImagePicker(); 
  final FocusNode _qtyFocus = FocusNode();
  final FocusNode _noteFocus = FocusNode();
  Timer? _qtyDebounce;
  Timer? _noteDebounce;
  bool _skipNextNoteUnfocusCommit = false;

  ChecklistRow _copyRow({
    String? name,
    int? qty,
    ChecklistStatus? status,
    String? note,
    Uint8List? imageBytes,
    String? imageAssetPath,
    String? variant, 
    bool clearBytes = false,
    bool clearAsset = false,
  }) {
    final r = widget.row;
    return ChecklistRow(
      name: name ?? r.name,
      qty: qty ?? r.qty,
      status: status ?? r.status,
      note: note ?? r.note,
      imageBytes: clearBytes ? null : (imageBytes ?? r.imageBytes),
      imageAssetPath: clearAsset ? null : (imageAssetPath ?? r.imageAssetPath),
      variant: variant ?? r.variant,  
    );
  }

  Color? _statusColor(ChecklistRow row) {
    if (row.status == ChecklistStatus.verifying) {
      return Colors.yellow.withValues(alpha: 0.18);
    }
    if (row.status == ChecklistStatus.ok) {
      return Colors.green.withValues(alpha: 0.18);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    qtyCtrl = TextEditingController(text: widget.row.qty.toString());
    noteCtrl = TextEditingController(text: widget.row.note);
    _noteFocus.addListener(() {
      if (_noteFocus.hasFocus) return;
      if (_skipNextNoteUnfocusCommit) {
        _skipNextNoteUnfocusCommit = false;
        return;
      }
      if (noteCtrl.text == widget.row.note) return;
      _noteDebounce?.cancel();
      _commit(_copyRow(note: noteCtrl.text));
    });
  }

  @override
  void didUpdateWidget(covariant _ChecklistRowEditor2 oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_qtyFocus.hasFocus && oldWidget.row.qty != widget.row.qty) {
      qtyCtrl.text = widget.row.qty.toString();
    }
    if (!_noteFocus.hasFocus && oldWidget.row.note != widget.row.note) {
      noteCtrl.text = widget.row.note;
    }
  }

  @override
  void dispose() {
    _qtyDebounce?.cancel();
    _noteDebounce?.cancel();
    _qtyFocus.dispose();
    _noteFocus.dispose();
    qtyCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _commit(ChecklistRow next) async {
    await context.read<AppState>().updateChecklistRowInRecord(
          widget.type,
          widget.recordId,
          widget.group,
          widget.index,
          next,
        );
  }

  Future<void> _pickRowPhoto() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (x == null) return;
    final bytes = await x.readAsBytes();

    final row = widget.row;
    await _commit(_copyRow(
      name: row.name,
      qty: row.qty,
      status: row.status,
      note: row.note,
      imageBytes: bytes, // ✅ 저장
    ));
  }

  Future<void> _removeRowPhoto() async {
    final row = widget.row;
    await _commit(_copyRow(
      name: row.name,
      qty: row.qty,
      status: row.status,
      note: row.note,
      imageBytes: null, // ✅ 삭제
    ));
  }

  void _openAssetZoom(String assetPath) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(maxWidth: 980, maxHeight: 740),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(assetPath, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  void _openBytesZoom(Uint8List bytes) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(maxWidth: 980, maxHeight: 740),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumb({
    String? assetPath,
    Uint8List? bytes,
    double size = 40,
  }) {
    Widget image;

    if (assetPath != null && assetPath.trim().isNotEmpty) {
      image = Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 18, color: Colors.white54),
      );
    } else if (bytes != null) {
      image = Image.memory(bytes, width: size, height: size, fit: BoxFit.cover);
    } else {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: const Icon(Icons.photo_outlined, size: 18, color: Colors.white54),
      );
    }

    return InkWell(
      onTap: () {
        if (assetPath != null && assetPath.trim().isNotEmpty) {
          _openAssetZoom(assetPath);
        } else if (bytes != null) {
          _openBytesZoom(bytes);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: size, height: size, child: image),
      ),
    );
  }

  Widget _variantDropdown(ChecklistRow row) {
    const double width = 140;

    final options = kChecklistVariants[row.name];

    // ✅ variant 없는 경우 → 동일 폭 공백
    if (options == null || options.isEmpty) {
      return const SizedBox(width: width);
    }

    final current = (row.variant != null && options.contains(row.variant))
        ? row.variant
        : options.first;
    final lang = context.watch<AppState>().lang;
    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<String>(
        initialValue: current,
        isDense: true,
        decoration: InputDecoration(
          labelText: I18n.tr(lang, 'type'),
          border: const OutlineInputBorder(),
        ),
        items: options
            .map((v) => DropdownMenuItem(value: v, child: Text(I18n.v(lang, v))))
            .toList(),
        onChanged: (v) async {
          if (v == null) return;

          final nextAsset = assetForChecklistItem(row.name, v);

          await _commit(_copyRow(
            variant: v,
            imageAssetPath: nextAsset ?? row.imageAssetPath,
          ));
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final isDisabled = row.qty == 0;
    final lang = context.watch<AppState>().lang;

    const thumbSize = 40.0;

    return LayoutBuilder(
      builder: (ctx, c) {
        final narrow = c.maxWidth < 980; // ✅ 기준은 취향대로 (윈도우 좁게 하면 더 자주 2줄)

        Widget leftMain() {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: thumbSize,
                height: thumbSize,
                child: _buildThumb(
                  assetPath: row.imageAssetPath,
                  bytes: row.imageBytes,
                  size: thumbSize,
                ),
              ),
              const SizedBox(width: 10),

              // ✅ 이름은 무조건 남는 공간을 먹게
              Expanded(
                child: Text(
                  I18n.v(lang, row.name),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 8),

              // ✅ variant 드롭다운 폭 줄이기(가로 overflow 핵심 원인 중 하나)
              SizedBox(
                width: 160,
                child: _variantDropdown(row),
              ),

              const SizedBox(width: 4),

              IconButton(
                tooltip: I18n.tr(lang, 'attachPhoto'),
                onPressed: _pickRowPhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
              ),
              if (row.imageBytes != null)
                IconButton(
                  tooltip: I18n.tr(lang, 'removePhoto'),
                  onPressed: _removeRowPhoto,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          );
        }

        Widget statusBox() {
          return SizedBox(
            width: narrow ? double.infinity : 150,
            child: DropdownButtonFormField<ChecklistStatus>(
              initialValue: row.status,
              isDense: true,
              decoration: InputDecoration(
                labelText: I18n.tr(lang, 'status'),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              items: ChecklistStatus.values
                  .map((st) => DropdownMenuItem(value: st, child: Text(statusLabel(lang, st))))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                await _commit(_copyRow(status: v));
              },
            ),
          );
        }

        Widget noteBox() {
          return TextField(
            controller: noteCtrl,
            focusNode: _noteFocus,
            decoration: InputDecoration(
              labelText: I18n.tr(lang, 'note'),
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
            onChanged: (v) {
              _noteDebounce?.cancel();
              _noteDebounce = Timer(const Duration(milliseconds: 300), () async {
                await _commit(_copyRow(note: v));
              });
            },
            onEditingComplete: () async {
              _noteDebounce?.cancel();
              await _commit(_copyRow(note: noteCtrl.text));
              if (context.mounted) {
                _skipNextNoteUnfocusCommit = true;
                FocusScope.of(context).unfocus();
              }
            },
          );
        }

        Widget qtyBox() {
          return SizedBox(
            width: narrow ? 110 : 70,
            child: TextField(
              controller: qtyCtrl,
              focusNode: _qtyFocus,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: InputDecoration(
                labelText: I18n.tr(lang, 'quantity'),
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              onChanged: (v) {
                final parsed = int.tryParse(v);
                final n = (parsed ?? 0).clamp(0, 999);

                _qtyDebounce?.cancel();
                _qtyDebounce = Timer(const Duration(milliseconds: 250), () async {
                  final nextStatus = (n == 0)
                      ? ChecklistStatus.fail
                      : (row.status == ChecklistStatus.fail ? ChecklistStatus.verifying : row.status);

                  await _commit(_copyRow(qty: n, status: nextStatus));
                });
              },
              onEditingComplete: () {
                _qtyDebounce?.cancel();
                FocusScope.of(context).unfocus();
              },
            ),
          );
        }

        final content = narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Opacity(
                    opacity: isDisabled ? 0.4 : 1,
                    child: IgnorePointer(
                      ignoring: isDisabled,
                      child: leftMain(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: statusBox()),
                      const SizedBox(width: 8),
                      qtyBox(),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: I18n.tr(lang, 'delete'),
                        onPressed: () => context.read<AppState>().deleteChecklistRowFromRecord(
                              widget.type,
                              widget.recordId,
                              widget.group,
                              widget.index,
                            ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  noteBox(),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Opacity(
                      opacity: isDisabled ? 0.4 : 1,
                      child: IgnorePointer(
                        ignoring: isDisabled,
                        child: Row(
                          children: [
                            Expanded(child: leftMain()),
                            const SizedBox(width: 8),
                            statusBox(),
                            const SizedBox(width: 8),
                            Expanded(child: noteBox()),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: I18n.tr(lang, 'delete'),
                              onPressed: () => context.read<AppState>().deleteChecklistRowFromRecord(
                                    widget.type,
                                    widget.recordId,
                                    widget.group,
                                    widget.index,
                                  ),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  qtyBox(),
                ],
              );

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _statusColor(row),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: content,
          ),
        );
      },
    );
  }

}


class _AddChecklistItemDialog extends StatefulWidget {
  const _AddChecklistItemDialog();

  @override
  State<_AddChecklistItemDialog> createState() => _AddChecklistItemDialogState();
}

class _AddChecklistItemDialogState extends State<_AddChecklistItemDialog> {
  final ctrl = TextEditingController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().lang;

    return AlertDialog(
      title: Text(I18n.tr(lang, 'addItem')),
      content: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: I18n.tr(lang, 'itemName'),
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: Text(I18n.tr(context.watch<AppState>().lang, 'cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(context, ctrl.text.trim()),
          child: Text(I18n.tr(context.watch<AppState>().lang, 'add')),
        ),
      ],
    );
  }
}
