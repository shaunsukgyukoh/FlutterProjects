# pip install ttkbootstrap
import json
import os
import csv
from datetime import datetime

import tkinter as tk
from tkinter import ttk, messagebox, filedialog

import ttkbootstrap as tb
from ttkbootstrap.constants import *

DATA_FILE = "troubles_v6.json"
LOG_FILE = "work_logs.json"
SETTINGS_FILE = "settings_v6.json"

# -----------------------------
# i18n (UI translations)
# -----------------------------
I18N = {
    "ko": {
        "app_title": "내시경 트러블슈터 v6 (한/영 UI 전환 + Edit UI + 로그/CSV)",
        "model": "모델:",
        "ga_use": "GA 사용:",
        "ga_board": "GA 보드:",
        "search": "검색:",
        "manage_models_boards": "모델/보드 관리",
        "add_issue": "새 문제 추가",
        "edit_issue": "문제 수정(Edit)",
        "delete_issue": "선택 문제 삭제",
        "log_box_title": "작업 로그 (성공/실패 시 자동 저장) + CSV 내보내기",
        "dt": "날짜/시간:",
        "location": "장소:",
        "sn": "장비 SN:",
        "note": "메모:",
        "export_csv": "CSV 내보내기",
        "refresh_time": "시간 갱신",
        "issue_list": "문제 현상 목록",
        "selected_issue": "선택한 문제",
        "scope": "적용 범위",
        "cause": "가능한 원인(Cause)",
        "try_select": "해결책(Try) 해결방법:",
        "add_try": "해결책 추가",
        "edit_try": "Try 수정(Edit)",
        "delete_try": "선택 해결책 삭제",
        "try_status": "Try 상태:",
        "try_success": "이 Try 성공(종료)",
        "try_fail_next": "이 Try 실패 → 다음 Try",
        "try_reset": "체크 초기화(현재 Try)",
        "steps_title": "Step-by-step 체크리스트 (편집/순서이동 가능)",
        "preview_title": "사진/아이콘 미리보기 (PNG 권장)",
        "try_icon": "Try 아이콘",
        "step_photo": "Step 사진",
        "logs_count": "저장된 로그: {n}건  |  로그 파일: {file}",
        "lang": "언어:",
        "any": "ANY",
        "no": "NO",
        "yes": "YES",
        "all": "ALL",
        "info": "안내",
        "confirm": "확인",
        "required": "필수",
        "cancel": "취소",
        "save": "저장",
        "close": "닫기",
        "done": "완료",
        "error": "오류",
        "no_logs": "내보낼 로그가 없습니다.",
        "export_done": "CSV 내보내기 완료:\n{path}",
        "export_fail": "CSV 저장 실패:\n{err}",
        "select_issue_first": "수정할 문제를 먼저 선택하세요.",
        "select_try_first": "수정할 Try를 먼저 선택하세요.",
        "select_issue_try_first": "먼저 문제와 Try를 선택하세요.",
        "step_no_image": "이 단계에는 첨부된 사진이 없어요.",
        "cannot_empty_symptom": "문제 현상은 비울 수 없어요.",
        "cannot_empty_try": "Try 제목은 비울 수 없어요.",
        "cannot_empty_step": "Step 텍스트는 비울 수 없어요.",
        "delete_step_q": "{k}번 단계를 삭제할까요?",
        "deleted_issue_q": "정말 삭제할까요?\n\n- {symptom}",
        "deleted_try_q": "선택한 해결책을 삭제할까요?\n\n- {title}",
        "success_logged": "해결(success)로 기록했고 작업 로그도 저장했어요.",
        "next_try": "다음 Try",
        "moved_next": "실패로 기록 + 로그 저장 후 다음 Try로 이동했어요.",
        "last_try": "마지막 Try",
        "last_try_msg": "마지막 Try까지 실패로 기록 + 로그 저장했어요.\n추가 해결책 등록 또는 상위 점검이 필요할 수 있어요.",
        "manage_title": "모델/GA 보드 타입 관리 (추가/삭제 즉시 반영)",
        "models_list": "모델 목록 (정렬)",
        "boards_list": "GA 보드 타입 목록 (정렬)",
        "add": "추가",
        "remove_selected": "선택 삭제",
        "exists": "이미 존재합니다.",
        "delete_q": "삭제할까요?\n\n{value}",
        "edit_step": "편집",
        "up": "↑",
        "down": "↓",
        "photo": "사진",
        "view": "보기",
        "delete": "삭제",
        "add_step": "Step 추가",
        "pick_icon": "아이콘 선택",
        "remove_icon": "아이콘 제거",
        "preview_fail": "(미리보기 실패: PNG/GIF 권장)",
        "no_icon": "(아이콘 없음)",
        "no_photo": "(사진 없음)",
    },
    "en": {
        "app_title": "Endoscope Troubleshooter v6 (KO/EN UI + Edit UI + Logs/CSV)",
        "model": "Model:",
        "ga_use": "GA use:",
        "ga_board": "GA board:",
        "search": "Search:",
        "manage_models_boards": "Manage models/boards",
        "add_issue": "Add issue",
        "edit_issue": "Edit issue",
        "delete_issue": "Delete issue",
        "log_box_title": "Work logs (auto-save on success/fail) + Export CSV",
        "dt": "Date/Time:",
        "location": "Location:",
        "sn": "Device S/N:",
        "note": "Note:",
        "export_csv": "Export CSV",
        "refresh_time": "Refresh time",
        "issue_list": "Issue list",
        "selected_issue": "Selected issue",
        "scope": "Applicability",
        "cause": "Possible cause",
        "try_select": "Select solution (Try):",
        "add_try": "Add solution",
        "edit_try": "Edit try",
        "delete_try": "Delete try",
        "try_status": "Try status:",
        "try_success": "Try success (finish)",
        "try_fail_next": "Try failed → Next try",
        "try_reset": "Reset checks (this try)",
        "steps_title": "Step-by-step checklist (editable / reorderable)",
        "preview_title": "Preview (PNG recommended)",
        "try_icon": "Try icon",
        "step_photo": "Step photo",
        "logs_count": "Saved logs: {n}  |  Log file: {file}",
        "lang": "Language:",
        "any": "ANY",
        "no": "NO",
        "yes": "YES",
        "all": "ALL",
        "info": "Info",
        "confirm": "Confirm",
        "required": "Required",
        "cancel": "Cancel",
        "save": "Save",
        "close": "Close",
        "done": "Done",
        "error": "Error",
        "no_logs": "No logs to export.",
        "export_done": "CSV exported:\n{path}",
        "export_fail": "CSV export failed:\n{err}",
        "select_issue_first": "Select an issue first.",
        "select_try_first": "Select a try first.",
        "select_issue_try_first": "Select an issue and a try first.",
        "step_no_image": "No image attached for this step.",
        "cannot_empty_symptom": "Symptom cannot be empty.",
        "cannot_empty_try": "Try title cannot be empty.",
        "cannot_empty_step": "Step text cannot be empty.",
        "delete_step_q": "Delete step #{k}?",
        "deleted_issue_q": "Delete this issue?\n\n- {symptom}",
        "deleted_try_q": "Delete this try?\n\n- {title}",
        "success_logged": "Marked success and saved a work log.",
        "next_try": "Next try",
        "moved_next": "Saved failure log and moved to the next try.",
        "last_try": "Last try",
        "last_try_msg": "Marked failed and saved a log for the last try.\nYou may need to add more tries or escalate.",
        "manage_title": "Manage models/GA boards (instant apply)",
        "models_list": "Models (sorted)",
        "boards_list": "GA board types (sorted)",
        "add": "Add",
        "remove_selected": "Remove selected",
        "exists": "Already exists.",
        "delete_q": "Delete?\n\n{value}",
        "edit_step": "Edit",
        "up": "↑",
        "down": "↓",
        "photo": "Photo",
        "view": "View",
        "delete": "Delete",
        "add_step": "Add step",
        "pick_icon": "Pick icon",
        "remove_icon": "Remove icon",
        "preview_fail": "(Preview failed: PNG/GIF recommended)",
        "no_icon": "(No icon)",
        "no_photo": "(No photo)",
    }
}

def t(lang: str, key: str, **kwargs) -> str:
    lang = lang if lang in I18N else "ko"
    s = I18N[lang].get(key, key)
    if kwargs:
        try:
            return s.format(**kwargs)
        except Exception:
            return s
    return s

# -----------------------------
# Settings
# -----------------------------
def default_settings():
    return {
        "language": "ko",
        "models": ["ME-400", "MGS-410"],
        "ga_board_types": ["DVI-only", "HDMI-only", "DVI+HDMI", "Unknown"]
    }

def load_settings():
    if not os.path.exists(SETTINGS_FILE):
        s = default_settings()
        save_settings(s)
        return s
    try:
        with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
            s = json.load(f)
        s.setdefault("language", "ko")
        s.setdefault("models", [])
        s.setdefault("ga_board_types", [])
        s.setdefault("tags", [])
        return s
    except Exception:
        s = default_settings()
        save_settings(s)
        return s

def save_settings(settings):
    with open(SETTINGS_FILE, "w", encoding="utf-8") as f:
        json.dump(settings, f, ensure_ascii=False, indent=2)

def sorted_unique(lst):
    seen = {}
    for x in lst:
        if x is None:
            continue
        x2 = str(x).strip()
        if x2:
            seen[x2] = True
    return sorted(seen.keys(), key=lambda s: s.lower())

class MultiSelectDropdown(ttk.Frame):
    def __init__(self, master, items, selected=None, width=40, allow_any=False):
        super().__init__(master)
        self.allow_any = allow_any
        self.items = []
        self.vars = {}

        self.btn_text = tk.StringVar(value="")
        self.btn = ttk.Menubutton(self, textvariable=self.btn_text, width=width)
        self.btn.pack(fill="x", expand=True)

        self.menu = tk.Menu(self.btn, tearoff=0)
        self.btn["menu"] = self.menu

        self.set_items(items, selected or [])

    def set_items(self, items, selected=None):
        selected = set(selected or [])
        self.items = list(items)
        self.menu.delete(0, tk.END)
        self.vars.clear()

        for it in self.items:
            v = tk.BooleanVar(value=(it in selected))
            self.vars[it] = v

            def _cmd(item=it):
                self._handle_click(item)
                self._refresh_label()

            self.menu.add_checkbutton(label=it, variable=v, command=_cmd)

        self._refresh_label()

    def _handle_click(self, item):
        if not self.allow_any:
            return

        if item == "ANY":
            if self.vars["ANY"].get():
                for k, v in self.vars.items():
                    if k != "ANY":
                        v.set(False)
        else:
            if self.vars.get(item) and self.vars[item].get():
                if "ANY" in self.vars:
                    self.vars["ANY"].set(False)

            if all(not v.get() for v in self.vars.values()):
                if "ANY" in self.vars:
                    self.vars["ANY"].set(True)

    def get_selected(self):
        return [k for k, v in self.vars.items() if v.get()]

    def set_selected(self, selected_list):
        sel = set(selected_list or [])
        for k, v in self.vars.items():
            v.set(k in sel)
        if self.allow_any and "ANY" in self.vars and all(not v.get() for v in self.vars.values()):
            self.vars["ANY"].set(True)
        self._refresh_label()

    def _refresh_label(self):
        sel = self.get_selected()
        if not sel:
            self.btn_text.set("(None)")
            return
        if len(sel) <= 3:
            self.btn_text.set(", ".join(sel))
        else:
            self.btn_text.set(f"{sel[0]}, {sel[1]}, {sel[2]} +{len(sel)-3}")

# -----------------------------
# Data
# -----------------------------
def default_data():
    return [
        {
            "symptom": "너무 어두운 부분이 잘 안보임",
            "cause": "FFC(Flat Field Correction)이 적용이 안됨",
            "tags": ["영상", "밝기", "FFC"],
            "applicability": {"models": ["ME-400", "MGS-410"], "ga_usage": "ANY", "ga_board_types": ["ANY"]},
            "solutions": [
                {"title": "Try 1: FFC 단축키 적용", "icon_path": "", "status": "unknown",
                 "steps": [
                     {"text": "키보드에서 Ctrl + Shift + F 를 누른다.", "done": False, "image_path": ""},
                     {"text": "화면 밝기/균일도가 개선되는지 확인한다.", "done": False, "image_path": ""},
                     {"text": "개선되면 작업을 종료한다.", "done": False, "image_path": ""},
                 ]}
            ]
        },
        {
            "symptom": "GA에 출력 내시경 영상이 안나옴",
            "cause": "모니터 출력 설정 또는 케이블/캡쳐보드 입력 문제 가능",
            "tags": ["GA", "출력", "캡쳐보드", "케이블"],
            "applicability": {"models": ["ME-400", "MGS-410"], "ga_usage": "YES",
                              "ga_board_types": ["DVI-only", "HDMI-only", "DVI+HDMI", "Unknown", "ANY"]},
            "solutions": [
                {"title": "Try 1: 모니터 출력(Out/Clone/DVI Out) 설정 확인", "icon_path": "", "status": "unknown",
                 "steps": [
                     {"text": "모니터 메뉴(OSD)로 들어간다.", "done": False, "image_path": ""},
                     {"text": "출력(Out) / Clone / DVI Out 관련 항목을 찾는다.", "done": False, "image_path": ""},
                     {"text": "출력을 ON(활성화)으로 변경한다.", "done": False, "image_path": ""},
                     {"text": "GA 화면에 영상이 들어오는지 확인한다.", "done": False, "image_path": ""},
                 ]},
                {"title": "Try 2: 캡쳐보드 입력 케이블/포트 점검 및 교체", "icon_path": "", "status": "unknown",
                 "steps": [
                     {"text": "GA 캡쳐보드에 연결된 케이블 규격(DVI/HDMI)을 확인한다.", "done": False, "image_path": ""},
                     {"text": "케이블 양쪽을 뽑았다가 다시 단단히 꽂는다.", "done": False, "image_path": ""},
                     {"text": "가능하면 다른 케이블로 교체한다.", "done": False, "image_path": ""},
                     {"text": "영상이 들어오는지 확인한다.", "done": False, "image_path": ""},
                 ]},
            ]
        }
    ]

def save_data(data):
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def load_data():
    if not os.path.exists(DATA_FILE):
        d = default_data()
        save_data(d)
        return d
    try:
        with open(DATA_FILE, "r", encoding="utf-8") as f:
            d = json.load(f)
        for item in d:
            item.setdefault("symptom", "")
            item.setdefault("cause", "")
            item.setdefault("tags", [])
            app = item.setdefault("applicability", {})
            app.setdefault("models", ["ANY"])
            app.setdefault("ga_usage", "ANY")
            app.setdefault("ga_board_types", ["ANY"])
            sols = item.setdefault("solutions", [])
            for sol in sols:
                sol.setdefault("title", "")
                sol.setdefault("icon_path", "")
                sol.setdefault("status", "unknown")
                steps = sol.setdefault("steps", [])
                if steps and isinstance(steps[0], str):
                    sol["steps"] = [{"text": s, "done": False, "image_path": ""} for s in steps]
                else:
                    for st in steps:
                        st.setdefault("text", "")
                        st.setdefault("done", False)
                        st.setdefault("image_path", "")
        save_data(d)
        return d
    except Exception:
        d = default_data()
        save_data(d)
        return d

def load_logs():
    if not os.path.exists(LOG_FILE):
        return []
    try:
        with open(LOG_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return []

def save_logs(logs):
    with open(LOG_FILE, "w", encoding="utf-8") as f:
        json.dump(logs, f, ensure_ascii=False, indent=2)

def matches_query(item, query: str) -> bool:
    q = (query or "").strip()
    if not q:
        return True
    q = q.replace(",", " ")
    keywords = [k.strip().lower() for k in q.split() if k.strip()]
    if not keywords:
        return True
    hay = " ".join([
        item.get("symptom", ""),
        item.get("cause", ""),
        " ".join(item.get("tags", [])),
        " ".join(sol.get("title", "") for sol in item.get("solutions", [])),
        " ".join(st.get("text", "") for sol in item.get("solutions", []) for st in sol.get("steps", [])),
    ]).lower()
    return all(k in hay for k in keywords)

def matches_filters(item, model_filter: str, ga_usage_filter: str, board_filter: str) -> bool:
    app = item.get("applicability", {})
    models = app.get("models", ["ANY"])
    item_ga = app.get("ga_usage", "ANY")
    boards = app.get("ga_board_types", ["ANY"])

    model_ok = (model_filter == "ALL") or ("ANY" in models) or (model_filter in models)

    if ga_usage_filter == "ANY":
        ga_ok = True
    else:
        ga_ok = (item_ga == "ANY") or (item_ga == ga_usage_filter)

    if ga_usage_filter == "NO":
        board_ok = True
    else:
        if item_ga == "NO":
            board_ok = True
        else:
            board_ok = (board_filter == "ALL") or ("ANY" in boards) or (board_filter in boards)

    return model_ok and ga_ok and board_ok

def collect_tags_from_data(data):
    tags = []
    for item in data:
        for tg in item.get("tags", []):
            if isinstance(tg, str) and tg.strip():
                tags.append(tg.strip())
    return sorted_unique(tags)

# -----------------------------
# App
# -----------------------------
class TroubleshooterV6(tb.Toplevel):
    def __init__(self, master=None):
        super().__init__(master)
        self.settings = load_settings()
        self.lang = self.settings.get("language", "ko")
        self.data = load_data()
        self.logs = load_logs()

        self.filtered_indices = []
        self.selected_issue_index = None
        self.selected_solution_index = None

        self._preview_img_ref = None
        self._icon_img_ref = None

        self._build_ui()
        self._apply_language()
        self._refresh_filter_lists()
        self.refresh_issue_list()

        self.transient(master) if master is not None else None
        self.lift()

    def _build_ui(self):
        self.title(t(self.lang, "app_title"))
        self.geometry("1180x760")
        self.minsize(600, 640)

                # ---------- Top bar ----------
        self.top = tb.Frame(self, padding=10)
        self.top.pack(fill="x")

        # 1줄: 드롭다운/검색 (필터 row)
        top_filters = tb.Frame(self.top)
        top_filters.pack(fill="x")

        self.lbl_lang = tb.Label(top_filters)
        self.lbl_lang.pack(side="left")

        self.lang_var = tk.StringVar(value=self.lang)
        self.lang_combo = ttk.Combobox(top_filters, textvariable=self.lang_var, state="readonly", width=2, values=["ko", "en"])
        self.lang_combo.pack(side="left", padx=6)
        self.lang_combo.bind("<<ComboboxSelected>>", lambda e: self.on_change_language())

        self.lbl_model = tb.Label(top_filters)
        self.lbl_model.pack(side="left", padx=(12, 0))
        self.model_filter = tk.StringVar(value="ALL")
        self.model_combo = ttk.Combobox(top_filters, textvariable=self.model_filter, state="readonly", width=10)
        self.model_combo.pack(side="left", padx=6)
        self.model_combo.bind("<<ComboboxSelected>>", lambda e: self.refresh_issue_list())

        self.lbl_ga = tb.Label(top_filters)
        self.lbl_ga.pack(side="left", padx=(12, 0))
        self.ga_usage_filter = tk.StringVar(value="ANY")
        self.ga_usage_combo = ttk.Combobox(top_filters, textvariable=self.ga_usage_filter, state="readonly", width=5, values=["ANY", "NO", "YES"])
        self.ga_usage_combo.pack(side="left", padx=6)
        self.ga_usage_combo.bind("<<ComboboxSelected>>", lambda e: self.on_ga_usage_changed())

        self.lbl_board = tb.Label(top_filters)
        self.lbl_board.pack(side="left", padx=(12, 0))
        self.board_filter = tk.StringVar(value="ALL")
        self.board_combo = ttk.Combobox(top_filters, textvariable=self.board_filter, state="readonly", width=5)
        self.board_combo.pack(side="left", padx=6)
        self.board_combo.bind("<<ComboboxSelected>>", lambda e: self.refresh_issue_list())

        self.lbl_search = tb.Label(top_filters)
        self.lbl_search.pack(side="left", padx=(12, 0))
        self.search_var = tk.StringVar()
        self.search_entry = tb.Entry(top_filters, textvariable=self.search_var, width=26)
        self.search_entry.pack(side="left", padx=6)
        self.search_entry.bind("<KeyRelease>", lambda e: self.refresh_issue_list())

        # 2줄: 버튼들 (드롭다운 아래)
        top_actions = tb.Frame(self.top)
        top_actions.pack(fill="x", pady=(8, 0))

        self.btn_manage = tb.Button(top_actions, command=self.open_manage_settings, bootstyle="secondary")
        self.btn_manage.pack(side="left", padx=6)

        self.btn_add_issue = tb.Button(top_actions, command=self.open_add_issue_window, bootstyle="primary")
        self.btn_add_issue.pack(side="left", padx=6)

        self.btn_edit_issue = tb.Button(top_actions, command=self.open_edit_issue_window, bootstyle="warning")
        self.btn_edit_issue.pack(side="left", padx=6)

        self.btn_del_issue = tb.Button(top_actions, command=self.delete_issue, bootstyle="danger")
        self.btn_del_issue.pack(side="left", padx=6)


        # ---------- Log bar (card-like) ----------
        self.logbar = tb.Labelframe(self, padding=10, bootstyle="info")
        self.logbar.pack(fill="x", padx=10, pady=(0, 10))

        self.now_var = tk.StringVar(value=self._now_str())
        self.lbl_dt = tb.Label(self.logbar)
        self.lbl_dt.grid(row=0, column=0, sticky="w")
        tb.Entry(self.logbar, textvariable=self.now_var, width=18, state="readonly").grid(row=0, column=1, sticky="w", padx=(6, 16))

        self.lbl_loc = tb.Label(self.logbar)
        self.lbl_loc.grid(row=0, column=2, sticky="w")
        self.location_var = tk.StringVar()
        tb.Entry(self.logbar, textvariable=self.location_var, width=18).grid(row=0, column=3, sticky="w", padx=(6, 16))

        self.lbl_sn = tb.Label(self.logbar)
        self.lbl_sn.grid(row=0, column=4, sticky="w")
        self.sn_var = tk.StringVar()
        tb.Entry(self.logbar, textvariable=self.sn_var, width=18).grid(row=0, column=5, sticky="w", padx=(6, 16))

        self.lbl_note = tb.Label(self.logbar)
        self.lbl_note.grid(row=0, column=6, sticky="w")
        self.note_var = tk.StringVar()
        tb.Entry(self.logbar, textvariable=self.note_var, width=18).grid(row=0, column=7, sticky="we", padx=(6, 16))

        self.btn_export = tb.Button(self.logbar, command=self.export_logs_csv, bootstyle="secondary")
        self.btn_export.grid(row=0, column=8, sticky="e")
        self.btn_time = tb.Button(self.logbar, command=self.refresh_now, bootstyle="secondary")
        self.btn_time.grid(row=0, column=9, sticky="e", padx=(6, 0))

        self.logbar.columnconfigure(7, weight=1)

        # ---------- Main (responsive) ----------
        main = tb.Frame(self, padding=(10, 0, 10, 10))
        main.pack(fill="both", expand=True)

        # 왼쪽: 리스트 (고정폭 느낌)
        left = tb.Labelframe(main, padding=10, bootstyle="secondary")
        left.pack(side="left", fill="y")

        self.lbl_issue_list = tb.Label(left)
        self.lbl_issue_list.pack(anchor="w")

        self.issue_listbox = tk.Listbox(left, width=34, height=26)
        self.issue_listbox.pack(fill="y", pady=8)
        self.issue_listbox.bind("<<ListboxSelect>>", self.on_issue_selected)

        # 오른쪽: 상세 (확장)
        right = tb.Frame(main)
        right.pack(side="left", fill="both", expand=True, padx=(12, 0))

        # 헤더 카드
        hdr = tb.Labelframe(right, padding=12, bootstyle="light")
        hdr.pack(fill="x")

        self.lbl_selected_issue = tb.Label(hdr, font=("Segoe UI", 10, "bold"))
        self.lbl_selected_issue.grid(row=0, column=0, sticky="w")

        self.symptom_lbl = tb.Label(hdr, text="(None)", font=("Segoe UI", 16, "bold"))
        self.symptom_lbl.grid(row=1, column=0, sticky="w", pady=(2, 10))

        self.lbl_scope = tb.Label(hdr)
        self.lbl_scope.grid(row=2, column=0, sticky="w")
        self.appl_lbl = tb.Label(hdr, text="-")
        self.appl_lbl.grid(row=3, column=0, sticky="w", pady=(2, 10))

        self.lbl_cause = tb.Label(hdr)
        self.lbl_cause.grid(row=4, column=0, sticky="w")
        self.cause_txt = tk.Text(hdr, height=3, wrap="word")
        self.cause_txt.grid(row=5, column=0, sticky="we", pady=(2, 0))
        self.cause_txt.configure(state="disabled")
        hdr.columnconfigure(0, weight=1)

        # Try 선택/관리 바
                # Try 선택/관리 바
        solbar = tb.Labelframe(right, padding=10, bootstyle="secondary")
        solbar.pack(fill="x", pady=(10, 6))

        # 1줄: 드롭다운
        sol_row1 = tb.Frame(solbar)
        sol_row1.pack(fill="x")

        self.lbl_try_select = tb.Label(sol_row1)
        self.lbl_try_select.pack(side="left")

        self.solution_combo = ttk.Combobox(sol_row1, state="readonly", width=42)
        self.solution_combo.pack(side="left", padx=8)
        self.solution_combo.bind("<<ComboboxSelected>>", lambda e: self.on_solution_selected())

        # 2줄: 버튼들 (드롭다운 아래)
        sol_row2 = tb.Frame(solbar)
        sol_row2.pack(fill="x", pady=(8, 0))

        self.btn_add_try = tb.Button(sol_row2, command=self.open_add_solution_window, bootstyle="primary")
        self.btn_add_try.pack(side="left", padx=6)

        self.btn_edit_try = tb.Button(sol_row2, command=self.open_edit_solution_window, bootstyle="warning")
        self.btn_edit_try.pack(side="left", padx=6)

        self.btn_del_try = tb.Button(sol_row2, command=self.delete_solution, bootstyle="danger")
        self.btn_del_try.pack(side="left", padx=6)


        # workflow bar
        wf = tb.Labelframe(right, padding=10, bootstyle="info")
        wf.pack(fill="x", pady=(0, 10))

        self.try_status_lbl = tb.Label(wf, text=f"{t(self.lang,'try_status')} -")
        self.try_status_lbl.pack(side="left")

        self.btn_success = tb.Button(wf, command=self.mark_try_success, bootstyle="success")
        self.btn_success.pack(side="left", padx=8)
        self.btn_fail = tb.Button(wf, command=self.mark_try_failed_and_next, bootstyle="danger")
        self.btn_fail.pack(side="left", padx=8)
        self.btn_reset = tb.Button(wf, command=self.reset_current_try_checks, bootstyle="secondary")
        self.btn_reset.pack(side="left", padx=8)

        # content row: steps + preview (둘 다 확장)
        content = tb.Frame(right)
        content.pack(fill="both", expand=True)

        # Steps: 확장
        self.steps_frame = tb.Labelframe(content, padding=6, bootstyle="light")
        self.steps_frame.pack(side="left", fill="both", expand=True)

        self.steps_canvas = tk.Canvas(self.steps_frame, highlightthickness=0)
        self.steps_scroll = ttk.Scrollbar(self.steps_frame, orient="vertical", command=self.steps_canvas.yview)
        self.steps_canvas.configure(yscrollcommand=self.steps_scroll.set)
        self.steps_scroll.pack(side="right", fill="y")
        self.steps_canvas.pack(side="left", fill="both", expand=True)

        self.steps_inner = tb.Frame(self.steps_canvas)
        self.steps_inner_id = self.steps_canvas.create_window((0, 0), window=self.steps_inner, anchor="nw")
        self.steps_inner.bind("<Configure>", lambda e: self.steps_canvas.configure(scrollregion=self.steps_canvas.bbox("all")))
        self.steps_canvas.bind("<Configure>", lambda e: self.steps_canvas.itemconfigure(self.steps_inner_id, width=e.width))

        # Preview: 고정폭 느낌 + fill y/both
        self.preview = tb.Labelframe(content, padding=10, bootstyle="secondary")
        self.preview.pack(side="left", fill="both", padx=(10, 0))

        self.lbl_try_icon = tb.Label(self.preview)
        self.lbl_try_icon.pack(anchor="w", padx=6, pady=(6, 4))
        self.icon_img_label = tb.Label(self.preview, text=t(self.lang, "no_icon"), width=44, anchor="center")
        self.icon_img_label.pack(padx=6, pady=(0, 10))

        self.lbl_step_photo = tb.Label(self.preview)
        self.lbl_step_photo.pack(anchor="w", padx=6, pady=(6, 4))
        self.preview_img_label = tb.Label(self.preview, text=t(self.lang, "no_photo"), width=44, anchor="center")
        self.preview_img_label.pack(padx=6, pady=(0, 10))

        self.log_count_lbl = tb.Label(self, text=t(self.lang, "logs_count", n=len(self.logs), file=LOG_FILE))
        self.log_count_lbl.pack(anchor="w", padx=12, pady=(8, 10))

    # ---------- language ----------
    def _apply_language(self):
        self.lang = self.lang_var.get() if self.lang_var.get() in ("ko", "en") else "ko"
        self.title(t(self.lang, "app_title"))

        self.lbl_lang.configure(text=t(self.lang, "lang"))
        self.lbl_model.configure(text=t(self.lang, "model"))
        self.lbl_ga.configure(text=t(self.lang, "ga_use"))
        self.lbl_board.configure(text=t(self.lang, "ga_board"))
        self.lbl_search.configure(text=t(self.lang, "search"))

        self.btn_manage.configure(text=t(self.lang, "manage_models_boards"))
        self.btn_add_issue.configure(text=t(self.lang, "add_issue"))
        self.btn_edit_issue.configure(text=t(self.lang, "edit_issue"))
        self.btn_del_issue.configure(text=t(self.lang, "delete_issue"))

        self.logbar.configure(text=t(self.lang, "log_box_title"))
        self.lbl_dt.configure(text=t(self.lang, "dt"))
        self.lbl_loc.configure(text=t(self.lang, "location"))
        self.lbl_sn.configure(text=t(self.lang, "sn"))
        self.lbl_note.configure(text=t(self.lang, "note"))
        self.btn_export.configure(text=t(self.lang, "export_csv"))
        self.btn_time.configure(text=t(self.lang, "refresh_time"))

        self.lbl_issue_list.configure(text=t(self.lang, "issue_list"))
        self.lbl_selected_issue.configure(text=t(self.lang, "selected_issue"))
        self.lbl_scope.configure(text=t(self.lang, "scope"))
        self.lbl_cause.configure(text=t(self.lang, "cause"))

        self.lbl_try_select.configure(text=t(self.lang, "try_select"))
        self.btn_add_try.configure(text=t(self.lang, "add_try"))
        self.btn_edit_try.configure(text=t(self.lang, "edit_try"))
        self.btn_del_try.configure(text=t(self.lang, "delete_try"))

        self.btn_success.configure(text=t(self.lang, "try_success"))
        self.btn_fail.configure(text=t(self.lang, "try_fail_next"))
        self.btn_reset.configure(text=t(self.lang, "try_reset"))

        self.steps_frame.configure(text=t(self.lang, "steps_title"))
        self.preview.configure(text=t(self.lang, "preview_title"))
        self.lbl_try_icon.configure(text=t(self.lang, "try_icon"))
        self.lbl_step_photo.configure(text=t(self.lang, "step_photo"))

        self.log_count_lbl.configure(text=t(self.lang, "logs_count", n=len(self.logs), file=LOG_FILE))

        if self._icon_img_ref is None:
            self.icon_img_label.configure(text=t(self.lang, "no_icon"))
        if self._preview_img_ref is None:
            self.preview_img_label.configure(text=t(self.lang, "no_photo"))

    def on_change_language(self):
        self.lang = self.lang_var.get()
        self.settings["language"] = self.lang
        save_settings(self.settings)
        self._apply_language()
        if self.selected_issue_index is not None:
            self.render_issue()
        self.refresh_issue_list()

    # ---------- filters ----------
    def _refresh_filter_lists(self):
        models = ["ALL"] + sorted_unique(self.settings.get("models", []))
        boards = ["ALL"] + sorted_unique(self.settings.get("ga_board_types", []))

        self.model_combo["values"] = models
        if self.model_filter.get() not in models:
            self.model_filter.set("ALL")

        self.board_combo["values"] = boards
        if self.board_filter.get() not in boards:
            self.board_filter.set("ALL")

        self.on_ga_usage_changed(refresh_only=True)

    def on_ga_usage_changed(self, refresh_only=False):
        if self.ga_usage_filter.get() == "NO":
            self.board_combo.configure(state="disabled")
            self.board_filter.set("ALL")
        else:
            self.board_combo.configure(state="readonly")
        if not refresh_only:
            self.refresh_issue_list()

    # ---------- time ----------
    def _now_str(self):
        return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    def refresh_now(self):
        self.now_var.set(self._now_str())

    # ---------- list ----------
    def refresh_issue_list(self):
        q = self.search_var.get()
        mf = self.model_filter.get()
        gf = self.ga_usage_filter.get()
        bf = self.board_filter.get()

        filtered = []
        for i, item in enumerate(self.data):
            if matches_query(item, q) and matches_filters(item, mf, gf, bf):
                filtered.append(i)

        filtered.sort(key=lambda idx: (self.data[idx].get("symptom", "").strip().lower()))
        self.filtered_indices = filtered

        self.issue_listbox.delete(0, tk.END)
        for idx in self.filtered_indices:
            self.issue_listbox.insert(tk.END, self.data[idx].get("symptom", ""))

        if self.selected_issue_index in self.filtered_indices:
            pos = self.filtered_indices.index(self.selected_issue_index)
            self.issue_listbox.selection_clear(0, tk.END)
            self.issue_listbox.selection_set(pos)
            self.issue_listbox.see(pos)
        else:
            self.clear_detail()

    def on_issue_selected(self, event=None):
        sel = self.issue_listbox.curselection()
        if not sel:
            return
        self.selected_issue_index = self.filtered_indices[sel[0]]
        self.render_issue()

    def clear_detail(self):
        self.selected_issue_index = None
        self.selected_solution_index = None
        self.symptom_lbl.configure(text="(None)")
        self.appl_lbl.configure(text="-")
        self.cause_txt.configure(state="normal")
        self.cause_txt.delete("1.0", tk.END)
        self.cause_txt.configure(state="disabled")
        self.solution_combo["values"] = []
        self.solution_combo.set("")
        self.try_status_lbl.configure(text=f"{t(self.lang,'try_status')} -")
        self._clear_steps_ui()
        self._set_icon_preview("")
        self._set_step_preview("")

    def render_issue(self):
        if self.selected_issue_index is None:
            return
        item = self.data[self.selected_issue_index]
        self.symptom_lbl.configure(text=item.get("symptom", ""))

        app = item.get("applicability", {})
        self.appl_lbl.configure(
            text=f"models: {', '.join(app.get('models', ['ANY']))} | GA: {app.get('ga_usage', 'ANY')} | boards: {', '.join(app.get('ga_board_types', ['ANY']))}"
        )

        self.cause_txt.configure(state="normal")
        self.cause_txt.delete("1.0", tk.END)
        self.cause_txt.insert(tk.END, item.get("cause", ""))
        self.cause_txt.configure(state="disabled")

        sols = item.get("solutions", [])
        titles = [s.get("title", f"Try {k+1}") for k, s in enumerate(sols)]

        self.lbl_try_select.configure(text=f"{t(self.lang, 'try_select')} ({len(titles)})")

        self.solution_combo["values"] = titles
        if titles:
            self.solution_combo.current(0)
            self.selected_solution_index = 0
            self.render_solution()
        else:
            self.solution_combo.set("")
            self.selected_solution_index = None
            self.try_status_lbl.configure(text=f"{t(self.lang,'try_status')} -")
            self._clear_steps_ui()
            self._set_icon_preview("")
            self._set_step_preview("")

    def on_solution_selected(self):
        if self.selected_issue_index is None:
            return
        idx = self.solution_combo.current()
        if idx < 0:
            return
        self.selected_solution_index = idx
        self.render_solution()

    def _get_current_sol(self):
        if self.selected_issue_index is None or self.selected_solution_index is None:
            return None
        return self.data[self.selected_issue_index]["solutions"][self.selected_solution_index]

    def render_solution(self):
        sol = self._get_current_sol()
        if not sol:
            return
        self.try_status_lbl.configure(text=f"{t(self.lang,'try_status')} {sol.get('status','unknown')}")
        self._set_icon_preview(sol.get("icon_path", ""))
        self._build_steps_ui(sol)

    # ---------- steps ----------
    def _clear_steps_ui(self):
        for child in self.steps_inner.winfo_children():
            child.destroy()

    def _build_steps_ui(self, sol):
        self._clear_steps_ui()

        top_row = tb.Frame(self.steps_inner)
        top_row.pack(fill="x", pady=(10, 8), padx=10)
        tb.Label(top_row, text=f"{t(self.lang,'try_icon')}: ").pack(side="left")
        tb.Button(top_row, text=t(self.lang, "pick_icon"), command=self.pick_try_icon, bootstyle="secondary").pack(side="left", padx=6)
        tb.Button(top_row, text=t(self.lang, "remove_icon"), command=self.clear_try_icon, bootstyle="secondary").pack(side="left", padx=6)

        ttk.Separator(self.steps_inner).pack(fill="x", padx=10, pady=6)

        steps = sol.get("steps", [])
        for i, st in enumerate(steps):
            row = tb.Frame(self.steps_inner)
            row.pack(fill="x", padx=10, pady=4)

            var = tk.BooleanVar(value=bool(st.get("done", False)))

            def on_toggle(ix=i, v=var):
                sol["steps"][ix]["done"] = bool(v.get())
                save_data(self.data)

            cb = ttk.Checkbutton(row, text=f"{i+1}. {st.get('text','')}", variable=var, command=on_toggle)
            cb.pack(side="left", fill="x", expand=True)

            tb.Button(row, text=t(self.lang, "edit_step"), command=lambda ix=i: self.open_edit_step_window(ix), bootstyle="secondary").pack(side="left", padx=4)
            tb.Button(row, text=t(self.lang, "up"), width=2, command=lambda ix=i: self.move_step(ix, -1), bootstyle="secondary").pack(side="left", padx=2)
            tb.Button(row, text=t(self.lang, "down"), width=2, command=lambda ix=i: self.move_step(ix, +1), bootstyle="secondary").pack(side="left", padx=2)

            tb.Button(row, text=t(self.lang, "photo"), command=lambda ix=i: self.pick_step_image(ix), bootstyle="secondary").pack(side="left", padx=4)
            tb.Button(row, text=t(self.lang, "view"), command=lambda ix=i: self.preview_step_image(ix), bootstyle="secondary").pack(side="left", padx=2)
            tb.Button(row, text=t(self.lang, "delete"), command=lambda ix=i: self.delete_step(ix), bootstyle="danger").pack(side="left", padx=2)

        add_row = tb.Frame(self.steps_inner)
        add_row.pack(fill="x", padx=10, pady=(10, 12))
        tb.Button(add_row, text=t(self.lang, "add_step"), command=self.add_step, bootstyle="primary").pack(side="left")

    def add_step(self):
        sol = self._get_current_sol()
        if not sol:
            messagebox.showinfo(t(self.lang, "info"), t(self.lang, "select_issue_try_first"))
            return
        sol["steps"].append({"text": "New step" if self.lang == "en" else "새 단계", "done": False, "image_path": ""})
        save_data(self.data)
        self.render_solution()

    def delete_step(self, step_index: int):
        sol = self._get_current_sol()
        if not sol:
            return
        if not messagebox.askyesno(t(self.lang, "confirm"), t(self.lang, "delete_step_q", k=step_index+1)):
            return
        del sol["steps"][step_index]
        save_data(self.data)
        self.render_solution()

    def move_step(self, step_index: int, direction: int):
        sol = self._get_current_sol()
        if not sol:
            return
        steps = sol["steps"]
        j = step_index + direction
        if j < 0 or j >= len(steps):
            return
        steps[step_index], steps[j] = steps[j], steps[step_index]
        save_data(self.data)
        self.render_solution()

    # ---------- edit windows (Issue/Try/Step) ----------
    def open_edit_issue_window(self):
        if self.selected_issue_index is None:
            messagebox.showinfo(t(self.lang, "info"), t(self.lang, "select_issue_first"))
            return
        item = self.data[self.selected_issue_index]

        win = tb.Toplevel(self)
        win.title(t(self.lang, "edit_issue"))
        win.geometry("820x700")
        win.transient(self)
        win.grab_set()

        tb.Label(win, text="Symptom").pack(anchor="w", padx=12, pady=(12, 4))
        symptom_var = tk.StringVar(value=item.get("symptom", ""))
        tb.Entry(win, textvariable=symptom_var).pack(fill="x", padx=12)

        tb.Label(win, text="Cause").pack(anchor="w", padx=12, pady=(12, 4))
        cause_txt = tk.Text(win, height=5, wrap="word")
        cause_txt.pack(fill="x", padx=12)
        cause_txt.insert("1.0", item.get("cause", ""))

        tb.Label(win, text="Tags (comma)").pack(anchor="w", padx=12, pady=(12, 4))
        tags_var = tk.StringVar(value=", ".join(item.get("tags", [])))
        tb.Entry(win, textvariable=tags_var).pack(fill="x", padx=12)

        ttk.Separator(win).pack(fill="x", padx=12, pady=12)

        app = item.get("applicability", {})
        tb.Label(win, text="Models (comma or ANY)").pack(anchor="w", padx=12)
        models_var = tk.StringVar(value=", ".join(app.get("models", ["ANY"])))
        tb.Entry(win, textvariable=models_var).pack(fill="x", padx=12, pady=(4, 10))

        tb.Label(win, text="GA usage (ANY/NO/YES)").pack(anchor="w", padx=12)
        ga_var = tk.StringVar(value=app.get("ga_usage", "ANY"))
        ttk.Combobox(win, textvariable=ga_var, state="readonly", values=["ANY", "NO", "YES"]).pack(
            fill="x", padx=12, pady=(4, 10)
        )

        tb.Label(win, text="GA boards (comma or ANY)").pack(anchor="w", padx=12)
        boards_var = tk.StringVar(value=", ".join(app.get("ga_board_types", ["ANY"])))
        tb.Entry(win, textvariable=boards_var).pack(fill="x", padx=12, pady=(4, 10))

        btns = tb.Frame(win)
        btns.pack(fill="x", padx=12, pady=12)

        def parse_list(s, default="ANY"):
            parts = [p.strip() for p in (s or "").split(",") if p.strip()]
            return parts if parts else [default]

        def on_save():
            symptom = symptom_var.get().strip()
            if not symptom:
                messagebox.showwarning(t(self.lang, "required"), t(self.lang, "cannot_empty_symptom"))
                return
            item["symptom"] = symptom
            item["cause"] = cause_txt.get("1.0", tk.END).strip()
            item["tags"] = [x.strip() for x in tags_var.get().split(",") if x.strip()]
            item["applicability"] = {
                "models": parse_list(models_var.get(), "ANY"),
                "ga_usage": ga_var.get(),
                "ga_board_types": parse_list(boards_var.get(), "ANY")
            }
            save_data(self.data)
            self.refresh_issue_list()
            self.render_issue()
            win.destroy()

        tb.Button(btns, text=t(self.lang, "save"), command=on_save, bootstyle="primary").pack(side="left")
        tb.Button(btns, text=t(self.lang, "cancel"), command=win.destroy, bootstyle="secondary").pack(side="left", padx=8)

    def open_edit_solution_window(self):
        sol = self._get_current_sol()
        if not sol:
            messagebox.showinfo(t(self.lang, "info"), t(self.lang, "select_try_first"))
            return
        win = tb.Toplevel(self)
        win.title(t(self.lang, "edit_try"))
        win.geometry("620x260")
        win.transient(self)
        win.grab_set()

        tb.Label(win, text="Try title").pack(anchor="w", padx=12, pady=(12, 4))
        title_var = tk.StringVar(value=sol.get("title", ""))
        tb.Entry(win, textvariable=title_var).pack(fill="x", padx=12)

        ttk.Separator(win).pack(fill="x", padx=12, pady=12)

        row = tb.Frame(win)
        row.pack(fill="x", padx=12)
        tb.Button(row, text=t(self.lang, "pick_icon"), command=self.pick_try_icon, bootstyle="secondary").pack(side="left")
        tb.Button(row, text=t(self.lang, "remove_icon"), command=self.clear_try_icon, bootstyle="secondary").pack(side="left", padx=8)

        btns = tb.Frame(win)
        btns.pack(fill="x", padx=12, pady=16)

        def on_save():
            title = title_var.get().strip()
            if not title:
                messagebox.showwarning(t(self.lang, "required"), t(self.lang, "cannot_empty_try"))
                return
            sol["title"] = title
            save_data(self.data)
            self.render_issue()
            if self.selected_solution_index is not None:
                self.solution_combo.current(self.selected_solution_index)
                self.render_solution()
            win.destroy()

        tb.Button(btns, text=t(self.lang, "save"), command=on_save, bootstyle="primary").pack(side="left")
        tb.Button(btns, text=t(self.lang, "cancel"), command=win.destroy, bootstyle="secondary").pack(side="left", padx=8)

    def open_edit_step_window(self, step_index: int):
        sol = self._get_current_sol()
        if not sol:
            return
        st = sol["steps"][step_index]

        win = tb.Toplevel(self)
        win.title(f"Step #{step_index+1}")
        win.geometry("720x260")
        win.transient(self)
        win.grab_set()

        tb.Label(win, text="Step text").pack(anchor="w", padx=12, pady=(12, 4))
        txt = tk.Text(win, height=6, wrap="word")
        txt.pack(fill="both", expand=True, padx=12)
        txt.insert("1.0", st.get("text", ""))

        btns = tb.Frame(win)
        btns.pack(fill="x", padx=12, pady=12)

        def on_save():
            new_text = txt.get("1.0", tk.END).strip()
            if not new_text:
                messagebox.showwarning(t(self.lang, "required"), t(self.lang, "cannot_empty_step"))
                return
            st["text"] = new_text
            save_data(self.data)
            self.render_solution()
            win.destroy()

        tb.Button(btns, text=t(self.lang, "save"), command=on_save, bootstyle="primary").pack(side="left")
        tb.Button(btns, text=t(self.lang, "cancel"), command=win.destroy, bootstyle="secondary").pack(side="left", padx=8)

    # ---------- images ----------
    def pick_try_icon(self):
        sol = self._get_current_sol()
        if not sol:
            messagebox.showinfo(t(self.lang, "info"), t(self.lang, "select_issue_try_first"))
            return
        path = filedialog.askopenfilename(
            title="Pick icon",
            filetypes=[("Image files", "*.png;*.gif;*.ppm;*.pgm"), ("All files", "*.*")]
        )
        if not path:
            return
        sol["icon_path"] = path
        save_data(self.data)
        self._set_icon_preview(path)

    def clear_try_icon(self):
        sol = self._get_current_sol()
        if not sol:
            return
        sol["icon_path"] = ""
        save_data(self.data)
        self._set_icon_preview("")

    def pick_step_image(self, step_index: int):
        sol = self._get_current_sol()
        if not sol:
            return
        path = filedialog.askopenfilename(
            title="Pick step image",
            filetypes=[("Image files", "*.png;*.gif;*.ppm;*.pgm"), ("All files", "*.*")]
        )
        if not path:
            return
        sol["steps"][step_index]["image_path"] = path
        save_data(self.data)
        self._set_step_preview(path)

    def preview_step_image(self, step_index: int):
        sol = self._get_current_sol()
        if not sol:
            return
        path = sol["steps"][step_index].get("image_path", "")
        if not path:
            messagebox.showinfo(t(self.lang, "info"), t(self.lang, "step_no_image"))
            return
        self._set_step_preview(path)

    def _set_icon_preview(self, path: str):
        if not path or not os.path.exists(path):
            self._icon_img_ref = None
            self.icon_img_label.configure(text=t(self.lang, "no_icon"), image="")
            return
        try:
            img = tk.PhotoImage(file=path)
            while img.width() > 360 or img.height() > 220:
                img = img.subsample(2, 2)
            self._icon_img_ref = img
            self.icon_img_label.configure(text="", image=img)
        except Exception:
            self._icon_img_ref = None
            self.icon_img_label.configure(text=t(self.lang, "preview_fail"), image="")

    def _set_step_preview(self, path: str):
        if not path or not os.path.exists(path):
            self._preview_img_ref = None
            self.preview_img_label.configure(text=t(self.lang, "no_photo"), image="")
            return
        try:
            img = tk.PhotoImage(file=path)
            while img.width() > 360 or img.height() > 480:
                img = img.subsample(2, 2)
            self._preview_img_ref = img
            self.preview_img_label.configure(text="", image=img)
        except Exception:
            self._preview_img_ref = None
            self.preview_img_label.configure(text=t(self.lang, "preview_fail"), image="")

    # ---------- workflow ----------
    def reset_current_try_checks(self):
        sol = self._get_current_sol()
        if not sol:
            messagebox.showinfo(t(self.lang, "info"), t(self.lang, "select_issue_try_first"))
            return
        for st in sol.get("steps", []):
            st["done"] = False
        sol["status"] = "unknown"
        save_data(self.data)
        self.render_solution()

    def mark_try_success(self):
        sol = self._get_current_sol()
        if not sol:
            messagebox.showinfo(t(self.lang, "info"), t(self.lang, "select_issue_try_first"))
            return
        sol["status"] = "success"
        save_data(self.data)
        self.refresh_now()
        self._append_log("success")
        self.render_solution()
        messagebox.showinfo(t(self.lang, "done"), t(self.lang, "success_logged"))

    def mark_try_failed_and_next(self):
        if self.selected_issue_index is None or self.selected_solution_index is None:
            messagebox.showinfo(t(self.lang, "info"), t(self.lang, "select_issue_try_first"))
            return
        item = self.data[self.selected_issue_index]
        sols = item.get("solutions", [])
        if not sols:
            return

        sols[self.selected_solution_index]["status"] = "failed"
        save_data(self.data)
        self.refresh_now()
        self._append_log("failed")

        next_idx = self.selected_solution_index + 1
        if next_idx < len(sols):
            self.solution_combo.current(next_idx)
            self.selected_solution_index = next_idx
            self.render_solution()
            messagebox.showinfo(t(self.lang, "next_try"), t(self.lang, "moved_next"))
        else:
            self.render_solution()
            messagebox.showwarning(t(self.lang, "last_try"), t(self.lang, "last_try_msg"))

    # ---------- logging ----------
    def _append_log(self, result: str):
        if self.selected_issue_index is None or self.selected_solution_index is None:
            return

        item = self.data[self.selected_issue_index]
        sol = item["solutions"][self.selected_solution_index]
        steps = sol.get("steps", [])
        done_count = sum(1 for st in steps if st.get("done"))
        total_count = len(steps)

        log = {
            "datetime": self.now_var.get() or self._now_str(),
            "location": self.location_var.get().strip(),
            "device_sn": self.sn_var.get().strip(),
            "model_filter": self.model_filter.get(),
            "ga_usage_filter": self.ga_usage_filter.get(),
            "ga_board_filter": self.board_filter.get() if self.ga_usage_filter.get() != "NO" else "N/A",
            "symptom": item.get("symptom", ""),
            "cause": item.get("cause", ""),
            "try_title": sol.get("title", ""),
            "result": result,
            "checked_steps": f"{done_count}/{total_count}",
            "note": self.note_var.get().strip()
        }
        self.logs.append(log)
        save_logs(self.logs)
        self.log_count_lbl.configure(text=t(self.lang, "logs_count", n=len(self.logs), file=LOG_FILE))

    def export_logs_csv(self):
        if not self.logs:
            messagebox.showinfo(t(self.lang, "info"), t(self.lang, "no_logs"))
            return

        default_name = f"work_logs_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
        path = filedialog.asksaveasfilename(
            title="Export CSV",
            defaultextension=".csv",
            initialfile=default_name,
            filetypes=[("CSV files", "*.csv"), ("All files", "*.*")]
        )
        if not path:
            return

        headers = [
            "datetime", "location", "device_sn",
            "model_filter", "ga_usage_filter", "ga_board_filter",
            "symptom", "cause", "try_title",
            "result", "checked_steps", "note"
        ]
        try:
            with open(path, "w", newline="", encoding="utf-8-sig") as f:
                w = csv.DictWriter(f, fieldnames=headers)
                w.writeheader()
                for row in self.logs:
                    w.writerow({h: row.get(h, "") for h in headers})
            messagebox.showinfo(t(self.lang, "done"), t(self.lang, "export_done", path=path))
        except Exception as e:
            messagebox.showerror(t(self.lang, "error"), t(self.lang, "export_fail", err=str(e)))

    # ---------- settings manager (simple) ----------
    def open_manage_settings(self):
        win = tb.Toplevel(self)
        win.title(t(self.lang, "manage_title"))
        win.geometry("760x460")
        win.transient(self)
        win.grab_set()

        left = tb.Labelframe(win, text=t(self.lang, "models_list"), padding=10, bootstyle="secondary")
        left.pack(side="left", fill="both", expand=True, padx=10, pady=10)

        right = tb.Labelframe(win, text=t(self.lang, "boards_list"), padding=10, bootstyle="secondary")
        right.pack(side="left", fill="both", expand=True, padx=10, pady=10)

        model_list = tk.Listbox(left)
        model_list.pack(fill="both", expand=True, padx=8, pady=8)
        for m in sorted_unique(self.settings.get("models", [])):
            model_list.insert(tk.END, m)

        board_list = tk.Listbox(right)
        board_list.pack(fill="both", expand=True, padx=8, pady=8)
        for b in sorted_unique(self.settings.get("ga_board_types", [])):
            board_list.insert(tk.END, b)

        ctrl = tb.Frame(win, padding=10)
        ctrl.pack(fill="x", padx=10, pady=(0, 10))

        model_new = tk.StringVar()
        board_new = tk.StringVar()

        tb.Label(ctrl, text="Model:").grid(row=0, column=0, sticky="w")
        tb.Entry(ctrl, textvariable=model_new, width=20).grid(row=0, column=1, padx=(6, 12))
        tb.Button(ctrl, text=t(self.lang, "add"), bootstyle="primary",
                  command=lambda: self._add_setting_item(model_new, model_list, "models")).grid(row=0, column=2, padx=(0, 12))
        tb.Button(ctrl, text=t(self.lang, "remove_selected"), bootstyle="danger",
                  command=lambda: self._remove_setting_item(model_list, "models")).grid(row=0, column=3, padx=(0, 30))

        tb.Label(ctrl, text="Board:").grid(row=0, column=4, sticky="w")
        tb.Entry(ctrl, textvariable=board_new, width=20).grid(row=0, column=5, padx=(6, 12))
        tb.Button(ctrl, text=t(self.lang, "add"), bootstyle="primary",
                  command=lambda: self._add_setting_item(board_new, board_list, "ga_board_types")).grid(row=0, column=6, padx=(0, 12))
        tb.Button(ctrl, text=t(self.lang, "remove_selected"), bootstyle="danger",
                  command=lambda: self._remove_setting_item(board_list, "ga_board_types")).grid(row=0, column=7)

        tb.Button(ctrl, text=t(self.lang, "close"), bootstyle="secondary", command=win.destroy).grid(row=1, column=7, sticky="e", pady=(10, 0))

    def _sync_setting_listbox(self, listbox, items):
        listbox.delete(0, tk.END)
        for x in sorted_unique(items):
            listbox.insert(tk.END, x)

    def _add_setting_item(self, var, listbox, key):
        value = (var.get() or "").strip()
        if not value:
            return
        cur = self.settings.get(key, [])
        if value in cur:
            messagebox.showinfo(t(self.lang, "info"), t(self.lang, "exists"))
            return
        cur.append(value)
        self.settings[key] = cur
        save_settings(self.settings)
        self._sync_setting_listbox(listbox, cur)
        var.set("")
        self._refresh_filter_lists()
        self.refresh_issue_list()

    def _remove_setting_item(self, listbox, key):
        sel = listbox.curselection()
        if not sel:
            return
        idx = sel[0]
        value = listbox.get(idx)
        if not messagebox.askyesno(t(self.lang, "confirm"), t(self.lang, "delete_q", value=value)):
            return
        cur = [x for x in self.settings.get(key, []) if x != value]
        self.settings[key] = cur
        save_settings(self.settings)
        self._sync_setting_listbox(listbox, cur)
        self._refresh_filter_lists()
        self.refresh_issue_list()

    # ---------- minimal add/delete issue/try ----------
    def open_add_issue_window(self):
        win = tb.Toplevel(self)
        win.title(t(self.lang, "add_issue"))
        win.geometry("860x780")
        win.transient(self)
        win.grab_set()

        if "tags" not in self.settings:
            self.settings["tags"] = []
        if not self.settings["tags"]:
            inferred = collect_tags_from_data(self.data)
            if not inferred:
                inferred = ["GA", "케이블", "캡쳐보드", "영상", "밝기", "모니터", "입력", "전원"]
            self.settings["tags"] = inferred
            save_settings(self.settings)

        tag_items = sorted_unique(self.settings.get("tags", []))
        model_items = ["ANY"] + sorted_unique(self.settings.get("models", []))
        board_items = ["ANY"] + sorted_unique(self.settings.get("ga_board_types", []))

        tb.Label(win, text="Symptom" if self.lang == "en" else "문제 현상(Symptom)").pack(anchor="w", padx=12, pady=(12, 4))
        symptom_var = tk.StringVar()
        tb.Entry(win, textvariable=symptom_var).pack(fill="x", padx=12)

        tb.Label(win, text="Cause" if self.lang == "en" else "가능한 원인(Cause)").pack(anchor="w", padx=12, pady=(12, 4))
        cause_txt = tk.Text(win, height=5, wrap="word")
        cause_txt.pack(fill="x", padx=12)

        ttk.Separator(win).pack(fill="x", padx=12, pady=12)

        tb.Label(win, text="Tags" if self.lang == "en" else "태그(Tags)").pack(anchor="w", padx=12, pady=(0, 4))
        tag_dd = MultiSelectDropdown(win, items=tag_items, selected=[], width=44, allow_any=False)
        tag_dd.pack(fill="x", padx=12)

        add_tag_row = tb.Frame(win)
        add_tag_row.pack(fill="x", padx=12, pady=(6, 0))
        tb.Label(add_tag_row, text="Add tag:" if self.lang == "en" else "태그 추가:").pack(side="left")
        new_tag_var = tk.StringVar()
        tb.Entry(add_tag_row, textvariable=new_tag_var, width=24).pack(side="left", padx=6)

        def add_new_tag():
            v = (new_tag_var.get() or "").strip()
            if not v:
                return
            if v not in self.settings["tags"]:
                self.settings["tags"].append(v)
                self.settings["tags"] = sorted_unique(self.settings["tags"])
                save_settings(self.settings)
            current = tag_dd.get_selected()
            if v not in current:
                current.append(v)
            tag_dd.set_items(sorted_unique(self.settings["tags"]), selected=current)
            new_tag_var.set("")

        tb.Button(add_tag_row, text=t(self.lang, "add"), command=add_new_tag, bootstyle="primary").pack(side="left")

        ttk.Separator(win).pack(fill="x", padx=12, pady=12)

        tb.Label(win, text="Models" if self.lang == "en" else "적용 모델(Models)").pack(anchor="w", padx=12, pady=(0, 4))
        model_dd = MultiSelectDropdown(win, items=model_items, selected=["ANY"], width=44, allow_any=True)
        model_dd.pack(fill="x", padx=12)

        tb.Label(win, text="GA usage (ANY/NO/YES)" if self.lang == "en" else "GA 사용 여부(ANY/NO/YES)").pack(anchor="w", padx=12, pady=(12, 4))
        ga_var = tk.StringVar(value="ANY")
        ga_combo = ttk.Combobox(win, textvariable=ga_var, state="readonly", values=["ANY", "NO", "YES"])
        ga_combo.pack(fill="x", padx=12)

        tb.Label(win, text="GA boards" if self.lang == "en" else "GA 보드 타입(GA boards)").pack(anchor="w", padx=12, pady=(12, 4))
        board_dd = MultiSelectDropdown(win, items=board_items, selected=["ANY"], width=44, allow_any=True)
        board_dd.pack(fill="x", padx=12)

        def on_ga_change(*_):
            if ga_var.get() == "NO":
                board_dd.btn.state(["disabled"])
            else:
                board_dd.btn.state(["!disabled"])

        ga_combo.bind("<<ComboboxSelected>>", on_ga_change)
        on_ga_change()

        ttk.Separator(win).pack(fill="x", padx=12, pady=12)

        tb.Label(win, text="Try 1 title (optional)" if self.lang == "en" else "해결책 1 제목(Try 1) (선택)").pack(anchor="w", padx=12)
        sol_title_var = tk.StringVar(value="Try 1:")
        tb.Entry(win, textvariable=sol_title_var).pack(fill="x", padx=12, pady=(4, 10))

        tb.Label(win, text="Steps (one line = one step) (optional)" if self.lang == "en" else "해결 단계(한 줄=한 단계, 선택)").pack(anchor="w", padx=12)
        steps_txt = tk.Text(win, height=10, wrap="word")
        steps_txt.pack(fill="both", expand=True, padx=12, pady=(4, 10))

        btns = tb.Frame(win)
        btns.pack(fill="x", padx=12, pady=12)

        def on_add():
            symptom = (symptom_var.get() or "").strip()
            if not symptom:
                messagebox.showwarning(t(self.lang, "required"), t(self.lang, "cannot_empty_symptom"))
                return

            tags = tag_dd.get_selected()
            models = model_dd.get_selected() or ["ANY"]
            boards = board_dd.get_selected() or ["ANY"]

            item = {
                "symptom": symptom,
                "cause": cause_txt.get("1.0", tk.END).strip(),
                "tags": tags,
                "applicability": {"models": models, "ga_usage": ga_var.get(), "ga_board_types": boards},
                "solutions": []
            }

            steps = [ln.strip() for ln in steps_txt.get("1.0", tk.END).splitlines() if ln.strip()]
            if steps:
                item["solutions"].append({
                    "title": sol_title_var.get().strip() or "Try 1",
                    "icon_path": "",
                    "status": "unknown",
                    "steps": [{"text": s, "done": False, "image_path": ""} for s in steps]
                })

            self.data.append(item)
            save_data(self.data)

            self.refresh_issue_list()

            new_index = len(self.data) - 1
            if new_index in self.filtered_indices:
                pos = self.filtered_indices.index(new_index)
                self.issue_listbox.selection_clear(0, tk.END)
                self.issue_listbox.selection_set(pos)
                self.issue_listbox.see(pos)
                self.selected_issue_index = new_index
                self.render_issue()

            win.destroy()

        tb.Button(btns, text=t(self.lang, "add"), command=on_add, bootstyle="primary").pack(side="left")
        tb.Button(btns, text=t(self.lang, "cancel"), command=win.destroy, bootstyle="secondary").pack(side="left", padx=8)

    def open_add_solution_window(self):
        if self.selected_issue_index is None:
            messagebox.showinfo(t(self.lang, "info"), t(self.lang, "select_issue_first"))
            return

        item = self.data[self.selected_issue_index]
        next_try = len(item.get("solutions", [])) + 1

        win = tb.Toplevel(self)
        win.title(t(self.lang, "add_try"))
        win.geometry("680x560")
        win.transient(self)
        win.grab_set()

        tb.Label(win, text="Try title" if self.lang == "en" else "해결책 제목").pack(anchor="w", padx=12, pady=(12, 4))
        title_var = tk.StringVar(value=f"Try {next_try}:")
        tb.Entry(win, textvariable=title_var).pack(fill="x", padx=12)

        tb.Label(win, text="Steps (one line = one step)" if self.lang == "en" else "해결 단계(한 줄=한 단계)").pack(anchor="w", padx=12, pady=(12, 4))
        steps_txt = tk.Text(win, height=18, wrap="word")
        steps_txt.pack(fill="both", expand=True, padx=12)

        btns = tb.Frame(win)
        btns.pack(fill="x", padx=12, pady=12)

        def on_add():
            steps = [ln.strip() for ln in steps_txt.get("1.0", tk.END).splitlines() if ln.strip()]
            if not steps:
                messagebox.showwarning(t(self.lang, "required"), "Steps required." if self.lang == "en" else "단계가 최소 1개는 필요해요.")
                return

            item.setdefault("solutions", []).append({
                "title": title_var.get().strip() or f"Try {next_try}",
                "icon_path": "",
                "status": "unknown",
                "steps": [{"text": s, "done": False, "image_path": ""} for s in steps]
            })
            save_data(self.data)

            self.render_issue()
            new_sol_idx = len(item["solutions"]) - 1
            self.solution_combo.current(new_sol_idx)
            self.selected_solution_index = new_sol_idx
            self.render_solution()

            win.destroy()

        tb.Button(btns, text=t(self.lang, "add"), command=on_add, bootstyle="primary").pack(side="left")
        tb.Button(btns, text=t(self.lang, "cancel"), command=win.destroy, bootstyle="secondary").pack(side="left", padx=8)

    def delete_issue(self):
        if self.selected_issue_index is None:
            messagebox.showinfo(t(self.lang, "info"), t(self.lang, "select_issue_first"))
            return
        item = self.data[self.selected_issue_index]
        if not messagebox.askyesno(t(self.lang, "confirm"), t(self.lang, "deleted_issue_q", symptom=item.get("symptom", ""))):
            return
        del self.data[self.selected_issue_index]
        save_data(self.data)
        self.refresh_issue_list()
        self.clear_detail()

    def delete_solution(self):
        if self.selected_issue_index is None or self.selected_solution_index is None:
            messagebox.showinfo(t(self.lang, "info"), t(self.lang, "select_try_first"))
            return
        item = self.data[self.selected_issue_index]
        sol = item["solutions"][self.selected_solution_index]
        if not messagebox.askyesno(t(self.lang, "confirm"), t(self.lang, "deleted_try_q", title=sol.get("title", ""))):
            return
        del item["solutions"][self.selected_solution_index]
        save_data(self.data)
        self.render_issue()

class MainMenu(tb.Window):
    def __init__(self):
        super().__init__(themename="flatly")  # 추천: flatly / cosmo / litera / darkly
        self.title("Endoscope Service Assistant")
        self.geometry("520x260")
        self.minsize(480, 220)

        root = tb.Frame(self, padding=18)
        root.pack(fill="both", expand=True)

        tb.Label(root, text="Endoscope Service Assistant", font=("Segoe UI", 16, "bold")).pack(anchor="w", pady=(0, 12))
        tb.Label(root, text="원하는 기능을 선택하세요.").pack(anchor="w", pady=(0, 16))

        btns = tb.Frame(root)
        btns.pack(fill="x")

        tb.Button(btns, text="설치 (TODO)", bootstyle="secondary").pack(fill="x", pady=6)
        tb.Button(btns, text="운영 (TODO)", bootstyle="secondary").pack(fill="x", pady=6)
        tb.Button(btns, text="트러블슈팅", bootstyle="primary", command=self.open_troubleshooting).pack(fill="x", pady=6)

        tb.Label(root, text="※ 설치/운영은 추후 개발 예정입니다.").pack(anchor="w", pady=(14, 0))

        self.troubleshooter_win = None

    def open_troubleshooting(self):
        if self.troubleshooter_win is not None and self.troubleshooter_win.winfo_exists():
            self.troubleshooter_win.lift()
            self.troubleshooter_win.focus_force()
            return

        self.troubleshooter_win = TroubleshooterV6(master=self)
        self.troubleshooter_win.title(t(getattr(self.troubleshooter_win, "lang", "ko"), "app_title"))
        self.troubleshooter_win.protocol("WM_DELETE_WINDOW", self._close_troubleshooter)

    def _close_troubleshooter(self):
        if self.troubleshooter_win is not None and self.troubleshooter_win.winfo_exists():
            self.troubleshooter_win.destroy()
        self.troubleshooter_win = None

if __name__ == "__main__":
    app = MainMenu()
    app.mainloop()
