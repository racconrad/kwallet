from PIL import Image, ImageDraw


BACKGROUNDS = ('#f2efe8', '#25232b')
INKS = ('#302c35', '#f8ecdd')


def write_previews(rendered, palette, destination):
    contact = Image.new('RGB', (1024, len(rendered) * 320))
    draw = ImageDraw.Draw(contact)
    for index, (animation, frames) in enumerate(rendered):
        for theme, (background, ink) in enumerate(zip(BACKGROUNDS, INKS)):
            y = index * 320 + theme * 160
            draw.rectangle((0, y, 1023, y + 159), fill=background)
            draw.text((8, y + 6), f'{animation.name} / {animation.frame_ms}ms per cell / 2x native', fill=ink)
            for column, frame in enumerate(frames):
                enlarged = frame.resize((128, 128), Image.Resampling.NEAREST)
                contact.paste(enlarged, (column * 128, y + 24), enlarged)
                draw.text((column * 128 + 8, y + 144), str(column), fill=ink)
        write_animation(animation, frames, palette, destination)
    contact.save(destination / 'review.png')


def write_animation(animation, frames, palette, destination):
    colors = [rgb[:3] for symbol, rgb in palette.items() if symbol != '.']
    colors += [tuple(bytes.fromhex(color[1:])) for color in BACKGROUNDS + INKS]
    table = Image.new('P', (1, 1))
    flat = [channel for rgb in colors for channel in rgb]
    table.putpalette(flat + [0] * (768 - len(flat)))
    preview_frames = []
    for frame in frames:
        preview = Image.new('RGB', (448, 240))
        draw = ImageDraw.Draw(preview)
        for theme, (background, ink) in enumerate(zip(BACKGROUNDS, INKS)):
            x = theme * 224
            draw.rectangle((x, 0, x + 223, 239), fill=background)
            draw.text((x + 12, 8), f'{animation.name} / 3x native', fill=ink)
            preview.paste(frame, (x + 148, 4), frame)
            enlarged = frame.resize((192, 192), Image.Resampling.NEAREST)
            preview.paste(enlarged, (x + 16, 32), enlarged)
        preview_frames.append(preview.quantize(palette=table, dither=Image.Dither.NONE))
    preview_frames[0].save(destination / f'{animation.name}.gif', save_all=True,
                           append_images=preview_frames[1:], duration=animation.frame_ms,
                           loop=0, disposal=2, optimize=False)
