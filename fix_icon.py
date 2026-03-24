from PIL import Image
import os

icon_path = r'd:\Xampp\htdocs\oncourse\oncourse_student_app\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-1024x1024@1x.png'

if os.path.exists(icon_path):
    print(f"Opening {icon_path}...")
    img = Image.open(icon_path)
    if img.mode in ('RGBA', 'LA') or (img.mode == 'P' and 'transparency' in img.info):
        print("Alpha channel found. Converting to RGB...")
        rgb_img = img.convert('RGB')
        rgb_img.save(icon_path)
        print("Success! Alpha channel removed.")
    else:
        print("No alpha channel found. Nothing to do.")
else:
    print(f"Icon not found at {icon_path}")
