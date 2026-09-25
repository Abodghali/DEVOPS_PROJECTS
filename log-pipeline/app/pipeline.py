"""Validate JSONL events and atomically publish a daily traffic report."""
import argparse
import collections
import json
import os
from pathlib import Path
import tempfile


def aggregate(lines):
    counts = collections.Counter()
    rejected = []
    accepted = 0
    for number, line in enumerate(lines, 1):
        try:
            event = json.loads(line)
            if not isinstance(event, dict):
                raise ValueError("event must be an object")
            status = event.get("status")
            duration = event.get("duration_ms")
            if type(status) is not int or not 100 <= status <= 599:
                raise ValueError("invalid status")
            if type(duration) is not int or not 0 <= duration <= 3600000:
                raise ValueError("invalid duration")
            accepted += 1
            counts[f"{status // 100}xx"] += 1
            counts["total_duration_ms"] += duration
        except (ValueError, TypeError) as exc:
            # Keep only location and reason; never copy raw logs containing secrets.
            rejected.append({"line": number, "reason": str(exc)[:100]})
    return {"accepted": accepted, "rejected": len(rejected), "status_counts": {
        key: counts[key] for key in ("1xx", "2xx", "3xx", "4xx", "5xx")},
        "average_duration_ms": round(counts["total_duration_ms"] / accepted, 2) if accepted else 0,
        "rejections": rejected}


def run(source, destination):
    source, destination = Path(source), Path(destination)
    with source.open(encoding="utf-8") as stream:
        report = aggregate(stream)
    if report["accepted"] == 0:
        raise ValueError("No valid events; previous report preserved")
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Temporary output on the same filesystem makes replacement atomic.
    fd, temp = tempfile.mkstemp(dir=destination.parent, prefix=".report-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(report, stream, indent=2)
            stream.write("\n")
        os.replace(temp, destination)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", default="/input/events.jsonl")
    parser.add_argument("--output", default="/output/report.json")
    args = parser.parse_args()
    result = run(args.input, args.output)
    print(json.dumps({"accepted": result["accepted"], "rejected": result["rejected"]}))
