from PIL import Image
import os

files = ['icon_256.png', 'icon_128.png', 'icon_64.png', 'icon_48.png', 'icon_32.png', 'icon_24.png', 'icon_16.png']
images = []

print("Loading images...")
for f in files:
    path = os.path.join('assets', f)
    if os.path.exists(path):
        img = Image.open(path)
        images.append(img)
        print(f"Loaded {path}: {img.size}")
    else:
        print(f"Missing {path}")

if images:
    out_path = os.path.join('assets', 'icon.ico')
    print(f"Saving to {out_path}...")
    # Note: append_images takes the rest of the images
    # sizes parameter is optional but good practice
    images[0].save(
        out_path, 
        format='ICO', 
        append_images=images[1:]
    )
    print("Saved.")
else:
    print("No images loaded.")
