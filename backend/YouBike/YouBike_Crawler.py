from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import Select
from bs4 import BeautifulSoup
import time
import json
import os

def find_addr(addr_list):
    # 等待網頁加載完成
    time.sleep(1)

    html = driver.page_source
    # with open("YouBike_01.html", "w", encoding="utf-8") as f:
    #     f.write(html)
    # print("✅ YouBike_01.html 已儲存")


    # 獲取 YouBike 地址
    soup = BeautifulSoup(html, "html.parser")
    
    addr_all = soup.find("ul", class_="item-inner2")
    # print(addr_all)
    addr_all = addr_all.find_all("ol")

    for item in addr_all:
        addr = item.find_all("li")
        if len(addr) >= 3:
            addr_city = addr[0].text
            addr_town = addr[1].text
            addr_name = addr[2].text
            addr_list.append({"city":addr_city, "town":addr_town, "name":addr_name})
            # print(addr_city, addr_town, addr_name)

    # 下一頁
    next_button = driver.find_element(By.CLASS_NAME, "cdp_i.next.css-4g6ai3")

    if next_button.is_displayed():
        next_button.click()
        find_addr(addr_list)
    else:
        return

    return

url = "https://www.youbike.com.tw/region/main/stations/list/"

# 設定 Chrome 選項
options = Options()
options.add_argument("--window-size=1920,1080")
options.add_argument("--disable-gpu")
options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36")

# 替換成你的 chromedriver 路徑
driver_path = os.path.join(os.path.dirname(__file__), '..', 'chromedriver.exe')
service = Service(executable_path=driver_path)
# service = Service(executable_path="chromedriver.exe")

# 啟動瀏覽器
driver = webdriver.Chrome(service=service, options=options)
driver.get(url)

# 等待網頁加載完成
WebDriverWait(driver, 10).until(EC.presence_of_element_located((By.TAG_NAME, "footer")))

# 寫入html
html = driver.page_source
with open("YouBike_List.html", "w", encoding="utf-8") as f:
    f.write(html)
print("✅ YouBike_List.html 已儲存")

# 城市列表
soup = BeautifulSoup(html, "html.parser")
city_list = []
city_all = soup.find("select", id="stations-select-area")
city_all = city_all.find_all("option")
for city in city_all:
    if city["value"]=='':
        continue
    city_list.append({"value":city["value"], "city":city.text})
# print(city_list)


# 選擇城市
select_elem = driver.find_element(By.ID, "stations-select-area")
select = Select(select_elem)

addr_list = []

for item in city_list:
    select.select_by_visible_text(item["city"])
    find_addr(addr_list)
    
with open("YouBike_List.json", "w", encoding="utf-8") as json_file:
    json.dump(addr_list, json_file, ensure_ascii=False, indent=4)

print("✅ addr_list 已儲存為 JSON 文件")


driver.quit()