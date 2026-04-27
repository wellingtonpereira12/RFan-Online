import urllib.request
import re

url = 'https://rfdatabase.net/monster/hue-gaff'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    html = urllib.request.urlopen(req).read().decode('utf-8')
    scripts = re.findall(r'<script.*?src=[\'\"]([^\'\"]+)[\'\"]', html)
    for s in scripts:
        print(s)
except Exception as e:
    print(e)
