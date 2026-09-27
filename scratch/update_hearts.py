# SVG content for heart.svg (official Pixelarticons outline)
heart_svg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="currentColor">
  <path d="M13 22h-2v-2h2v2Zm-2-2H9v-2h2v2Zm4 0h-2v-2h2v2Zm-6-2H7v-2h2v2Zm8 0h-2v-2h2v2ZM7 16H5v-2h2v2Zm12 0h-2v-2h2v2ZM5 14H3v-2h2v2Zm16 0h-2v-2h2v2ZM3 12H1V6h2v6Zm20 0h-2V6h2v6ZM13 8h-2V6h2v2ZM5 6H3V4h2v2Zm6 0H9V4h2v2Zm4 0h-2V4h2v2Zm6 0h-2V4h2v2ZM9 4H5V2h4v2Zm10 0h-4V2h4v2Z"/>
</svg>
'''

# SVG content for heart_filled.svg (matching filled shape)
heart_filled_svg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" fill="currentColor">
  <path d="M5 2h4v2H5V2zm10 0h4v2h-4V2zM3 4h8v2H3V4zm10 0h8v2h-8V4zM1 6h10v2H1V6zm12 0h10v2h-10V6zM1 8h22v4H1V8zm2 4h18v2H3v-2zm2 2h14v2H5v-2zm2 2h10v2H7v-2zm2 2h6v2H9v-2zm2 2h2v2h-2v-2z"/>
</svg>
'''

with open("assets/icons/heart.svg", "w") as f:
    f.write(heart_svg)

with open("assets/icons/heart_filled.svg", "w") as f:
    f.write(heart_filled_svg)

print("Updated assets/icons/heart.svg and heart_filled.svg successfully!")
