#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path

LOW_SIGNAL_NAMES = {
    "<deduplicated_symbol>",
    "start",
    "NSApplicationMain",
    "__CFRunLoopRun",
    "_CFRunLoopRunSpecificWithOptions",
}


FRAMEWORK_BRIDGE_LABELS = (
    (
        "[SwiftUI/AppKit layout bridge]",
        (
            "nshostingview",
            "viewgraph",
            "graphhost",
            "displaylist.viewupdater",
            "layoutenginebox",
            "viewlayoutengine",
            "unarylayoutengine",
            "layoutproxy",
            "stacklayout",
            "layoutsubview.place",
            "_framelayout",
            "_paddinglayout",
            "viewrendererhost",
        ),
    ),
    (
        "[Core Animation bridge]",
        (
            "ca::transaction",
            "ca::layer",
            "calayer",
            "cgdrawinglayer",
            "cabackingstore",
            "platformdrawablecontent.draw",
            "rb::displaylist",
        ),
    ),
)


@dataclass(frozen=True)
class Frame:
    name: str
    binary_name: str
    binary_path: str
    module: str

    @property
    def key(self) -> tuple[str, str, str]:
        return (self.name, self.binary_name, self.module)


@dataclass(frozen=True)
class FeatureGroup:
    key: str
    title: str
    patterns: tuple[str, ...]


FEATURE_GROUPS = (
    FeatureGroup(
        key="dashboard-layout",
        title="Dashboard Layout",
        patterns=(
            "dashboardlayout",
            "dashboardview.body",
        ),
    ),
    FeatureGroup(
        key="metric-tile-text-layout",
        title="Metric Tile Text & Layout",
        patterns=(
            "metrictileview",
            "monitortileview",
            "styledtextlayoutengine",
            "resolvedstyledtext",
            "resolvedtext",
            "text.resolve",
            "text.style.nsattributes",
            "nsattributedstring.metricscache",
            "__nsstringdrawingengine",
            "nscoretypesetter",
        ),
    ),
    FeatureGroup(
        key="ring-gauge",
        title="Ring Gauge",
        patterns=(
            "ringgauge",
        ),
    ),
    FeatureGroup(
        key="sparkline",
        title="Sparkline",
        patterns=(
            "sparkline",
        ),
    ),
    FeatureGroup(
        key="polling-services",
        title="Polling Services & Batching",
        patterns=(
            "monitorservice.poll",
            "pollingmonitorbase",
            "pollingcadence",
            "dashboardupdatebatcher",
            "monitorviewmodelbase",
        ),
    ),
)


FEATURE_GROUPS_BY_KEY = {group.key: group for group in FEATURE_GROUPS}
FEATURE_GROUP_ORDER = {group.key: index for index, group in enumerate(FEATURE_GROUPS)}


def run_xctrace(args: list[str]) -> str:
    result = subprocess.run(args + ["--quiet"], capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(result.stderr.strip() or result.stdout.strip() or f"Command failed: {' '.join(args)}")
    return result.stdout


def human_ns(value: int) -> str:
    if value >= 1_000_000_000:
        return f"{value / 1_000_000_000:.2f} s"
    if value >= 1_000_000:
        return f"{value / 1_000_000:.2f} ms"
    if value >= 1_000:
        return f"{value / 1_000:.2f} us"
    return f"{value} ns"


def pct(value: int, total: int) -> str:
    if total <= 0:
        return "0.0%"
    return f"{(value / total) * 100:.1f}%"


def matches_patterns(name: str, patterns: tuple[str, ...]) -> bool:
    lowered = name.casefold()
    return any(pattern in lowered for pattern in patterns)


def classify_module(binary_name: str, binary_path: str, focus_process: str) -> str:
    if focus_process and (binary_name == focus_process or focus_process in binary_path or focus_process in binary_name):
        return "app"
    if binary_name in {"SwiftUI", "SwiftUICore", "AttributeGraph"}:
        return "swiftui"
    if binary_name == "AppKit":
        return "appkit"
    if binary_name in {"QuartzCore", "CoreAnimation"}:
        return "core-animation"
    if binary_name in {"CoreGraphics", "CoreText", "TextInputCore"}:
        return "graphics"
    if binary_path.startswith("/System/") or binary_path.startswith("/usr/lib"):
        return "system"
    return binary_name or "unknown"


def parse_toc(trace_path: Path) -> dict[str, str]:
    root = ET.fromstring(run_xctrace(["xcrun", "xctrace", "export", "--input", str(trace_path), "--toc"]))
    runs = root.findall("run")
    if not runs:
        raise SystemExit("No runs found in trace")
    latest = runs[-1]
    target_process = latest.find("./info/target/process")
    summary = latest.find("./info/summary")
    return {
        "run_number": latest.attrib.get("number", "1"),
        "process_name": target_process.attrib.get("name", "unknown") if target_process is not None else "unknown",
        "pid": target_process.attrib.get("pid", "") if target_process is not None else "",
        "duration": summary.findtext("duration", default="") if summary is not None else "",
        "template_name": summary.findtext("template-name", default="") if summary is not None else "",
        "end_reason": summary.findtext("end-reason", default="") if summary is not None else "",
    }


def resolve_binary(binary_node: ET.Element | None, binary_lookup: dict[str, tuple[str, str]]) -> tuple[str, str]:
    if binary_node is None:
        return ("unknown", "")
    if "ref" in binary_node.attrib:
        return binary_lookup.get(binary_node.attrib["ref"], ("unknown", ""))
    info = (binary_node.attrib.get("name", "unknown"), binary_node.attrib.get("path", ""))
    if "id" in binary_node.attrib:
        binary_lookup[binary_node.attrib["id"]] = info
    return info


def collapse_frames(frames: list[Frame]) -> list[Frame]:
    collapsed: list[Frame] = []
    for frame in frames:
        if not collapsed or collapsed[-1].key != frame.key:
            collapsed.append(frame)
    return collapsed


def is_low_signal(name: str) -> bool:
    return name in LOW_SIGNAL_NAMES or name.startswith("0x")


def bridge_label(name: str) -> str | None:
    lowered = name.casefold()
    for label, patterns in FRAMEWORK_BRIDGE_LABELS:
        if any(pattern in lowered for pattern in patterns):
            return label
    return None


def trimmed_path(path: list[Frame], focus_index: int) -> tuple[str, ...]:
    start = max(0, focus_index - 4)
    end = min(len(path), focus_index + 5)
    names: list[str] = []
    for index in range(start, end):
        name = path[index].name
        if index != focus_index and is_low_signal(name):
            continue
        if index != focus_index:
            collapsed_name = bridge_label(name)
            if collapsed_name is not None:
                name = collapsed_name
        if not names or names[-1] != name:
            names.append(name)
    return tuple(names)


def feature_match_indices(path: list[Frame]) -> dict[str, int]:
    matches: dict[str, int] = {}
    for group in FEATURE_GROUPS:
        deepest_index: int | None = None
        for index, frame in enumerate(path):
            if matches_patterns(frame.name, group.patterns):
                deepest_index = index
        if deepest_index is not None:
            matches[group.key] = deepest_index
    return matches


def load_samples(trace_path: Path, run_number: str, focus_process: str) -> tuple[list[tuple[int, str, list[Frame]]], dict[str, str]]:
    xpath = f'/trace-toc/run[@number="{run_number}"]/data/table[@schema="time-profile"]'
    root = ET.fromstring(run_xctrace(["xcrun", "xctrace", "export", "--input", str(trace_path), "--xpath", xpath]))
    node = root.find("node")
    if node is None:
        raise SystemExit("Could not export the time-profile table")

    frame_lookup: dict[str, Frame] = {}
    binary_lookup: dict[str, tuple[str, str]] = {}
    samples: list[tuple[int, str, list[Frame]]] = []

    for row in node.findall("row"):
        weight_node = row.find("weight")
        thread_node = row.find("thread")
        backtrace_node = row.find("backtrace")
        if weight_node is None or thread_node is None or backtrace_node is None:
            continue
        weight_value = int(weight_node.text or "0")
        if weight_value <= 0:
            continue

        frames: list[Frame] = []
        for frame_node in backtrace_node.findall("frame"):
            if "ref" in frame_node.attrib:
                frame = frame_lookup.get(frame_node.attrib["ref"])
                if frame is not None:
                    frames.append(frame)
                continue

            binary_name, binary_path = resolve_binary(frame_node.find("binary"), binary_lookup)
            frame = Frame(
                name=frame_node.attrib.get("name", "unknown"),
                binary_name=binary_name,
                binary_path=binary_path,
                module=classify_module(binary_name, binary_path, focus_process),
            )
            if "id" in frame_node.attrib:
                frame_lookup[frame_node.attrib["id"]] = frame
            frames.append(frame)

        if not frames:
            continue
        samples.append((weight_value, thread_node.attrib.get("fmt", "unknown thread"), collapse_frames(frames)))

    # On macOS 26 / Instruments 26, Time Profiler uses deferred recording mode.
    # The aggregated time-profile call tree is only computed when the trace is
    # opened in Instruments.app and is not written to disk for xctrace export.
    # Count raw time-sample rows whenever the symbolicated table looks sparse so
    # the caller can emit a useful diagnostic.
    raw_count = 0
    if len(samples) < 20:
        raw_xpath = f'/trace-toc/run[@number="{run_number}"]/data/table[@schema="time-sample"]'
        try:
            raw_root = ET.fromstring(
                run_xctrace(["xcrun", "xctrace", "export", "--input", str(trace_path), "--xpath", raw_xpath])
            )
            raw_count = len(raw_root.findall(".//row"))
        except Exception:
            pass

    return samples, {"row_count": str(len(samples)), "raw_sample_count": str(raw_count)}


def render_summary(trace_path: Path, toc: dict[str, str], samples: list[tuple[int, str, list[Frame]]], top_frames: int) -> str:
    total_ns = sum(weight for weight, _, _ in samples)
    process_suffix = f" (pid {toc['pid']})" if toc["pid"] else ""
    thread_totals: Counter[str] = Counter()
    inclusive: Counter[tuple[str, str, str]] = Counter()
    self_time: Counter[tuple[str, str, str]] = Counter()
    frame_details: dict[tuple[str, str, str], Frame] = {}
    path_counter: dict[tuple[str, str, str], Counter[tuple[str, ...]]] = defaultdict(Counter)
    child_counter: dict[tuple[str, str, str], Counter[str]] = defaultdict(Counter)
    feature_totals: Counter[str] = Counter()
    feature_primary_symbols: dict[str, Counter[str]] = defaultdict(Counter)
    feature_dominant_symbols: dict[str, Counter[str]] = defaultdict(Counter)
    feature_paths: dict[str, Counter[tuple[str, ...]]] = defaultdict(Counter)

    for weight, thread_name, leaf_to_root in samples:
        thread_totals[thread_name] += weight
        path = list(reversed(leaf_to_root))
        seen: set[tuple[str, str, str]] = set()
        matched_features = feature_match_indices(path)

        if matched_features:
            primary_feature_key, primary_feature_index = max(
                matched_features.items(),
                key=lambda item: (item[1], -FEATURE_GROUP_ORDER[item[0]]),
            )
            feature_totals[primary_feature_key] += weight
            feature_primary_symbols[primary_feature_key][path[primary_feature_index].name] += weight
            feature_paths[primary_feature_key][trimmed_path(path, primary_feature_index)] += weight
            primary_feature = FEATURE_GROUPS_BY_KEY[primary_feature_key]
            for frame in path:
                if matches_patterns(frame.name, primary_feature.patterns):
                    feature_dominant_symbols[primary_feature_key][frame.name] += weight

        for index, frame in enumerate(path):
            key = frame.key
            frame_details[key] = frame
            if key not in seen:
                inclusive[key] += weight
                path_counter[key][trimmed_path(path, index)] += weight
                seen.add(key)
            if index + 1 < len(path):
                child_counter[key][path[index + 1].name] += weight

        self_frame = leaf_to_root[0]
        self_time[self_frame.key] += weight

    ranked = sorted(inclusive.items(), key=lambda item: (-item[1], item[0][0]))
    app_ranked = [item for item in ranked if frame_details[item[0]].module == "app"]
    hotspot_rows = app_ranked[:top_frames] or ranked[:top_frames]

    lines = [
        "# Instruments Time Profiler Summary",
        "",
        f"- trace: {trace_path}",
        f"- run: {toc['run_number']}",
        f"- template: {toc['template_name'] or 'Time Profiler'}",
        f"- process: {toc['process_name']}{process_suffix}",
        f"- duration: {toc['duration']} s" if toc["duration"] else "- duration: unknown",
        f"- total sampled time: {human_ns(total_ns)}",
    ]
    if toc["end_reason"]:
        lines.append(f"- end reason: {toc['end_reason']}")

    lines.extend(["", "## Top Threads", ""])
    for index, (thread_name, ns) in enumerate(thread_totals.most_common(6), start=1):
        lines.append(f"{index}. {thread_name} — {human_ns(ns)} ({pct(ns, total_ns)})")

    if feature_totals:
        attributed_ns = sum(feature_totals.values())
        lines.extend([
            "",
            "## Top Feature Groups",
            "",
            f"- attribution rule: each sample is assigned to the deepest matching feature in its call path",
            f"- attributed sampled time: {human_ns(attributed_ns)} ({pct(attributed_ns, total_ns)})",
            "",
        ])
        for index, (feature_key, ns) in enumerate(feature_totals.most_common(), start=1):
            group = FEATURE_GROUPS_BY_KEY[feature_key]
            representative_symbol = ""
            if feature_primary_symbols[feature_key]:
                representative_symbol = max(feature_primary_symbols[feature_key].items(), key=lambda item: item[1])[0]
            representative_path: tuple[str, ...] = ()
            if feature_paths[feature_key]:
                representative_path = max(feature_paths[feature_key].items(), key=lambda item: item[1])[0]
            dominant_symbols = ", ".join(name for name, _ in feature_dominant_symbols[feature_key].most_common(3))
            lines.append(f"{index}. {group.title}")
            lines.append(f"   attributed: {human_ns(ns)} ({pct(ns, total_ns)})")
            if representative_symbol:
                lines.append(f"   representative symbol: {representative_symbol}")
            if representative_path:
                lines.append(f"   path: {' > '.join(representative_path)}")
            if dominant_symbols:
                lines.append(f"   dominant symbols: {dominant_symbols}")
            lines.append("")

    section_title = "Top App Hotspots" if app_ranked else "Top Hotspots"
    lines.extend(["", f"## {section_title}", ""])
    for index, (key, ns) in enumerate(hotspot_rows, start=1):
        frame = frame_details[key]
        representative_path = ()
        if path_counter[key]:
            representative_path = max(path_counter[key].items(), key=lambda item: item[1])[0]
        dominant_children = ", ".join(name for name, _ in child_counter[key].most_common(3))
        lines.append(f"{index}. {frame.name}")
        lines.append(f"   module: {frame.module}")
        lines.append(f"   binary: {frame.binary_name}")
        lines.append(f"   inclusive: {human_ns(ns)} ({pct(ns, total_ns)})")
        lines.append(f"   self: {human_ns(self_time[key])} ({pct(self_time[key], total_ns)})")
        if representative_path:
            lines.append(f"   path: {' > '.join(representative_path)}")
        if dominant_children:
            lines.append(f"   dominant children: {dominant_children}")
        lines.append("")

    if app_ranked:
        lines.extend(["## Top Overall Hotspots", ""])
        for index, (key, ns) in enumerate(ranked[: min(8, top_frames)], start=1):
            frame = frame_details[key]
            lines.append(f"{index}. {frame.name} [{frame.module}] — {human_ns(ns)} ({pct(ns, total_ns)})")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Summarize an Instruments Time Profiler trace")
    parser.add_argument("trace_path", type=Path)
    parser.add_argument("--focus-process", default="")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--run-number")
    parser.add_argument("--top-frames", type=int, default=12)
    args = parser.parse_args()

    toc = parse_toc(args.trace_path)
    run_number = args.run_number or toc["run_number"]
    focus_process = args.focus_process or toc["process_name"]
    samples, meta = load_samples(args.trace_path, run_number, focus_process)
    raw_count = int(meta.get("raw_sample_count", "0"))

    if not samples:
        if raw_count > 0:
            raise SystemExit(
                f"No time-profile samples were exported from the trace "
                f"({raw_count} raw stackshots found in time-sample schema).\n"
                f"On macOS 26 / Instruments 26, Time Profiler deferred recording mode stores "
                f"raw PC addresses that are only symbolicated when the trace is opened in "
                f"Instruments.app. Open {args.trace_path} in Instruments.app to view the "
                f"symbolicated call tree."
            )
        raise SystemExit("No time-profile samples were exported from the trace")

    summary = render_summary(args.trace_path, {**toc, "run_number": run_number, "process_name": focus_process}, samples, args.top_frames)

    # Warn when the time-profile table is nearly empty relative to raw stackshots.
    # This happens on macOS 26 with deferred Time Profiler recording: the export
    # only returns early-startup dyld frames while the real 1ms-interval samples
    # live unsymbolicated in the time-sample schema.
    if raw_count > len(samples) * 10:
        warning = (
            f"\n> **macOS 26 deferred-mode note**: the time-profile export contains only "
            f"{len(samples)} sample(s) but {raw_count} raw stackshots were recorded in the "
            f"time-sample schema. The summary above reflects only early dyld startup activity. "
            f"Open `{args.trace_path}` in Instruments.app for the full symbolicated call tree.\n"
        )
        summary = summary.rstrip() + "\n" + warning

    if args.output:
        args.output.write_text(summary, encoding="utf-8")
    sys.stdout.write(summary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())