from playwright.sync_api import sync_playwright
from bs4 import BeautifulSoup
import pandas as pd
import re
import time

def scrape_house(page):
    print("Scraping House...")
    page.goto("https://www.flhouse.gov/representatives")
    page.wait_for_selector('.team-box')
    html_content = page.content()
    doc = BeautifulSoup(html_content, "html.parser")
    legislators = doc.find_all(class_='team-box')

    all_data = []
    for legislator in legislators:
        try:
            full_name = legislator.find('h5').text.strip()
            last_name = full_name.split(',')[0] if ',' in full_name else full_name.split(' ')[-1]
            district = None
            district_tag = legislator.find('span', class_='text-nowrap')
            if district_tag:
                district = district_tag.text.replace('District: ', '').strip()
            member_link = legislator.find('a', href=re.compile(r'details\.aspx\?MemberId=\d+'))
            member_id = None
            if member_link:
                m = re.search(r'MemberId=(\d+)', member_link['href'])
                if m:
                    member_id = m.group(1)
            # Party and counties not reliably available, leave blank
            all_data.append({
                'legislator_name': full_name,
                'last_name': last_name,
                'district_number': district,
                'member_id': member_id,
                'party': "",
                'counties': "",
                'chamber': 'House'
            })
        except Exception as e:
            print(f"Error on House legislator: {e}")
    return all_data

def scrape_senate(page):
    print("Scraping Senate...")
    page.goto("https://www.flsenate.gov/Senators")
    page.wait_for_selector('tr[class*="All"]')
    html_content = page.content()
    doc = BeautifulSoup(html_content, "html.parser")
    senators = doc.find_all('tr', class_=re.compile(r'All'))

    all_data = []
    for senator in senators:
        try:
            th = senator.find('th', class_='lefttext')
            if not th:
                continue
            name_link = th.find('a', class_='senatorLink')
            full_name = name_link.text.strip() if name_link else None
            last_name = full_name.split(',')[0] if full_name and ',' in full_name else (full_name.split(' ')[-1] if full_name else None)
            tds = senator.find_all('td')
            district = tds[0].text.strip() if len(tds) > 0 else None
            party = tds[1].text.strip() if len(tds) > 1 else None
            counties = tds[2].text.strip() if len(tds) > 2 else None

            # Get senator/member_id from URL or img src
            senator_id = None
            img = name_link.find('img') if name_link else None
            if img and 'src' in img.attrs:
                match = re.search(r'S(\d+)_', img['src'])
                if match:
                    senator_id = match.group(1)
            elif name_link and 'href' in name_link.attrs:
                match = re.search(r'/S(\d+)', name_link['href'])
                if match:
                    senator_id = match.group(1)

            all_data.append({
                'legislator_name': full_name,
                'last_name': last_name,
                'district_number': district,
                'member_id': senator_id,
                'party': party,
                'counties': counties,
                'chamber': 'Senate'
            })
        except Exception as e:
            print(f"Error on senator: {e}")
    return all_data

def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        page = browser.new_page()

        house_data = scrape_house(page)
        # Add a small pause so the Senate page doesn't get a 429/too many requests error
        time.sleep(2)
        senate_data = scrape_senate(page)

        all_legislators = house_data + senate_data
        df = pd.DataFrame(all_legislators)
        print(df)
        df.to_csv("t_legislator_ids.csv", index=False)
        browser.close()

if __name__ == "__main__":
    main()
