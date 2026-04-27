import urllib.request
import re
import json

url = 'https://rfdatabase.net/monster/hue-gaff'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    html = urllib.request.urlopen(req).read().decode('utf-8')
    # Look for the model URL
    models = re.findall(r'[\'\"].*?(?:glb|gltf|3d|model|obj|fbx).*?[\'\"]', html, re.IGNORECASE)
    print("Found potential model strings:", set(models))
    
    # Look for scripts that might be 3D viewers
    scripts = re.findall(r'<script.*?src=[\'\"]([^\'\"]+)[\'\"].*?>', html)
    print("Scripts:", scripts)
    
    for line in html.split('\n'):
        if 'model' in line.lower() or 'gltf' in line.lower() or 'glb' in line.lower():
            print(line.strip()[:200])
except Exception as e:
    print('Error:', e)
