import math
from PIL import Image, ImageDraw

def create_icons():
    # Grid size: 128 x 128 (scaled 8x -> 1024 x 1024)
    GW, GH = 128, 128
    
    # Colors from RetroColors (PICO-8 palette)
    C_BG = (29, 43, 83, 255)       # #1D2B53 Pico Dark Blue
    C_BLACK = (0, 0, 0, 255)       # #000000
    C_INK = (18, 20, 26, 255)      # Deep ink
    C_SHELL = (255, 0, 77, 255)    # #FF004D Pico Red/Pink
    C_SHELL_DARK = (126, 37, 83, 255) # #7E2553 Pico Dark Purple/Burgundy shadow
    C_SHELL_LIGHT = (255, 119, 168, 255) # #FF77A8 Pico Pink highlight
    C_LABEL = (255, 241, 232, 255) # #FFF1E8 Pico White/Cream
    C_LABEL_LINE = (194, 195, 199, 255) # #C2C3C7
    C_BLUE = (41, 173, 255, 255)   # #29ADFF Pico Blue
    C_DARK_BLUE = (29, 43, 83, 255)
    C_YELLOW = (255, 236, 39, 255) # #FFEC27 Pico Yellow
    C_ORANGE = (255, 163, 0, 255)  # #FFA300 Pico Orange
    C_GREEN = (0, 228, 54, 255)    # #00E436 Pico Green
    C_BROWN = (171, 82, 54, 255)   # #AB5236 Magnetic Tape Brown
    C_WHITE = (255, 255, 255, 255)
    C_GRAY = (95, 87, 79, 255)     # #5F574F
    C_LIGHT_GRAY = (194, 195, 199, 255)
    C_TRANSPARENT = (0, 0, 0, 0)

    # 1. Base foreground image (transparent background)
    fg = Image.new("RGBA", (GW, GH), C_TRANSPARENT)
    draw = ImageDraw.Draw(fg)

    # --- CASSETTE DIMENSIONS ---
    # Centered horizontally: X from 30 to 97 (width = 68)
    # Cassette Y from 42 to 85 (height = 44)
    # Safe zone circle radius: ~42 around (64, 64).
    # Corners: (30,42) dist to (64,64) = sqrt(34^2 + 22^2) = sqrt(1156+484) = sqrt(1640) = 40.5! Perfectly inside 42 safe radius.

    x0, y0 = 30, 42
    x1, y1 = 97, 85

    # Cassette Outer Shadow / Outline (Black)
    # Main body outline
    draw.rectangle([x0+2, y0, x1-2, y1], fill=C_BLACK)
    draw.rectangle([x0, y0+2, x1, y1-2], fill=C_BLACK)
    # Corner chamfers
    draw.point((x0+1, y0+1), fill=C_BLACK)
    draw.point((x1-1, y0+1), fill=C_BLACK)
    draw.point((x0+1, y1-1), fill=C_BLACK)
    draw.point((x1-1, y1-1), fill=C_BLACK)

    # Cassette Shell (Red/Pink with bottom-right shadow and top-left highlight)
    draw.rectangle([x0+2, y0+2, x1-2, y1-2], fill=C_SHELL)
    
    # Shadow edges (bottom and right inside border)
    draw.line([(x0+3, y1-2), (x1-2, y1-2)], fill=C_SHELL_DARK)
    draw.line([(x1-2, y0+3), (x1-2, y1-2)], fill=C_SHELL_DARK)
    
    # Highlight edges (top and left inside border)
    draw.line([(x0+2, y0+2), (x1-3, y0+2)], fill=C_SHELL_LIGHT)
    draw.line([(x0+2, y0+2), (x0+2, y1-3)], fill=C_SHELL_LIGHT)

    # 4 Corner Screws (2x2 light gray with 1 black pixel)
    for sx, sy in [(x0+3, y0+3), (x1-5, y0+3), (x0+3, y1-5), (x1-5, y1-5)]:
        draw.rectangle([sx, sy, sx+1, sy+1], fill=C_LIGHT_GRAY)
        draw.point((sx+1, sy), fill=C_DARK_BLUE)

    # --- CASSETTE LABEL (Cream White Area) ---
    lx0, ly0 = x0+6, y0+6
    lx1, ly1 = x1-6, y0+29  # 56 wide, 24 high

    # Label border
    draw.rectangle([lx0, ly0, lx1, ly1], outline=C_BLACK, fill=C_LABEL)

    # Label Top Header Banner (Pico Blue)
    draw.rectangle([lx0+1, ly0+1, lx1-1, ly0+6], fill=C_BLUE)
    # Secondary thin stripe (Pico Orange)
    draw.rectangle([lx0+1, ly0+7, lx1-1, ly0+8], fill=C_ORANGE)

    # Text on Header: "MY MUSIC" in 8-bit micro font (3x5 per glyph)
    # Let's draw "MY MUSIC" or "MYMUSIC" precisely in 1-pixel font!
    # M:
    # #   #
    # ## ##
    # # # #
    # #   #
    # #   #
    glyphs = {
        'M': ["10001", "11011", "10101", "10001", "10001"],
        'Y': ["10001", "01010", "00100", "00100", "00100"],
        'U': ["10001", "10001", "10001", "10001", "01110"],
        'S': ["01111", "10000", "01110", "00001", "11110"],
        'I': ["111", "010", "010", "010", "111"],
        'C': ["01110", "10000", "10000", "10000", "01110"],
        ' ': ["00"]
    }
    # Banner area: ly0+1 is Y=49. Height is 5px (Y=49 to 53).
    # Total width of "MY MUSIC": M(5)+1+Y(5)+2+M(5)+1+U(5)+1+S(5)+1+I(3)+1+C(5) = 5+1+5+2+5+1+5+1+5+1+3+1+5 = 40px.
    # Center banner: (lx0 + lx1) // 2 = 64. Start X = 64 - 20 = 44.
    cur_x = 44
    text = "MY MUSIC"
    for char in text:
        bitmap = glyphs[char]
        w = len(bitmap[0])
        for row_idx, row in enumerate(bitmap):
            for col_idx, bit in enumerate(row):
                if bit == '1':
                    draw.point((cur_x + col_idx, ly0 + 1 + row_idx), fill=C_WHITE)
        cur_x += w + 1

    # --- CENTER TAPE RECORDER WINDOW & SPOOLS ---
    # Window area: center horizontally, Y from ly0+10 to ly0+22
    wx0, wy0 = 44, ly0+10   # X: 44 to 83 (40 wide, 13 high)
    wx1, wy1 = 83, ly0+22
    # Black outline of center window
    draw.rectangle([wx0, wy0, wx1, wy1], outline=C_BLACK, fill=C_BLACK)
    # Dark brown tape fill between spools
    draw.rectangle([wx0+7, wy0+2, wx1-7, wy1-2], fill=C_BROWN)
    # Center clear window slit
    draw.rectangle([58, wy0+3, 70, wy1-3], fill=C_DARK_BLUE)
    # Tape progress line
    draw.line([(59, wy0+7), (69, wy0+7)], fill=C_ORANGE)

    # Spool 1 (Left): Center (51, wy0+6)
    # Spool 2 (Right): Center (76, wy0+6)
    for cx in [51, 76]:
        cy = wy0 + 6
        # White spool gear (diameter 7)
        draw.rectangle([cx-3, cy-2, cx+3, cy+2], fill=C_WHITE)
        draw.rectangle([cx-2, cy-3, cx+2, cy+3], fill=C_WHITE)
        # 3 Spool teeth (Yellow)
        draw.point((cx-2, cy), fill=C_YELLOW)
        draw.point((cx+2, cy), fill=C_YELLOW)
        draw.point((cx, cy-2), fill=C_YELLOW)
        draw.point((cx, cy+2), fill=C_YELLOW)
        # Center hole (Black)
        draw.rectangle([cx-1, cy-1, cx+1, cy+1], fill=C_BLACK)
        draw.point((cx, cy), fill=C_DARK_BLUE)

    # --- CASSETTE BOTTOM SECTION (Head Trapezoid & Guide Rollers) ---
    # Bottom area: Y from 74 to 83
    tx0, ty0 = x0+14, 74
    tx1, ty1 = x1-14, 83
    # Trapezoid notch
    draw.rectangle([tx0, ty0, tx1, ty1], outline=C_BLACK, fill=C_SHELL_DARK)
    # Roller holes (Left & Right)
    draw.rectangle([tx0+4, ty0+2, tx0+7, ty0+5], fill=C_BLACK)
    draw.point((tx0+5, ty0+3), fill=C_LIGHT_GRAY)
    draw.point((tx0+6, ty0+3), fill=C_LIGHT_GRAY)
    
    draw.rectangle([tx1-7, ty0+2, tx1-4, ty0+5], fill=C_BLACK)
    draw.point((tx1-6, ty0+3), fill=C_LIGHT_GRAY)
    draw.point((tx1-5, ty0+3), fill=C_LIGHT_GRAY)

    # Center tape head contact pad
    draw.rectangle([60, ty0+2, 68, ty1-1], fill=C_BLACK)
    draw.rectangle([61, ty0+3, 67, ty1-2], fill=C_LIGHT_GRAY)

    # --- FLOATING RETRO 8-BIT MUSICAL NOTES & ARCADE STARS (Above Cassette) ---
    # Note 1: Vibrant Yellow (#FFEC27) Double Musical Note (Center-Left: X=45..58, Y=22..36)
    # Let's draw a double eighth note with black border!
    def draw_pixel_double_note(ox, oy, fill_color):
        # 8-bit double note pattern:
        # Note heads at (ox, oy+9) and (ox+8, oy+7)
        # Stems going up to oy, connected by beam
        # Beam:
        draw.line([(ox+2, oy), (ox+10, oy-2)], fill=C_BLACK, width=2)
        draw.line([(ox+3, oy+1), (ox+9, oy-1)], fill=fill_color)
        
        # Left stem:
        draw.line([(ox+2, oy), (ox+2, oy+9)], fill=C_BLACK, width=2)
        draw.line([(ox+3, oy+1), (ox+3, oy+8)], fill=fill_color)
        
        # Right stem:
        draw.line([(ox+10, oy-2), (ox+10, oy+7)], fill=C_BLACK, width=2)
        draw.line([(ox+9, oy-1), (ox+9, oy+6)], fill=fill_color)
        
        # Left note head:
        draw.rectangle([ox-1, oy+7, ox+3, oy+10], fill=C_BLACK)
        draw.rectangle([ox, oy+8, ox+2, oy+9], fill=fill_color)
        
        # Right note head:
        draw.rectangle([ox+7, oy+5, ox+11, oy+8], fill=C_BLACK)
        draw.rectangle([ox+8, oy+6, ox+10, oy+7], fill=fill_color)

    # Draw cyan double note floating joyfully above the cassette (ox=56, oy=24)
    # Radius check: (56, 24) to (64, 64) is sqrt(8^2 + 40^2) = sqrt(64+1600) = 40.79! Within safe circle!
    draw_pixel_double_note(58, 25, C_BLUE)

    # Single eighth note on the left (Cyan/Yellow ox=36, oy=28)
    def draw_pixel_single_note(ox, oy, fill_color):
        # Stem
        draw.line([(ox+3, oy), (ox+3, oy+8)], fill=C_BLACK, width=2)
        draw.line([(ox+3, oy+1), (ox+3, oy+7)], fill=fill_color)
        # Flag
        draw.rectangle([ox+4, oy, ox+6, oy+2], fill=C_BLACK)
        draw.point((ox+4, oy+1), fill=fill_color)
        draw.point((ox+5, oy+2), fill=fill_color)
        # Note head
        draw.rectangle([ox, oy+6, ox+4, oy+9], fill=C_BLACK)
        draw.rectangle([ox+1, oy+7, ox+3, oy+8], fill=fill_color)

    draw_pixel_single_note(38, 27, C_YELLOW)

    # Retro 4-point Arcade Stars / Sparkles
    def draw_sparkle(cx, cy, color):
        draw.point((cx, cy), fill=C_WHITE)
        draw.point((cx-1, cy), fill=color)
        draw.point((cx+1, cy), fill=color)
        draw.point((cx, cy-1), fill=color)
        draw.point((cx, cy+1), fill=color)
        # Outer subtle points
        draw.point((cx-2, cy), fill=color)
        draw.point((cx+2, cy), fill=color)
        draw.point((cx, cy-2), fill=color)
        draw.point((cx, cy+2), fill=color)

    draw_sparkle(82, 26, C_GREEN)
    draw_sparkle(27, 36, C_ORANGE)
    draw_sparkle(101, 38, C_YELLOW)
    draw_sparkle(26, 75, C_BLUE)
    draw_sparkle(102, 75, C_GREEN)

    # Soundwave pulses on the sides (8-bit equalizer bars)
    # Left side: X=22, 24
    for i, h in enumerate([2, 5, 3]):
        by = 58 - h
        draw.rectangle([21 + i*2, by, 21 + i*2 + 1, 58 + h], fill=C_BLUE)

    # Right side: X=102, 104
    for i, h in enumerate([3, 6, 2]):
        by = 58 - h
        draw.rectangle([101 + i*2, by, 101 + i*2 + 1, 58 + h], fill=C_YELLOW)

    # 2. Master Icon with solid arcade background
    master = Image.new("RGBA", (GW, GH), C_BG)
    master_draw = ImageDraw.Draw(master)
    
    # Add subtle retro CRT / pixel grid pattern to background for extra depth
    for y in range(0, GH, 4):
        master_draw.line([(0, y), (GW, y)], fill=(24, 35, 68, 255))

    # Composite foreground on master
    master.paste(fg, (0, 0), fg)

    # Upscale master to 1024x1024 using NEAREST neighbor for perfect pixel-art clarity!
    master_1024 = master.resize((1024, 1024), Image.Resampling.NEAREST)
    
    # Adaptive background: 1024x1024 with the retro dark blue and scanlines
    bg_1024 = master.resize((1024, 1024), Image.Resampling.NEAREST)
    # Clear the fg from bg_1024
    bg_clean = Image.new("RGBA", (GW, GH), C_BG)
    bg_draw = ImageDraw.Draw(bg_clean)
    for y in range(0, GH, 4):
        bg_draw.line([(0, y), (GW, y)], fill=(24, 35, 68, 255))
    bg_1024 = bg_clean.resize((1024, 1024), Image.Resampling.NEAREST)

    # Adaptive foreground:
    # Android Adaptive Icon safe zone is the inner 66dp of 108dp (61.1%).
    # We scale the foreground to ~75% (800x800) and place it centered at (512, 512)
    # so the cassette (which spans ~68% of the grid) lands at ~52% of the canvas,
    # safely inside the 66% circular mask on any Android device!
    fg_scaled_size = 780
    fg_scaled = fg.resize((fg_scaled_size, fg_scaled_size), Image.Resampling.NEAREST)
    fg_adaptive_1024 = Image.new("RGBA", (1024, 1024), C_TRANSPARENT)
    offset = (1024 - fg_scaled_size) // 2
    fg_adaptive_1024.paste(fg_scaled, (offset, offset), fg_scaled)

    # Save outputs
    master_1024.save("assets/icons/app_icon.png", "PNG")
    fg_adaptive_1024.save("assets/icons/app_icon_foreground.png", "PNG")
    bg_1024.save("assets/icons/app_icon_background.png", "PNG")

    print("Icons generated successfully in assets/icons/!")

if __name__ == "__main__":
    create_icons()
