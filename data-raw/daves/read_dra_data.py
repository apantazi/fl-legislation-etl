#!/usr/bin/env python3
"""Download DRA `districtData` CSV exports for plans in DRA_plans.csv.

This script automates the same export path used in the DRA UI:
  1) open map URL (`/maps#viewmap::<plan_id>`)
  2) open Export dialog
  3) choose "District Data (as .csv)"
  4) click Export and save the downloaded file

Because DRA is a browser app and some environments block direct HTTP access,
this script runs in Playwright.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path
from typing import Dict, List

from playwright.sync_api import BrowserContext, Page, TimeoutError, sync_playwright


def read_plans(plans_csv: Path, limit: int | None = None) -> List[Dict[str, str]]:
    with plans_csv.open(newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    if limit is not None:
        rows = rows[:limit]
    return rows


def safe_name(value: str) -> str:
    value = re.sub(r"[^A-Za-z0-9_.-]+", "_", value.strip())
    return value.strip("_") or "plan"


def accept_terms_if_present(page: Page) -> None:
    # Terms dialog occasionally appears on first page load.
    if page.locator("text=I agree to the Terms of Use and Privacy Policy.").count() > 0:
        try:
            page.click("text=I agree to the Terms of Use and Privacy Policy.", timeout=3_000)
            page.click("button:has-text('ACCEPT')", timeout=3_000)
            page.wait_for_timeout(1000)
        except Exception:
            # If interaction races with dialog closing/opening, continue best-effort.
            pass


def open_export_dialog(page: Page) -> None:
    # Try multiple selectors; DRA UI can vary by state/view mode.
    candidates = [
        "button:has-text('Export')",
        "[aria-label*='Export']",
        "text=Export Map to a File",
    ]

    for selector in candidates:
        try:
            if page.locator(selector).count() > 0:
                page.locator(selector).first.click(timeout=2_500)
                page.wait_for_timeout(400)
                if page.locator("text=Export Map to a File").count() > 0:
                    return
        except Exception:
            continue

    # Last-ditch: attempt keyboard shortcuts often used by web apps.
    for key in ["e", "Control+e", "Meta+e"]:
        try:
            page.keyboard.press(key)
            page.wait_for_timeout(300)
            if page.locator("text=Export Map to a File").count() > 0:
                return
        except Exception:
            continue

    raise RuntimeError("Could not open Export dialog")


def export_district_data_csv(context: BrowserContext, page: Page, save_to: Path) -> None:
    open_export_dialog(page)

    # Select districtData option in dialog.
    option_selectors = [
        "text=District Data",
        "text=District\u00a0Data",
        "text=(as .csv)",
    ]

    clicked = False
    for selector in option_selectors:
        try:
            loc = page.locator(selector)
            if loc.count() > 0:
                loc.first.click(timeout=2_500)
                clicked = True
                break
        except Exception:
            continue

    if not clicked:
        raise RuntimeError("Could not select District Data option in Export dialog")

    with page.expect_download(timeout=30_000) as dl_info:
        # Prefer button role text first; fallback on literal text selector.
        try:
            page.get_by_role("button", name="Export").click(timeout=2_500)
        except Exception:
            page.click("button:has-text('Export')", timeout=2_500)

    download = dl_info.value
    save_to.parent.mkdir(parents=True, exist_ok=True)
    download.save_as(str(save_to))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--plans-csv", default="DRA_plans.csv")
    parser.add_argument("--output-dir", default="districtData_csv")
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--headful", action="store_true", help="Run browser in headed mode")
    parser.add_argument(
        "--state-filter",
        default=None,
        help="Optional two-letter state code filter (e.g., FL)",
    )
    args = parser.parse_args()

    plans = read_plans(Path(args.plans_csv), limit=args.limit)
    if args.state_filter:
        plans = [p for p in plans if p.get("stateCode") == args.state_filter]

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    results: List[Dict[str, str]] = []

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=not args.headful)
        context = browser.new_context(accept_downloads=True)
        page = context.new_page()

        # Prime session/cookies.
        page.goto("https://davesredistricting.org/maps", wait_until="domcontentloaded", timeout=60_000)
        accept_terms_if_present(page)

        for idx, plan in enumerate(plans, start=1):
            plan_id = (plan.get("id") or "").strip()
            title = (plan.get("title") or plan_id).strip()

            if not plan_id:
                results.append({"plan_id": "", "status": "skip", "reason": "missing plan id"})
                continue

            print(f"[{idx}/{len(plans)}] {plan_id} :: {title}")
            map_url = f"https://davesredistricting.org/maps#viewmap::{plan_id}"

            try:
                page.goto(map_url, wait_until="domcontentloaded", timeout=60_000)
                page.wait_for_timeout(2500)
                accept_terms_if_present(page)

                fname = f"{safe_name(plan.get('stateCode','XX'))}_{safe_name(plan.get('year','year'))}_{safe_name(plan.get('planType','type'))}_{plan_id}_districtData.csv"
                save_to = output_dir / fname

                export_district_data_csv(context, page, save_to)

                results.append({
                    "plan_id": plan_id,
                    "status": "ok",
                    "file": str(save_to),
                    "stateCode": plan.get("stateCode", ""),
                    "year": plan.get("year", ""),
                    "planType": plan.get("planType", ""),
                })
            except TimeoutError:
                results.append({"plan_id": plan_id, "status": "error", "reason": "timeout"})
            except Exception as e:
                results.append({"plan_id": plan_id, "status": "error", "reason": str(e)})

        context.close()
        browser.close()

    results_path = output_dir / "download_results.json"
    with results_path.open("w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)

    ok = sum(1 for r in results if r.get("status") == "ok")
    err = sum(1 for r in results if r.get("status") == "error")
    print(f"Done. ok={ok}, error={err}, results={results_path}")


if __name__ == "__main__":
    main()
