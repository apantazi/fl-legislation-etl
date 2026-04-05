import os
import zipfile
import pandas as pd
import random
import time
from playwright.sync_api import sync_playwright

# --- CONFIG ---
EMAIL = "andrew.pantazi@gmail.com"
PASSWORD = "hockey11"
SPREADSHEET = "C:/Users/Andrew/Documents/fl-legislation/fl-legislation-etl-/data-raw/daves/DRA_plans_filtered.csv"
URL_COLUMN = "url"
NAME_COLUMN = "filename"
OUTPUT_DIR = "downloads"
USER_DATA_DIR = "browser_profile"
# --------------

os.makedirs(OUTPUT_DIR, exist_ok=True)
df = pd.read_csv(SPREADSHEET)

with sync_playwright() as p:
    context = p.chromium.launch_persistent_context(
        USER_DATA_DIR,
        headless=False,
        args=[
            "--disable-blink-features=AutomationControlled",
            "--hide-crash-restore-bubble",
        ],
    )
    page = context.new_page()

    # --- STEP 1: LOGIN ---
    print("Navigating to DRA...")
    page.goto("https://davesredistricting.org/maps#home")

    try:
        if not page.get_by_role("button", name="Log Out").is_visible(timeout=5000):
            print("Logging in...")
            page.get_by_role("button", name="Log In").click()
            page.get_by_role("textbox", name="Email").fill(EMAIL)
            page.get_by_role("textbox", name="Password").fill(PASSWORD)
            page.locator("#homepageTop").get_by_role("button", name="Log In").click()
            page.wait_for_selector("text=Log Out", timeout=15000)
            print("Login successful.")
    except:
        print("Continuing (assuming already logged in)...")

    # --- STEP 2: LOOP THROUGH CSV ---
    for index, row in df.iterrows():
        url = row[URL_COLUMN]
        output_name = str(row[NAME_COLUMN]).strip()
        if not output_name.endswith(".csv"):
            output_name += ".csv"

        save_path = os.path.join(OUTPUT_DIR, output_name)
        if os.path.exists(save_path):
            print(f"Skipping (already exists): {output_name}")
            continue

        try:
            print(f"\nProcessing {index+1}/{len(df)}: {output_name}")
            page.goto(url)
            page.wait_for_load_state("networkidle")
            # Give the app time to fully hydrate the map and state context
            time.sleep(4)

            # --- STEP 3: CONFIGURE DATASETS ---
            print("  Opening Settings...")
            page.get_by_role("button", name="Settings").click()
            time.sleep(2)

            # Go straight to "Choose Datasets" — do NOT click "Data Selector"
            # (clicking it can reset the state dropdown to blank)
            choose_btn = page.get_by_text("Choose Datasets")
            choose_btn.wait_for(state="visible", timeout=10000)
            choose_btn.click()

            # Wait for the dropdown options to appear
            print("  Selecting all available datasets...")
            options = page.get_by_role("option")
            options.first.wait_for(state="visible", timeout=10000)

            # Select every option that isn't already selected
            count = options.count()
            for i in range(count):
                opt = options.nth(i)
                if opt.get_attribute("aria-selected") == "false":
                    opt.click()
                    time.sleep(0.2)  # small delay between clicks for stability

            # Close the dropdown and apply
            page.locator("#menu- div").first.click()
            time.sleep(0.5)
            page.get_by_role("button", name="Apply").click()

            # Allow time for the map to recalculate with new data
            page.wait_for_load_state("networkidle")
            time.sleep(3)

            # --- STEP 4: EXPORT ---
            print("  Triggering Export...")
            export_toolbar_btn = page.get_by_role("button", name="Export")
            export_toolbar_btn.wait_for(state="visible", timeout=60000)
            export_toolbar_btn.click()

            # Select CSV Radio
            radio = page.get_by_role("radio", name="District Data (as .csv)")
            radio.wait_for(state="visible")
            radio.check()

            # Handle the actual download event
            with page.expect_download(timeout=90000) as download_info:
                time.sleep(1)
                # .last ensures we click the 'Export' button in the popup, not the toolbar
                page.get_by_role("button", name="Export").last.click()

            download = download_info.value
            current_temp_zip = os.path.join(OUTPUT_DIR, f"temp_{index}.zip")
            download.save_as(current_temp_zip)

            # --- STEP 5: EXTRACT AND CLEANUP ---
            with zipfile.ZipFile(current_temp_zip, "r") as z:
                csv_in_zip = [f for f in z.namelist() if f.endswith(".csv")][0]
                with z.open(csv_in_zip) as csv_file:
                    with open(save_path, "wb") as out_file:
                        out_file.write(csv_file.read())

            if os.path.exists(current_temp_zip):
                os.remove(current_temp_zip)

            print(f"  SUCCESS: {output_name}")

            # Anti-throttle delay
            time.sleep(random.uniform(3, 6))

        except Exception as e:
            print(f"  ERROR on {output_name}: {e}")
            time.sleep(10)

    context.close()
    print("\nBatch process complete.")