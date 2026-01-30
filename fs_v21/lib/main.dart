import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';

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
/// i18n (simple map)
/// -------------------------

class I18n {
  static const supported = ['ko', 'en'];

  static const Map<String, Map<String, String>> _t = {
    'ko': {
      'appTitle': 'Field Service MVP',
      'install': '설치',
      'operate': '운영',
      'troubleshoot': '문제해결',
      'todo': 'TODO (MVP)',
      'filters': '필터',
      'model': '모델',
      'gaUsage': 'GA 사용',
      'gaBoard': 'GA 보드 타입',
      'tags': '태그',
      'searchHint': '현상/원인/태그 검색',
      'any': 'ALL',
      'yes': 'YES',
      'no': 'NO',
      'reset': '초기화',
      'addIssue': '문제 추가',
      'symptom': '현상',
      'cause': '원인',
      'solutions': '해결방법',
      'steps': '단계',
      'attachPhoto': '사진 첨부',
      'removePhoto': '사진 제거',
      'generateReport': 'PDF 리포트 생성',
      'solutionCount': '솔루션',
      'selectSolution': '솔루션 선택',
      'save': '저장',
      'cancel': '취소',
      'required': '필수 입력',
      'multiSelect': '복수 선택 가능',
      'reportTitle': 'Troubleshooting Report',
      'date': '날짜',
      'appliedSolution': '적용 솔루션',
      'checklist': '체크리스트',
      'addSolution': '솔루션 추가',
      'removeSolution': '솔루션 삭제',
      'addStep': '스텝 추가',
      'removeStep': '스텝 삭제',
      'solutionTitle': '솔루션 제목',
      'stepText': '스텝 내용',
      'tagSearch': '태그 검색',
      'saveProgress': '진행상태 저장됨',
      'clearProgress': '진행상태 초기화',
    },
    'en': {
      'appTitle': 'Field Service MVP',
      'install': 'Installation',
      'operate': 'Operation',
      'troubleshoot': 'Troubleshooting',
      'todo': 'TODO (MVP)',
      'filters': 'Filters',
      'model': 'Model',
      'gaUsage': 'GA Usage',
      'gaBoard': 'GA Board Type',
      'tags': 'Tags',
      'searchHint': 'Search symptom/cause/tags',
      'any': 'ALL',
      'yes': 'YES',
      'no': 'NO',
      'reset': 'Reset',
      'addIssue': 'Add Issue',
      'symptom': 'Symptom',
      'cause': 'Cause',
      'solutions': 'Solutions',
      'steps': 'Steps',
      'attachPhoto': 'Attach Photo',
      'removePhoto': 'Remove Photo',
      'generateReport': 'Generate PDF Report',
      'solutionCount': 'Solutions',
      'selectSolution': 'Select a solution',
      'save': 'Save',
      'cancel': 'Cancel',
      'required': 'Required',
      'multiSelect': 'Multi-select',
      'reportTitle': 'Troubleshooting Report',
      'date': 'Date',
      'appliedSolution': 'Applied Solution',
      'checklist': 'Checklist',
      'addSolution': 'Add Solution',
      'removeSolution': 'Remove Solution',
      'addStep': 'Add Step',
      'removeStep': 'Remove Step',
      'solutionTitle': 'Solution title',
      'stepText': 'Step text',
      'tagSearch': 'Search tags',
      'saveProgress': 'Progress saved',
      'clearProgress': 'Clear progress',
    },
  };

  static String tr(String lang, String key) => _t[lang]?[key] ?? _t['en']![key] ?? key;
}

/// -------------------------
/// Data (your JSON embedded for MVP)
/// -------------------------
const String troubleshooterDataV6Json = r'''
[
  {
    "symptom": "명암이 진해서 어두운 부분이 잘 안보임 (위장 진입시)",
    "cause": "FFC (Flat Field Correction)이 적용이 안됨",
    "tags": ["영상", "밝기", "FFC"],
    "applicability": {
      "models": ["ME-400", "ME-470", "MGS-400", "MCS-400"],
      "deepeye_usage": "ALL",
      "deepeye_board_types": ["ALL"]
    },
    "solutions": [
      {
        "title": "Try 1: FFC 적용",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "키보드에서 Ctrl + Shift + F 를 누른다.", "done": false, "image_path": "" },
          { "text": "화면 밝기/균일도가 개선되는지 확인한다.", "done": false, "image_path": "" },
          { "text": "개선되면 작업을 종료한다.", "done": false, "image_path": "" }
        ]
      }
    ]
  },
  {
    "symptom": "GA 출력 내시경 영상이 안나옴 (화면: Please connect the endoscopy video.)",
    "cause": "모니터 출력 설정 또는 케이블/캡쳐보드 입력 문제 가능",
    "tags": ["GA", "출력", "캡쳐보드", "케이블"],
    "applicability": {
      "models": ["MD-GA-300"],
      "deepeye_usage": "YES",
      "deepeye_board_types": ["DVI-only", "HDMI-only", "DVI+HDMI", "Unknown", "ALL"]
    },
    "solutions": [
      {
        "title": "Try 1: 모니터 DVI OUT 설정 확인",
        "icon_path": "",
        "status": "failed",
        "steps": [
          { "text": "모니터 메뉴버튼 - General 세팅 - DVI Power Supply 를 On 으로 바꾼다", "done": false, "image_path": "" },
          { "text": "GA 화면에 영상이 들어오는지 확인한다.", "done": false, "image_path": "" }
        ]
      },
      {
        "title": "Try 2: 캡쳐보드 입력 케이블/포트 점검 및 교체",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "GA 캡쳐보드와 영상 출력에 연결된 케이블 규격(DVI-HDMI/HDMI-HDMI/DVI-DVI)을 확인", "done": false, "image_path": "" },
          { "text": "케이블 양쪽을 뽑았다가 다시 단단히 꽂음. 이래도 안되면 다른 케이블로 교체", "done": false, "image_path": "" },
          { "text": "영상이 들어오는지 확인", "done": false, "image_path": "" }
        ]
      }
    ]
  },
  {
    "symptom": "모니터에 영상이 안나옴 (GA 없이 단독 구성)",
    "cause": "입력 소스 설정/케이블/전원 문제 가능",
    "tags": ["모니터", "입력", "케이블"],
    "applicability": {
      "models": ["ALL"],
      "deepeye_usage": "NO",
      "deepeye_board_types": ["ALL"]
    },
    "solutions": [
      {
        "title": "Try 1: 입력 소스/케이블/전원 확인",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "모니터 전원이 켜져 있는지 확인한다.", "done": false, "image_path": "" },
          { "text": "모니터 입력 소스(HDMI/DVI/DP)를 올바르게 선택한다.", "done": false, "image_path": "" },
          { "text": "케이블 양쪽 연결 상태를 재체결한다.", "done": false, "image_path": "" },
          { "text": "다른 케이블/포트로 교차 테스트한다.", "done": false, "image_path": "" }
        ]
      }
    ]
  },
  {
    "symptom": "화면 과도한 색감 이상: 너무 파랗거나 초록등 정상적이지 않음",
    "cause": "WB 미진행",
    "tags": ["WB", "색감"],
    "applicability": {
      "models": ["ALL"],
      "deepeye_usage": "ALL",
      "deepeye_board_types": ["ALL"]
    },
    "solutions": [
      {
        "title": "Try 1: WB 진행",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "화밸캡 안에 내시경 끝을 1cm 간격만 남을정도로 넣는다. (화밸캡 바닥과 센서가 닿으면 안됨)", "done": false, "image_path": "" },
          { "text": "함체의 WB 버튼을 눌러 색감이 2번 변환되는것을 확인한다.", "done": false, "image_path": "" },
          { "text": "정상 색감을 확인한다.", "done": false, "image_path": "" }
        ]
      }
    ]
  },
  {
    "symptom": "특정 방향으로 움직이지 않으며, 커넥터 추출 후 상하 또는 좌우 핀이 한쪽방향으로 쉽게 움직인다",
    "cause": "스트링 파단",
    "tags": ["텐션", "스트링", "파단"],
    "applicability": {
      "models": ["MGS-400", "MCS-400"],
      "deepeye_usage": "ALL",
      "deepeye_board_types": ["ALL"]
    },
    "solutions": [
      {
        "title": "Try 1:회수",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "스태프에게 텐션에 이상이 생겼다고 안내한다. (절대 파단이나 끊어졌단 얘기는 하지 말것)", "done": false, "image_path": "" },
          { "text": "회수 후 생산관리본부에 전달한다.", "done": false, "image_path": "" }
        ]
      }
    ]
  },
  {
    "symptom": "석션이 약함",
    "cause": "석션실린더 튜브 간섭, 석션 단계 세팅값 설정 이상",
    "tags": ["석션", "제어"],
    "applicability": {
      "models": ["ME-400", "ME-470"],
      "deepeye_usage": "ALL",
      "deepeye_board_types": ["ALL"]
    },
    "solutions": [
      {
        "title": "Try 1: (석션H일때 소음이 거의 없어지지 않을경우) 석션 튜브 약간 후퇴",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "석션 실린더의 하단포트에 연결된 석션 튜브를 살짝 뺌 (밸브가 눌렸을때 튜브가 안씹힐 정도).", "done": false, "image_path": "" },
          { "text": "석션 세기 재확인.", "done": false, "image_path": "" }
        ]
      },
      {
        "title": "Try 2:석션 길이 SW 재설정",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "[win] + [alt] + [r] 을 눌러 커맨드 프롬프트를 활성화 함.", "done": false, "image_path": "" },
          { "text": "gen + [tab] + ter + [tab] 을 눌러 genome-terminal을 킨다.", "done": false, "image_path": "" },
          { "text": "cd .local/share/me400/configs/에서 eciconfig.ini 파일 변경한다. 만약 eciconfig.ini파일이 없으면 만든다", "done": false, "image_path": "" },
          { "text": "해당 파일에 아래 내용을 추가 한다 (1줄당 1개씩):", "done": false, "image_path": "" },
          { "text": "suction_pos1=450", "done": false, "image_path": "" },
          { "text": "suction_pos2=680", "done": false, "image_path": "" },
          { "text": "저장 후 재부팅 한다.", "done": false, "image_path": "" }
        ]
      }
    ]
  },
  {
    "symptom": "endopilot 에임 비정상",
    "cause": "제어 파라미터 오류",
    "tags": ["제어"],
    "applicability": {
      "models": ["ME-470"],
      "deepeye_usage": "ALL",
      "deepeye_board_types": ["ALL"]
    },
    "solutions": [
      {
        "title": "Try 1:제어 파라미터 변경",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "[win] + [alt] + [r] 을 눌러 커맨드 프롬프트를 활성화", "done": false, "image_path": "" },
          { "text": "gen + [tab] + ter + [tab] 키를 눌러 genome-terminal을 켬", "done": false, "image_path": "" },
          { "text": "TODO: 제어팀 수정 방법 확인", "done": false, "image_path": "" }
        ]
      }
    ]
  },
  {
    "symptom": "게이트웨이 전원 안들어옴",
    "cause": "PC 이상",
    "tags": ["게이트웨이"],
    "applicability": {
      "models": ["인피니트 게이트웨이"],
      "deepeye_usage": "ALL",
      "deepeye_board_types": ["ALL"]
    },
    "solutions": [
      {
        "title": "Try 1:다른 게이트웨이 사용",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "영상 출력을 다른 게이트웨이에 연결하여 사용", "done": false, "image_path": "" },
          { "text": "정상 동작 확인", "done": false, "image_path": "" }
        ]
      }
    ]
  },
  {
    "symptom": "endotrack 에임 비정상",
    "cause": "제어 파라미터 오류",
    "tags": ["제어"],
    "applicability": {
      "models": ["ME-470"],
      "deepeye_usage": "ALL",
      "deepeye_board_types": ["ALL"]
    },
    "solutions": [
      {
        "title": "Try 1:제어 파라미터 튜닝",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "[win] + [alt] + [r] 을 눌러 커맨드 프롬프트를 활성화", "done": false, "image_path": "" },
          { "text": "\"gen\" + [tab] + \"ter\" + [tab] 키를 눌러 genome-terminal을 켬", "done": false, "image_path": "" },
          { "text": "TODO: 제어팀 수정 방법 확인", "done": false, "image_path": "" }
        ]
      }
    ]
  },
  {
    "symptom": "Leak test 실패",
    "cause": "에어러버 미장착, 방수캡 크랙, 스코프 볼트결합부 오링 손상 등",
    "tags": ["방수"],
    "applicability": {
      "models": ["MCS-400", "MGS-400"],
      "deepeye_usage": "ALL",
      "deepeye_board_types": ["ALL"]
    },
    "solutions": [
      {
        "title": "Try 1: 에어러버 장착",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "방수캡을 열어 에어러버가 있는지 확인 및 끝까지 들어가있는지 확인", "done": false, "image_path": "" },
          { "text": "에어러버가 이미 있다면 다음 Try, 없다면 장착후 다시 테스트", "done": false, "image_path": "" },
          { "text": "압력이 2분동안 150mmHg 에서 140mmHg 미만으로 떨어지지 않는지 확인", "done": false, "image_path": "" }
        ]
      },
      {
        "title": "Try 2: 방수캡 교체",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "방수캡 교체", "done": false, "image_path": "" },
          { "text": "압력이 2분동안 150mmHg 에서 140mmHg 미만으로 떨어지지 않는지 확인", "done": false, "image_path": "" }
        ]
      },
      {
        "title": "Try 3: 위 2개의 방법에도 실패시 제품 파손에 의한 방수 FAIL",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "스태프에게 스코프 사용 불가 안내. 가능하면 원인 분석을 위해 세척시, 또는 사용시 어딘가에 부딛히거나 떨어뜨린적이 있는지 확인", "done": false, "image_path": "" },
          { "text": "회수 및 메디인테크 생산팀에 수리 요청", "done": false, "image_path": "" }
        ]
      }
    ]
  },
  {
    "symptom": "버튼 탈락",
    "cause": "버튼의 측면 또는 대각 밀림, 고무 노후화",
    "tags": ["버튼"],
    "applicability": {
      "models": ["MCS-400", "MGS-400"],
      "deepeye_usage": "ALL",
      "deepeye_board_types": ["ALL"]
    },
    "solutions": [
      {
        "title": "Try 1: 즉시 회수",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "스태프에게 스코프 사용 불가 안내 한다.", "done": false, "image_path": "" },
          { "text": "회수 및 메디인테크 생산팀에 수리 요청한다.", "done": false, "image_path": "" }
        ]
      }
    ]
  },
  {
    "symptom": "부팅 후 자동 실행 안됨",
    "cause": "SW 버그",
    "tags": ["부팅", "함체"],
    "applicability": {
      "models": ["ME-400", "ME-470"],
      "deepeye_usage": "ALL",
      "deepeye_board_types": ["ALL"]
    },
    "solutions": [
      {
        "title": "Try 1: 재부팅",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "재부팅", "done": false, "image_path": "" },
          { "text": "정상 동작 확인", "done": false, "image_path": "" }
        ]
      },
      {
        "title": "Try 2: 소프트웨어 팀 연락",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "소프트웨어팀에 연락하여 디버깅 진행", "done": false, "image_path": "" },
          { "text": "정상동작 확인", "done": false, "image_path": "" }
        ]
      }
    ]
  },
  {
    "symptom": "부팅 후, 칼리브레이션 중 에러 팝업",
    "cause": "SW 버그",
    "tags": [],
    "applicability": {
      "models": ["ALL"],
      "deepeye_usage": "ALL",
      "deepeye_board_types": ["ALL"]
    },
    "solutions": [
      {
        "title": "Try 1: 계속 엔터를 누른다",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "없어질때까지 엔터를 누름", "done": false, "image_path": "" },
          { "text": "에러 팝업 없이 정상 동작 하는지 확인", "done": false, "image_path": "" }
        ]
      }
    ]
  },
  {
    "symptom": "GA 약 30초 지나도 자동실행 안함",
    "cause": "SW 버그",
    "tags": ["GA"],
    "applicability": {
      "models": ["MD-GA-300"],
      "deepeye_usage": "YES",
      "deepeye_board_types": ["ALL"]
    },
    "solutions": [
      {
        "title": "Try 1: 바탕화면의 GA 아이콘 더블 클릭",
        "icon_path": "",
        "status": "unknown",
        "steps": [
          { "text": "바탕화면에 GA 아이콘이 있다면 더블 클릭, 없다면 C:\\md-ga-300\\md-ga-300.exe 더블 클릭", "done": false, "image_path": "" },
          { "text": "정상 동작 확인", "done": false, "image_path": "" }
        ]
      }
    ]
  }
]
''';

const String settingsV6Json = r'''
{
  "models": ["ME-400","ME-470","MGS-400","MCS-400","MD-GA-300","MD-GW-300","INFINITT 게이트웨이","MDGATE 게이트웨이"],
  "deepeye_board_types": ["DVI","HDMI"],
  "language": "ko",
  "tags": ["FFC","GA","WB","MD-GW-300","INFINITT 게이트웨이","MDGATE 게이트웨이","모니터",
  "밝기","방수","버튼","부팅","색감","석션","스트링","영상","입력","제어","출력","캡쳐보드","케이블","텐션","파단","함체"]
}
''';

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
        models: (j['models'] as List).map((e) => e.toString()).toList(),
        gaUsage: j['deepeye_usage'].toString(),
        gaBoardTypes: (j['deepeye_board_types'] as List).map((e) => e.toString()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'models': models,
        'deepeye_usage': gaUsage,
        'deepeye_board_types': gaBoardTypes,
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


/// -------------------------
/// Persistence keys
/// -------------------------
class StoreKeys {
  static const troubles = 'troubles';   // list json
  static const installGuides = 'install_guides';     // ✅ 추가
  static const operationGuides = 'operation_guides'; // ✅ 추가
  static const settings = 'settings';   // settings json
  static const language = 'language';

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

  late List<String> allModels;
  late List<String> allGaBoardTypes;
  late List<String> allTags;

  List<TroubleItem> troubles = [];
  List<GuideSection> installSections = [];
  List<GuideSection> operationSections = [];

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
    // 1) Hive에서 먼저 가져오기
    String raw = _box.get(hiveKey) ?? '';

    // 2) 없으면 assets seed 로드 후 Hive에 저장
    if (raw.trim().isEmpty) {
      raw = await rootBundle.loadString(assetPath);
      await _box.put(hiveKey, raw);
    }

    // 3) 파싱
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    return decoded
        .map((e) => GuideSection.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }


  Future<void> persistInstallGuides() async {
    await _box.put(StoreKeys.installGuides, jsonEncode(installSections.map((e) => e.toJson()).toList()));
  }

  Future<void> persistOperationGuides() async {
    await _box.put(StoreKeys.operationGuides, jsonEncode(operationSections.map((e) => e.toJson()).toList()));
  }

  // Future<void> persistInstallGuides() async {
  //   await _box.put(StoreKeys.installGuides,
  //       jsonEncode(installSections.map((e) => e.toJson()).toList()));
  // }

  // Future<void> persistOperationGuides() async {
  //   await _box.put(StoreKeys.operationGuides,
  //       jsonEncode(operationSections.map((e) => e.toJson()).toList()));
  // }

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

  

  Future<void> init() async {
    final settings = jsonDecode(settingsV6Json) as Map<String, dynamic>;
    allModels = (settings['models'] as List).map((e) => e.toString()).toList();
    allGaBoardTypes = (settings['deepeye_board_types'] as List).map((e) => e.toString()).toList();
    allTags = (settings['tags'] as List).map((e) => e.toString()).toList();

    // language (Hive로 통일)
    lang = _box.get(StoreKeys.language) ?? settings['language']?.toString() ?? 'ko';

    // ✅ 1) Hive에 troubles가 "없으면" seed를 만들고 저장
    String raw = _box.get(StoreKeys.troubles) ?? '';
    if (raw.isEmpty) {
      final seeded = (jsonDecode(troubleshooterDataV6Json) as List)
          .cast<Map<String, dynamic>>();

      // ✅ 2) seed에 id가 없으니 여기서 1회 생성해서 박아넣고 저장(중요)
      for (int i = 0; i < seeded.length; i++) {
        seeded[i]['id'] ??= 'T${DateTime.now().microsecondsSinceEpoch}_$i';
      }

      raw = jsonEncode(seeded);
      await _box.put(StoreKeys.troubles, raw);
    }

    // ✅ 3) 이후엔 무조건 Hive에 있는 raw만 읽기
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    troubles = list.map((m) => TroubleItem.fromJson(m)).toList();

    // ✅ install guides
    installSections = await _loadGuideSections(
      hiveKey: StoreKeys.installGuides,
      assetPath: 'assets/data/install_guides_v1.json',
    );

    operationSections = await _loadGuideSections(
      hiveKey: StoreKeys.operationGuides,
      assetPath: 'assets/data/operation_guides_v1.json',
    );

    notifyListeners();
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

  Future<void> _persistTroubles() async {
    await _box.put(StoreKeys.troubles, jsonEncode(troubles.map((e) => e.toJson()).toList()));
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
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.tr(s.lang, 'appTitle')),
        actions: [
          PopupMenuButton<String>(
            initialValue: s.lang,
            onSelected: (v) => context.read<AppState>().setLang(v),
            itemBuilder: (_) => I18n.supported
                .map((e) => PopupMenuItem(value: e, child: Text(e.toUpperCase())))
                .toList(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MainBtn(
                  label: I18n.tr(s.lang, 'install'),
                  icon: Icons.construction,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InstallTypeSelectScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                _MainBtn(
                  label: I18n.tr(s.lang, 'operate'),
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
    );
  }

  void _todo(BuildContext context) {
    final s = context.read<AppState>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(I18n.tr(s.lang, 'todo'))),
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

/// -------------------------
/// Troubleshooting list + filters + search
/// -------------------------
class TroubleListScreen extends StatelessWidget {
  const TroubleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final items = s.filteredTroubles;

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.tr(s.lang, 'troubleshoot')),
        actions: [
          IconButton(
            tooltip: I18n.tr(s.lang, 'addIssue'),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AddIssueDialog(),
            ),
            icon: const Icon(Icons.add),
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
              separatorBuilder: (_, __) => const Divider(height: 1),
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
                items: models.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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
              label: Text(tag),
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

  Future<void> _generatePdfReportWithMeta(
    BuildContext context,
    TroubleItem t,
    SolutionItem sol,
    ReportMeta meta,
  ) async {
    final s = context.read<AppState>();
    final now = DateTime.now();
    final createdAtStr = DateFormat('yyyy-MM-dd HH:mm').format(now);
    final actionDateStr = DateFormat('yyyy-MM-dd').format(meta.actionDate);
    final fontData = await rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    final boldData = await rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf');
    final ttfBold = pw.Font.ttf(boldData);

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: ttf,
        bold: ttfBold, // 볼드 파일 있으면 bold: ttfBold
      ),
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
            pw.SizedBox(width: 110, child: pw.Text(k, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Expanded(child: pw.Text(v)),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Text(I18n.tr(s.lang, 'reportTitle'),
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),

          // ---- Template section
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 0.8),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('기본정보', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                kv('병원', meta.hospital),
                kv('시리얼', meta.serial),
                kv('담당자', meta.contact),
                kv('조치일자', actionDateStr),
                kv('리포트 생성', createdAtStr),
                pw.SizedBox(height: 8),
                pw.Text('설치구성', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                kv('모델', meta.model),
                kv('GA', meta.gaUsage),
                kv('보드', meta.gaBoard),
                pw.SizedBox(height: 8),
                pw.Text('이슈', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                kv('현상', meta.symptom.isEmpty ? t.symptom : meta.symptom),
                kv('원인', meta.cause.isEmpty ? t.cause : meta.cause),
                kv('조치방식', meta.action),
                pw.SizedBox(height: 4),
                kv('적용 솔루션', sol.title),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // ---- Checklist section
          pw.Text(I18n.tr(s.lang, 'checklist'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),

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
                  pw.Container(width: 420, child: pw.Image(img, fit: pw.BoxFit.contain)),
                ],
                pw.SizedBox(height: 10),
              ],
            );
          }),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'report_${meta.hospital.isEmpty ? "site" : meta.hospital}_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf',
    );
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
                  lang: st.lang,
                ),
              );

              if (edited == null) return;

              // 3) 저장
              await st.saveReportMeta(t.id, edited);

              // 4) PDF 생성 (meta 포함)
              await _generatePdfReportWithMeta(context, t, sol, edited);
            },
            icon: const Icon(Icons.picture_as_pdf),
          ),
          IconButton(
            tooltip: 'Save',
            onPressed: _saveProgress,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: 'Clear',
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
                    _applySavedProgressIfAny(); // ✅ 선택한 솔루션의 저장 progress 로드
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

  Future<void> _generatePdfReport(BuildContext context, TroubleItem t, SolutionItem sol) async {
    final s = context.read<AppState>();
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(now);
    final fontData = await rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    final boldData = await rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf');
    final ttfBold = pw.Font.ttf(boldData);
   
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: ttf,
        bold: ttfBold, // 볼드 파일 있으면 bold: ttfBold
      ),
    );


    pw.ImageProvider? imgFromBytes(Uint8List? b) {
      if (b == null) return null;
      return pw.MemoryImage(b);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Text(I18n.tr(s.lang, 'reportTitle'),
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('${I18n.tr(s.lang, 'date')}: $dateStr'),
          pw.SizedBox(height: 10),
          pw.Text('${I18n.tr(s.lang, 'symptom')}: ${t.symptom}'),
          pw.Text('${I18n.tr(s.lang, 'cause')}: ${t.cause}'),
          pw.SizedBox(height: 10),
          pw.Text('${I18n.tr(s.lang, 'appliedSolution')}: ${sol.title}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Text(I18n.tr(s.lang, 'checklist'),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          ...sol.steps.asMap().entries.map((e) {
            final idx = e.key + 1;
            final st = e.value;
            final mark = st.done ? '[x]' : '[ ]';
            final img = imgFromBytes(st.imageBytes);

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('$mark  $idx. ${st.text}'),
                if (img != null) ...[
                  pw.SizedBox(height: 6),
                  pw.Container(width: 400, child: pw.Image(img, fit: pw.BoxFit.contain)),
                ],
                pw.SizedBox(height: 10),
              ],
            );
          }),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'troubleshooting_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf',
    );
  }
}

class GuideSection {
  final String id;
  final String title;
  final List<GuideStep> steps;

  GuideSection({required this.id, required this.title, required this.steps});

  factory GuideSection.fromJson(Map<String, dynamic> j) => GuideSection(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        steps: (j['steps'] as List? ?? const [])
            .map((e) => GuideStep.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'steps': steps.map((e) => e.toJson()).toList(),
      };
}

class GuideImage {
  final String asset;
  final String caption;

  const GuideImage(this.asset, {this.caption = ''});

  factory GuideImage.fromJson(Map<String, dynamic> j) => GuideImage(
        (j['asset'] ?? '').toString(),
        caption: (j['caption'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'asset': asset, 'caption': caption};
}

class GuideTable {
  final List<String> headers;
  final List<List<String>> rows;

  GuideTable({required this.headers, required this.rows});

  factory GuideTable.fromJson(Map<String, dynamic> j) => GuideTable(
        headers: (j['headers'] as List? ?? const []).map((e) => e.toString()).toList(),
        rows: (j['rows'] as List? ?? const [])
            .map((r) => (r as List).map((c) => c.toString()).toList())
            .toList(),
      );

  Map<String, dynamic> toJson() => {'headers': headers, 'rows': rows};
}

class GuideStep {
  final String title;
  final List<String> paragraphs;
  final List<String> bullets;
  final List<GuideTable> tables;
  final List<GuideImage> images; // ✅ 여러 장

  GuideStep({
    required this.title,
    this.paragraphs = const [],
    this.bullets = const [],
    this.tables = const [],
    this.images = const [],       // ✅
  });

  factory GuideStep.fromJson(Map<String, dynamic> j) => GuideStep(
        title: (j['title'] ?? '').toString(),
        paragraphs: (j['paragraphs'] as List? ?? const []).map((e) => e.toString()).toList(),
        bullets: (j['bullets'] as List? ?? const []).map((e) => e.toString()).toList(),
        tables: (j['tables'] as List? ?? const [])
            .map((e) => GuideTable.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        images: (j['images'] as List? ?? const [])
            .map((e) => GuideImage.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'paragraphs': paragraphs,
        'bullets': bullets,
        'tables': tables.map((e) => e.toJson()).toList(),
        'images': images.map((e) => e.toJson()).toList(),
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
  final String lang;

  const ReportTemplateDialog({
    super.key,
    required this.trouble,
    required this.meta,
    required this.allModels,
    required this.allBoards,
    required this.lang,
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
    final lang = widget.lang;
    final models = ['ALL', ...widget.allModels];
    final boards = ['ALL', ...widget.allBoards];
    const gaUsages = ['ALL', 'YES', 'NO'];

    return AlertDialog(
      title: Text('리포트 템플릿'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _textField(hospitalCtrl, '병원'),
              const SizedBox(height: 8),
              _textField(serialCtrl, '시리얼'),
              const SizedBox(height: 8),
              _textField(contactCtrl, '담당자'),
              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('설치구성', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: m.model,
                      decoration: const InputDecoration(labelText: '모델', border: OutlineInputBorder(), isDense: true),
                      items: models.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => m.model = v ?? 'ALL'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: m.gaUsage,
                      decoration: const InputDecoration(labelText: 'GA', border: OutlineInputBorder(), isDense: true),
                      items: gaUsages.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => m.gaUsage = v ?? 'ALL'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: m.gaBoard,
                decoration: const InputDecoration(labelText: '보드', border: OutlineInputBorder(), isDense: true),
                items: boards.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => m.gaBoard = v ?? 'ALL'),
              ),

              const SizedBox(height: 14),
              _textField(symptomCtrl, '현상'),
              const SizedBox(height: 8),
              _textField(causeCtrl, '원인'),
              const SizedBox(height: 8),
              _textField(actionCtrl, '조치방식', maxLines: 3),

              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '조치일자',
                        border: OutlineInputBorder(),
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
                            label: const Text('선택'),
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
                      ? '※ 입력값은 해당 현상(Trouble) 단위로 저장됩니다.'
                      : 'Saved per Trouble item.',
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

  Widget _textField(TextEditingController c, String label, {int maxLines = 1}) {
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
    _DraftSolution(title: 'Try 1', steps: ['Step 1', 'Step 2']),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    final models = ['ALL', ...s.allModels];
    final boards = ['ALL', ...s.allGaBoardTypes];
    final usages = const ['ALL', 'YES', 'NO'];

    final filteredTags = s.allTags
        .where((t) => tagQuery.trim().isEmpty ? true : t.toLowerCase().contains(tagQuery.toLowerCase()))
        .toList();

    return AlertDialog(
      title: Text(I18n.tr(s.lang, 'addIssue')),
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
                      items: models.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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
                      label: Text(tag),
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

            await context.read<AppState>().addTrouble(newItem);
            if (context.mounted) Navigator.pop(context);
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

  const GuideSectionScreen({super.key, required this.section, required this.appBarTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: section.steps.map((step) {
          return ExpansionTile(
            title: Text(step.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              ...step.paragraphs.map((p) => _paragraph(p)),
              ...step.tables.map((t) => _table(t)),
              ...step.bullets.map((b) => _bullet(b)),
              ...step.images.map((gi) => _image(gi)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _paragraph(String raw) {
    final isIndented = raw.startsWith('\t');
    final text = raw.replaceFirst('\t', '');
    return Padding(
      padding: EdgeInsets.only(left: isIndented ? 16 : 0, bottom: 6),
      child: Text(text, textAlign: TextAlign.left),
    );
  }

  Widget _bullet(String b) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 18, child: Text('•')),
        Expanded(child: Text(b)),
      ],
    ),
  );

  Widget _image(GuideImage gi) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(gi.asset, fit: BoxFit.contain),
        ),
        if (gi.caption.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(gi.caption, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ],
    ),
  );

  Widget _table(GuideTable t) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: t.headers.map((h) => DataColumn(label: Text(h))).toList(),
      rows: t.rows.map((r) => DataRow(cells: r.map((c) => DataCell(Text(c))).toList())).toList(),
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
        title: const Text('설치 유형 선택'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
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
                MaterialPageRoute(builder: (_) => GuideSectionScreen(section: sec, appBarTitle: '설치 가이드')),
              ),
              icon: const Icon(Icons.monitor),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(sec.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
        title: Text(mode == GuideMode.install ? '설치 가이드 편집' : '운영 가이드 편집'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Section',
            onPressed: () async {
              final created = await showDialog<GuideSection>(
                context: context,
                builder: (_) => GuideSectionDialog(mode: mode),
              );
              if (created == null) return;

              final st = context.read<AppState>();
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
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final sec = sections[i];
          return ListTile(
            title: Text(sec.title),
            subtitle: Text(sec.id, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final updated = await Navigator.push<GuideSection>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GuideSectionEditScreen(mode: mode, section: sec),
                      ),
                    );
                    if (updated == null) return;

                    final st = context.read<AppState>();
                    if (mode == GuideMode.install) {
                      await st.updateInstallSection(updated);
                    } else {
                      await st.updateOperationSection(updated);
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('삭제할까요?'),
                        content: Text('섹션 "${sec.title}"을(를) 삭제합니다.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
                        ],
                      ),
                    );
                    if (ok != true) return;

                    final st = context.read<AppState>();
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
              final updated = await Navigator.push<GuideSection>(
                context,
                MaterialPageRoute(
                  builder: (_) => GuideSectionEditScreen(mode: mode, section: sec),
                ),
              );
              if (updated == null) return;

              final st = context.read<AppState>();
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
    final prefix = widget.mode == GuideMode.install ? 'install' : 'operate';

    return AlertDialog(
      title: const Text('섹션 추가'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: '섹션 제목(버튼에 표시)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'id는 자동 생성됩니다. (예: $prefix:1700000000)',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: () {
            final title = titleCtrl.text.trim();
            if (title.isEmpty) return;

            final id = '$prefix:${DateTime.now().microsecondsSinceEpoch}';
            final sec = GuideSection(id: id, title: title, steps: [
              GuideStep(
                title: 'Step 1',
                paragraphs: const ['내용을 입력하세요'],
              ),
            ]);

            Navigator.pop(context, sec);
          },
          child: const Text('생성'),
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

  @override
  void initState() {
    super.initState();
    // deep copy(간단히 json roundtrip)
    draft = GuideSection.fromJson(widget.section.toJson());
    titleCtrl = TextEditingController(text: draft.title);
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    super.dispose();
  }

  void _addStep() {
    setState(() {
      final n = draft.steps.length + 1;
      draft = GuideSection(
        id: draft.id,
        title: draft.title,
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
      draft = GuideSection(id: draft.id, title: draft.title, steps: next.isEmpty ? [GuideStep(title: 'Step 1')] : next);
    });
  }

  void _updateStep(int index, GuideStep step) {
    setState(() {
      final next = [...draft.steps];
      next[index] = step;
      draft = GuideSection(id: draft.id, title: draft.title, steps: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('섹션 편집'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save',
            onPressed: () {
              final t = titleCtrl.text.trim();
              if (t.isEmpty) return;

              final saved = GuideSection(id: draft.id, title: t, steps: draft.steps);
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
            decoration: const InputDecoration(
              labelText: '섹션 제목',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              const Expanded(
                child: Text('Steps', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              FilledButton.tonalIcon(
                onPressed: _addStep,
                icon: const Icon(Icons.add),
                label: const Text('Step 추가'),
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

  GuideStep _emit({String? title, List<String>? paragraphs, List<String>? bullets, List<GuideImage>? images}) {
    return GuideStep(
      title: title ?? widget.step.title,
      paragraphs: paragraphs ?? widget.step.paragraphs,
      bullets: bullets ?? widget.step.bullets,
      images: images ?? widget.step.images,
      tables: widget.step.tables, // TODO: table editor
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.step;

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
                      labelText: 'Step 제목 #${widget.index + 1}',
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
                    tooltip: 'Step 삭제',
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            _ListEditor(
              label: 'Paragraphs',
              items: st.paragraphs,
              hint: '예) 1. ME-400/470를 카트 제일 윗칸에 배치',
              onChanged: (list) => widget.onChanged(_emit(paragraphs: list)),
            ),

            const SizedBox(height: 12),

            _ListEditor(
              label: 'Bullets',
              items: st.bullets,
              hint: '예) 안정성을 위해 모든 영상 케이블은 DVI 사용 권장',
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
              label: const Text('추가'),
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
                  tooltip: '삭제',
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
  final List<GuideImage> images;
  final ValueChanged<List<GuideImage>> onChanged;

  const _ImageListEditor({required this.images, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Images', style: TextStyle(fontWeight: FontWeight.w700))),
            FilledButton.tonalIcon(
              onPressed: () => onChanged([...images, const GuideImage('assets/images/xxx.png', caption: '')]),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('추가'),
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
                    decoration: const InputDecoration(
                      labelText: 'asset 경로',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final next = [...images];
                      next[i] = GuideImage(v.trim(), caption: images[i].caption);
                      onChanged(next);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: images[i].caption,
                    decoration: const InputDecoration(
                      labelText: 'caption',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final next = [...images];
                      next[i] = GuideImage(images[i].asset, caption: v);
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
                          label: const Text('삭제'),
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
    if (!path.startsWith('assets/')) {
      return const Text('미리보기: assets/ 경로를 입력하세요', style: TextStyle(fontSize: 12, color: Colors.white70));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        path,
        height: 160,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Padding(
          padding: EdgeInsets.all(8),
          child: Text('이미지 로드 실패 (경로/pubspec 확인)', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
        title: const Text('운영 유형 선택'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
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
                MaterialPageRoute(builder: (_) => GuideSectionScreen(section: sec, appBarTitle: sec.title)),
              ),
              icon: const Icon(Icons.menu_book),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(sec.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

