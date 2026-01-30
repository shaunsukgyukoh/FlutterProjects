import json

INPUT = "assets/data/troubles_v1.json"
OUTPUT = "troubles_v1_with_id.json"

with open(INPUT, "r", encoding="utf-8") as f:
    data = json.load(f)

for i, item in enumerate(data, start=1):
    item["id"] = f"T{i:04d}"   # T0001, T0002, ...

with open(OUTPUT, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("✅ id added:", OUTPUT)