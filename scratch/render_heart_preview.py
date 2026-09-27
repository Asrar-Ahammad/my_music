from PIL import Image, ImageDraw

# Create 24x24 canvas for heart outline and filled
# Let's map the pixels:
# 24x24 grid:
# Row 2-3 (y=2..3):
#   Left top: x=5..8 (width 4)
#   Right top: x=15..18 (width 4)
# Row 4-5 (y=4..5):
#   x=3..4, x=9..10, x=13..14, x=19..20
# Row 6-7 (y=6..7):
#   x=1..2, x=11..12, x=21..22
# Row 8-11 (y=8..11):
#   x=1..2, x=21..22
# Row 12-13 (y=12..13):
#   x=3..4, x=19..20
# Row 14-15 (y=14..15):
#   x=5..6, x=17..18
# Row 16-17 (y=16..17):
#   x=7..8, x=15..16
# Row 18-19 (y=18..19):
#   x=9..10, x=13..14
# Row 20-21 (y=20..21):
#   x=11..12 (tip)

# For heart filled:
# Fill the interior:
# Row 2-3: x=5..8 and x=15..18
# Row 4-5: x=3..10 and x=13..20
# Row 6-7: x=1..22 (except maybe cleft at top if desired, or x=1..10 and 13..22, with x=11..12 at y=6..7 as cleft)
# Row 8-11: x=1..22
# Row 12-13: x=3..20
# Row 14-15: x=5..18
# Row 16-17: x=7..16
# Row 18-19: x=9..14
# Row 20-21: x=11..12

def render_preview():
    # Outline
    img_outline = Image.new("RGBA", (24, 24), (0,0,0,0))
    d_out = ImageDraw.Draw(img_outline)

    # Let's draw the pixelarticons outline:
    # Row 2..3 (y=2, h=2): x=5..8, x=15..18
    d_out.rectangle([5, 2, 8, 3], fill=(255,255,255,255))
    d_out.rectangle([15, 2, 18, 3], fill=(255,255,255,255))

    # Row 4..5 (y=4, h=2): x=3..4, x=9..10, x=13..14, x=19..20
    d_out.rectangle([3, 4, 4, 5], fill=(255,255,255,255))
    d_out.rectangle([9, 4, 10, 5], fill=(255,255,255,255))
    d_out.rectangle([13, 4, 14, 5], fill=(255,255,255,255))
    d_out.rectangle([19, 4, 20, 5], fill=(255,255,255,255))

    # Row 6..7 (y=6, h=2): x=1..2, x=11..12, x=21..22
    d_out.rectangle([1, 6, 2, 7], fill=(255,255,255,255))
    d_out.rectangle([11, 6, 12, 7], fill=(255,255,255,255))
    d_out.rectangle([21, 6, 22, 7], fill=(255,255,255,255))

    # Row 8..11 (y=8, h=4): x=1..2, x=21..22
    d_out.rectangle([1, 8, 2, 11], fill=(255,255,255,255))
    d_out.rectangle([21, 8, 22, 11], fill=(255,255,255,255))

    # Row 12..13 (y=12, h=2): x=3..4, x=19..20
    d_out.rectangle([3, 12, 4, 13], fill=(255,255,255,255))
    d_out.rectangle([19, 12, 20, 13], fill=(255,255,255,255))

    # Row 14..15 (y=14, h=2): x=5..6, x=17..18
    d_out.rectangle([5, 14, 6, 15], fill=(255,255,255,255))
    d_out.rectangle([17, 14, 18, 15], fill=(255,255,255,255))

    # Row 16..17 (y=16, h=2): x=7..8, x=15..16
    d_out.rectangle([7, 16, 8, 17], fill=(255,255,255,255))
    d_out.rectangle([15, 16, 16, 17], fill=(255,255,255,255))

    # Row 18..19 (y=18, h=2): x=9..10, x=13..14
    d_out.rectangle([9, 18, 10, 19], fill=(255,255,255,255))
    d_out.rectangle([13, 18, 14, 19], fill=(255,255,255,255))

    # Row 20..21 (y=20, h=2): x=11..12
    d_out.rectangle([11, 20, 12, 21], fill=(255,255,255,255))

    # Filled Heart:
    img_filled = Image.new("RGBA", (24, 24), (0,0,0,0))
    d_fill = ImageDraw.Draw(img_filled)

    # Row 2..3
    d_fill.rectangle([5, 2, 8, 3], fill=(255,0,77,255))
    d_fill.rectangle([15, 2, 18, 3], fill=(255,0,77,255))

    # Row 4..5
    d_fill.rectangle([3, 4, 10, 5], fill=(255,0,77,255))
    d_fill.rectangle([13, 4, 20, 5], fill=(255,0,77,255))

    # Row 6..7
    d_fill.rectangle([1, 6, 10, 7], fill=(255,0,77,255))
    d_fill.rectangle([13, 6, 22, 7], fill=(255,0,77,255))

    # Row 8..11
    d_fill.rectangle([1, 8, 22, 11], fill=(255,0,77,255))

    # Row 12..13
    d_fill.rectangle([3, 12, 20, 13], fill=(255,0,77,255))

    # Row 14..15
    d_fill.rectangle([5, 14, 18, 15], fill=(255,0,77,255))

    # Row 16..17
    d_fill.rectangle([7, 16, 16, 17], fill=(255,0,77,255))

    # Row 18..19
    d_fill.rectangle([9, 18, 14, 19], fill=(255,0,77,255))

    # Row 20..21
    d_fill.rectangle([11, 20, 12, 21], fill=(255,0,77,255))

    # Scale 10x for preview
    img_outline.resize((240, 240), Image.Resampling.NEAREST).save("scratch/heart_outline_preview.png")
    img_filled.resize((240, 240), Image.Resampling.NEAREST).save("scratch/heart_filled_preview.png")
    print("Previews saved!")

if __name__ == "__main__":
    render_preview()
